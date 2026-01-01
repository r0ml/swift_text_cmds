
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1987, 1993, 1994
   The Regents of the University of California.  All rights reserved.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  3. Neither the name of the University nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.
 
  THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */

import CMigration

// for regcomp and regex
import Darwin

@main final class split : ShellCommand {

  let DEFLINE: Int = 1000 // Default number of lines per file
  let MAXBSIZE = 8192 // Define an appropriate buffer size

  var usage : String = """
Usage: split [-cd] [-l line_count] [-a suffix_length] [file [prefix]]
       split [-cd] -b byte_count[K|k|M|m|G|g] [-a suffix_length] [file [prefix]]
       split [-cd] -n chunk_count [-a suffix_length] [file [prefix]]
       split [-cd] -p pattern [-a suffix_length] [file [prefix]]
"""

  struct CommandOptions {
    var bytecnt = 0      // Byte count to split on
    var chunks: Int = 0         // Chunks count to split into
    var clobber: Bool = true    // Whether to overwrite existing output files
    var numlines: Int = 0       // Line count to split on
    var iurl : String? = nil
    var ifd: FileDescriptor = FileDescriptor.standardInput
    var fname: String = ""      // File name prefix
    var sufflen: Int = 2        // File name suffix length
    // for non-Apple, it is true
    var autosfx: Bool = false   // Whether to auto-extend the suffix length
    var pflag: Bool = false
    var dflag: Bool = false
    var rgx : Darwin.regex_t = Darwin.regex_t()
//    var regexPattern: NSRegularExpression?
    var args : [String] = CommandLine.arguments
  }

  var options: CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "0::1::2::3::4::5::6::7::8::9::a:b:cdl:n:p:"
    let go = BSDGetopt(supportedFlags)

    // FIXME: need to put the locale back in
//    let locale = Locale.current.identifier
    

    while let (k, v) = try go.getopt() {
      switch k {
        case "0"..."9":
          // Undocumented Kludge: split was originally designed to take a number after a dash
          if options.numlines != 0 { throw CmdErr(64) }
          if let lc = Int(String(k)+v) {
            options.numlines = lc
          } else {
            throw CmdErr(64, "\(k)\(v): line count is invalid")
          }
        case "a": // suffix length
          if let s = Int(v) {
            options.sufflen = s
          } else {
            throw CmdErr(1, "\(v): suffix length is invalid number")
          }
          if options.sufflen == 0 {
            options.sufflen = 2
            options.autosfx = true
          } else {
            options.autosfx = false
          }
        case "b": // byte count
          if let bc = Int(v) {
            options.bytecnt = bc
          } else {
            throw CmdErr(64, "\(v): byte count is invalid")
          }
        case "c": // continue, don't overwrite output files
          options.clobber = false
        case "d": // decimal suffix
          options.dflag = true
        case "l": // line count
          if options.numlines != 0 {
            throw CmdErr(64)
          }
          if let n = Int(v) {
            options.numlines = n
          } else {
            throw CmdErr(64, "\(v): line count is invalid")
          }
        case "n": // chunks
          if let c = Int(v) {
            options.chunks = c
          } else {
            throw CmdErr(64, "\(v): chunk count is invalid")
          }
        case "p": // pattern matching
          let error = regcomp(&options.rgx, v, REG_EXTENDED | REG_NOSUB)
          if error != 0 {
            let s = regerror(error, options.rgx)
            throw CmdErr(64, "\(v): regex is invalid: \(s)")
          }
          options.pflag = true
            
/*          if let pattern = args.first {
            do {
              regexPattern = try NSRegularExpression(pattern: pattern, options: [])
              pflag = true
            } catch {
              print("Invalid regex pattern: \(pattern)")
              exit(EXIT_FAILURE)
            }
 */
        default: throw CmdErr(64)
      }
    }
    
    var args = go.remaining
    
