
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1991, 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Edward Sze-Tyan Wang.
 
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

@main final class tail : ShellCommand {
  
  var usage : String = """
Usage: tail [-F | -f | -r] [-q] [-b # | -c # | -n #] [file ...]
"""
  
  struct CommandOptions {
//    var byteOffset: Int64 = 0
    var off : Int64 = 0
//    var numLines: Int64 = 0
    var fflag: Bool = false
    var Fflag: Bool = false
    var qflag: Bool = false
    var vflag: Bool = false
    var rflag: Bool = false
    var style: STYLE = .NOTSET
    var filePaths: [String] = []
    var args : [String] = CommandLine.arguments
  }
  
  // Enum to define different tail styles
  enum STYLE {
    case NOTSET
    case FBYTES
    case FLINES
    case RBYTES
    case RLINES
    case REVERSE
  }
  
  var rval : Int32 = 0
  var action : Action = .USE_SLEEP
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    //    var args = CommandLine.arguments.dropFirst() // Ignore the first argument (executable name)
    var options = CommandOptions()
    let supportedFlags = "+Fb:c:fn:qrv"
    let longOptions : [CMigration.option] = [
      .init("blocks", .required_argument),
      .init("bytes", .required_argument),
      .init("lines", .required_argument),
      .init("quiet", .no_argument),
      .init("silent", .no_argument),
      .init("verbose", .no_argument),
    ]

    let argo = try obsolete(CommandLine.arguments.dropFirst())
    let go = BSDGetopt_long(supportedFlags, longOptions, argo)

    while let (k, v) = try go.getopt_long() {
      switch k {
        case "F":
          options.Fflag = true
          options.fflag = true
        case "f":
          options.fflag = true
        case "q", "silent", "quiet":
          options.qflag = true
          options.vflag = false
        case "v", "verbose":
          options.vflag = true
          options.qflag = false
        case "r":
          options.rflag = true
        case "b", "blocks":
          try ARG(&options, v, 512, .FBYTES, .RBYTES)
        case "c", "bytes":
          try ARG(&options, v, 1, .FBYTES, .RBYTES)
        case "n", "lines":
          try ARG(&options, v, 1, .FLINES, .RLINES)
        default:
          throw CmdErr(1)
      }
    }
    
    options.filePaths = go.remaining
    
    if options.rflag {
      if options.fflag {
        throw CmdErr(1)
      }
      if options.style == .FBYTES {
        options.style = .RBYTES
      } else if options.style == .FLINES {
        options.style = .RLINES
      }
    }
    
    if options.style == .NOTSET {
      if options.rflag {
        options.off = 0
        options.style = .REVERSE
      } else {
        options.off = 10
        options.style = .RLINES
      }
    }
    
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    if options.filePaths.count > 0 && options.fflag {
      let files = try options.filePaths.map { (x : String) throws(CmdErr) in
        do {
          return try (FileDescriptor(forReading: x), x)
        } catch {
          // FIXME: in the original, it doesn't throw, it warns and continues
          throw CmdErr(1, "\(x): \(error)")
        }
      }
      do {
        try await follow(files, options)
      } catch {
        throw CmdErr(1, "\(error)")
      }
    } else if options.filePaths.count > 0 {
      var first = true
      for fn in options.filePaths {
          do {
            let fp = try FileDescriptor(forReading: fn)
            if options.vflag || (!options.qflag && options.filePaths.count > 1) {
              if (!first) { print("") }
              print("==> \(fn) <==")
              first = false
            }
            // FIXME: what about the directory?
            if options.rflag {
              try await reverse(fp, fn, options)
            } else {
              try await forward(fp, fn, options)
            }
            
          } catch {
            // FIXME: in the original, it doesn't throw, it warns and continues
            throw CmdErr(1, "\(fn): \(error)")
          }
          
      }
    } else {
      let fn = "stdin";
      var fflag = options.fflag
      /*
       * Determine if input is a pipe.  4.4BSD will set the SOCKET
       * bit in the st_mode field for pipes.  Fix this then.
       */
      if (Darwin.lseek(FileDescriptor.standardInput.rawValue, 0, Darwin.SEEK_CUR) == -1 &&
          errno == ESPIPE) {
        Darwin.errno = 0;
        fflag = false    /* POSIX.2 requires this. */
      }
      
      do {
        if (options.rflag) {
          try await reverse(FileDescriptor.standardInput, fn, options)
        } else if fflag {
          try await follow([(FileDescriptor.standardInput, fn)], options)
        } else {
          try await forward(FileDescriptor.standardInput, fn, options)
        }
      } catch {
        throw CmdErr(1, "\(error)")
      }
    }
    // exit(Int32(rval))
  }
  
  
  func ARG(_ options : inout CommandOptions, _ optarg : String, _ units : Int, _ forward : STYLE, _ backward : STYLE) throws(CmdErr) {
    if (options.style != .NOTSET) {
      throw CmdErr(1)
    }
    
    do {
      options.off = try Int64(expand_number(optarg))
    } catch {
      throw CmdErr(1, "illegal offset -- \(optarg)")
    }
    if (options.off > Int.max / units || options.off < Int.min / units ) {
      throw CmdErr(1, "illegal offset -- \(optarg)")
    }
    switch optarg.first {
      case "+":
        if (options.off != 0) {
          options.off -= Int64(units)
        }
        options.style = forward
      case "-":
        options.off = -options.off;
        fallthrough
      default:
        options.style = backward
    }
    
  }
}

// ==================================================

enum ExpandNumberError: Error {
    case invalidFormat
    case overflow
}

func expand_number(_ input: String) throws -> UInt64 {
    let suffixMultipliers: [Character: UInt64] = [
        "B": 1,         // Bytes
        "K": 1024,      // Kilobytes
        "M": 1024 * 1024, // Megabytes
        "G": 1024 * 1024 * 1024, // Gigabytes
        "T": 1024 * 1024 * 1024 * 1024, // Terabytes
        "P": 1024 * 1024 * 1024 * 1024 * 1024, // Petabytes
        "E": 1024 * 1024 * 1024 * 1024 * 1024 * 1024 // Exabytes
    ]
    
  let trimmed = input.drop { $0.isWhitespace || $0.isNewline }.uppercased()
    let regex = try! Regex("^([0-9]+)([BKMGTPE]?)$")
    
    guard let match = try regex.firstMatch(in: trimmed) else {
        throw ExpandNumberError.invalidFormat
    }
    
  guard let numberString = match.output[1].substring else {
    throw ExpandNumberError.invalidFormat
  }
    
    guard let number = UInt64(numberString) else {
        throw ExpandNumberError.invalidFormat
    }
    
    var multiplier: UInt64 = 1
  if let mr = match.output[2].range {
      if let suffix = trimmed[mr].first {
        multiplier = suffixMultipliers[suffix] ?? 1
      } else {
          multiplier = 1
      }
    }
    
    let result = number.multipliedReportingOverflow(by: multiplier)
    if result.overflow {
        throw ExpandNumberError.overflow
    }
    
    return result.partialValue
}

// **Example Usage**
/* do {
    print(try expandNumber("10K"))  // 10240
    print(try expandNumber("5M"))   // 5242880
    print(try expandNumber("2G"))   // 2147483648
    print(try expandNumber("1T"))   // 1099511627776
    print(try expandNumber("100"))  // 100 (default is bytes)
    print(try expandNumber("10P"))  // 11258999068426240
} catch {
    print("Error: \(error)")
}
*/