    if args.count > 0 { // input file
      if args[0] == "-" {
        options.ifd = FileDescriptor.standardInput
      } else {
        do {
//          let u = URL(filePath: args[0])
          options.iurl = args[0]
          options.ifd = try FileDescriptor(forReading: args[0])
        } catch {
          throw CmdErr(1, "\(args[0]): \(error)")
        }
      }
      args.removeFirst()
    }
    
    if args.count > 0 {
      options.fname = args[0]
      args.removeFirst()
    }
    
    if args.count > 0 {
      throw CmdErr(1)
    }
    
    if options.pflag && (options.numlines != 0 || options.bytecnt != 0 || options.chunks != 0) {
      throw CmdErr(1)
    }
    
    if options.numlines == 0 { options.numlines = DEFLINE }
    else if options.bytecnt != 0 || options.chunks != 0 {
      throw CmdErr(1)
    }
    
    if options.bytecnt != 0 && options.chunks != 0 {
      throw CmdErr(1)
    }
    
    return options
  }
  
  func runCommand() async throws(CmdErr) {
    if options.bytecnt != 0 {
      try split1()
    } else if options.chunks != 0 {
      try split3()
    } else {
      try await split2()
    }
  }
  
  /// Split the input by bytes
  func split1() throws(CmdErr) {
    
    var bcnt = 0
    var nfiles = 0
    var buffer : ArraySlice<UInt8>
    var state = splitState(options)
    
//    let k = AsyncBlockSequence(fileHandle: options.ifd, chunkSize: options.bytecnt)

    while true {
      do {
        buffer = try ArraySlice(options.ifd.readUpToCount(MAXBSIZE))
      } catch {
        throw CmdErr(1, "read: \(error)")
      }
      guard buffer.count > 0 else { break }
      var len = buffer.count
      if state.ofd == nil {
            if options.chunks == 0 || nfiles < options.chunks {
              try newfile(&state)
              nfiles += 1
            }
          }
      
      if bcnt + len > options.bytecnt {
        
        let dist = options.bytecnt - bcnt
        
        do {
          try state.ofd?.write(Array(buffer.prefix(dist)))
        } catch {
          throw CmdErr(1, "write: \(error)")
        }
        
        buffer = buffer.dropFirst(dist)
        len -= dist
        
        while len >= options.bytecnt {
          if options.chunks == 0 || nfiles < options.chunks {
            try newfile(&state)
            nfiles += 1
          }
          do {
            try state.ofd?.write(Array(buffer.prefix(options.bytecnt)))
          } catch {
            throw CmdErr(1, "write: \(error)")
          }
          buffer = buffer.dropFirst(options.bytecnt)
          len -= options.bytecnt
        }
          
        if len != 0 {
          if options.chunks == 0 || nfiles < options.chunks {
            try newfile(&state)
            nfiles += 1
          }
          
          do {
            try state.ofd?.write(Array(buffer))
          } catch {
            throw CmdErr(1, "write: \(error)")
          }
        } else {
          try? state.ofd?.close()
          state.ofd = nil
        }
        bcnt = len
      } else {
        bcnt += len
        do {
          try state.ofd?.write(Array(buffer))
        } catch {
          throw CmdErr(1, "write: \(error)")
        }
      }
      }
    }
  
  /// Split the input by lines
  func split2() async throws(CmdErr) {
    var state = splitState(options)
    var lcnt: Int = 0
    var rgx = options.rgx
    
    do {
      for try await line in options.ifd.bytes.lines {
        if options.pflag {
          var pmatch = Darwin.regmatch_t()
          pmatch.rm_so = 0
          pmatch.rm_eo = Darwin.regoff_t(line.count)

          if (Darwin.regexec(&rgx, line, 0, &pmatch, REG_STARTEND) == 0) {
            try newfile(&state)
          }
          //        if let regex = regexPattern, regex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
          //          newfile()
          //        }
          
        } else {
           if lcnt == options.numlines {
            try newfile(&state)
            lcnt = 1
           } else {
             lcnt += 1
           }
        }
        if state.ofd == nil {
          try newfile(&state)
        }

        print(line, to: &state.ofd!)

//        state.ofd?.write(line)
        
      }
    } catch let e as CmdErr {
      throw e
    } catch {
      throw CmdErr(1, "read: \(error)")
    }
  }
  
  /// Split the input into specified number of chunks
  func split3() throws(CmdErr) {
    var fs : UInt = 0
    do {
      fs = try fileSize(at: FilePath(options.iurl!))
    } catch {
      if let iurl = options.iurl {
        throw CmdErr(1, "Stat error: \(iurl)")
      } else {
        throw CmdErr(1, "Stat error: stdin")
      }
    }
    if options.chunks > fs {
      throw CmdErr(1, "can't split into more than \(fs) files")
    }
    
    options.bytecnt = Int(fs) / options.chunks
    try split1()
  }
  

  struct splitState {
    var fnum = 0
    var fname = ""
    var sufflen = 2
    var ofd : FileDescriptor?
    
    init(_ options: CommandOptions) {
      self.sufflen = options.sufflen
      self.fname = options.fname
    }
  }
  
  /// Open a new output file
  func newfile(_ state : inout splitState) throws(CmdErr) {
    var maxfiles = 1
//    var flags = Darwin.O_WRONLY | Darwin.O_CREAT | Darwin.O_TRUNC
    var patt = "0123456789"
    
    if let ofd = state.ofd {
      do {
        try ofd.close()
      } catch {
        throw CmdErr(1, "closing file: \(error)")
      }
    } else {
      if state.fname.isEmpty {
        state.fname = "x"
      }
    }
    
    while true { // again
      if options.dflag {
        patt = "0123456789"
      } else {
        patt = "abcdefghijklmnopqrstuvwxyz"
      }
      
      let pattlen = patt.count
      
      /*
       * If '-a' is not specified, then we automatically expand the
       * suffix length to accomodate splitting all input.  We do this
       * by moving the suffix pointer (fpnt) forward and incrementing
       * sufflen by one, thereby yielding an additional two characters
       * and allowing all output files to sort such that 'cat *' yields
       * the input in order.  I.e., the order is '... xyy xyz xzaaa
       * xzaab ... xzyzy, xzyzz, xzzaaaa, xzzaaab' and so on.
       */
      
      if !options.dflag && options.autosfx {
        let z = state.sufflen-1 * Array(repeating: pattlen-1, count: state.sufflen).reduce(1, *)
        if state.fnum >= z {
          state.fname += "z"
          state.sufflen += 1
          state.fnum = 0
        }
      }
      
      for i in 0..<state.sufflen {
        if Int.max / pattlen < maxfiles {
          throw CmdErr(1, "suffix is too long (max \(i))")
        } else {
          maxfiles *= pattlen
        }
      }
      
      if state.fnum >= maxfiles {
        throw CmdErr(1, "too many files")
      }
      
      let fpnt = makeSuffix(state.fnum, state.sufflen, options.dflag)
      state.fnum += 1
      
      do {
        if !options.clobber {
          if fileExists(atPath: state.fname+fpnt) {
            continue
          }
        }
        state.ofd = try FileDescriptor.open(state.fname + fpnt, .writeOnly, options: [.create, .truncate], permissions: [.ownerReadWrite])
          break
      } catch {
        throw CmdErr(1, "writing to \(state.fname): \(error)")
      }
    }
  }
  
  func makeSuffix(_ fnum : Int, _ sufflen : Int, _ dflag : Bool) -> String {
    var tfnum = fnum
    var fpnt : [Character] = Array(repeating: " ", count: sufflen)
    let patt = Array(dflag ? "0123456789" : "abcdefghijklmnopqrstuvwxyz")
    
    
    for i in stride(from: sufflen, to: 0, by: -1) {
      fpnt[i-1] = patt[tfnum % patt.count]
      tfnum /= patt.count
    }
    return String(fpnt)
  }
  
}

public func fileSize(at path: FilePath) throws -> UInt {
  var statBuf = try FileMetadata(for: path.string)
  return statBuf.size
}
