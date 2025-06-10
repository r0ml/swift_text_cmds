
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 
  Copyright (c) 2002 Tim J. Robbins.
  All rights reserved.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */


/*
 * csplit -- split files based on context
 *
 * This utility splits its input into numbered output files by line number
 * or by a regular expression. Regular expression matches have an optional
 * offset with them, allowing the split to occur a specified number of
 * lines before or after the match.
 *
 * To handle negative offsets, we stop reading when the match occurs and
 * store the offset that the file should have been split at, then use
 * this output file as input until all the "overflowed" lines have been read.
 * The file is then closed and truncated to the correct length.
 *
 * We assume that the output files can be seeked upon (ie. they cannot be
 * symlinks to named pipes or character devices), but make no such
 * assumption about the input.
 */

import CMigration
import Synchronization

let doclean = Mutex(false)
let filesToClean = Mutex<[String]>([])

@main final class csplit : ShellCommand {
  
  var usage : String = "usage: csplit [-ks] [-f prefix] [-n number] file args ..."
  
  struct CommandOptions {
    var kflag = false
    var sflag = false
    var prefix = "xx"
    var sufflen = 2
    var infn = ""
    var args : [String] = CommandLine.arguments
  }
  
  var currfile = ""
  var nfiles = 0
  var maxfiles = 0
  var lineno: Int64 = 0
  var truncofs: Int64 = 0
  var ofp: FileDescriptor!
  
  // Instead of FILE* we read the entire input into an array of lines.
  var inputLines = [String]()
  var inputIndex = 0
  
  var _overfile : FileDescriptor? { // Overflow file for toomuch()
    didSet {
      if _overfile == nil {
        isof = false
        srcx = origsrcx
      } else {
        origsrcx = srcx
        isof = true
        srcx = _overfile!
//        print("set _overfile")
      }
    }
  }
  
  var origsrcx : FileDescriptor! //  AsyncLineSequence<FileDescriptor.AsyncBytes>.AsyncIterator?
  
  var srcx : FileDescriptor! //  AsyncLineSequence<FileDescriptor.AsyncBytes>.AsyncIterator!
    
  var isof : Bool = false
  
  // A repetition count used with patterns.
  var reps = 0
  
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    // FIXME: setlocale has disappeared!
    // setlocale(LC_ALL, "")
    
    var options = CommandOptions()
    let supportedFlags = "ksf:n:"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "k":
          options.kflag = true
        case "s":
          options.sflag = true
        case "f":
          options.prefix = v
        case "n":
          guard let num = Int(v), num > 0 else {
            throw CmdErr(1, "\(v): bad suffix length")
          }
          options.sufflen = num
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    
    // Make sure there is an input file.
    if options.args.count < 1 {
      throw CmdErr(1)
    }
    
    
    // Check that the output file name (prefix + suffix) won’t be too long.
    //    let PATH_MAX = 1024
    if options.prefix.count + options.sufflen >= PATH_MAX {
      throw CmdErr(1, "name too long")
    }
    
    options.infn = options.args.removeFirst()
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    
    var infn = options.infn
    
    // Open the input file.
    if infn == "-" {
      origsrcx = FileDescriptor.standardInput
      // Use standard input.
      infn = "stdin"
    } else {
      
      do {
        origsrcx = try FileDescriptor(forReading: infn )
      } catch {
        throw CmdErr(1, "Cannot open file \(infn)")
      }
    }
    srcx = origsrcx

    if !options.kflag {
        doclean.withLock { $0 = true }
        atexit(cleanup)
        
        var sa = sigaction()
        sa.sa_flags = 0;
        sa.__sigaction_u.__sa_handler = handlesig //    sa_handler = handlesig
        sigemptyset(&sa.sa_mask)
        sigaddset(&sa.sa_mask, SIGHUP)
        sigaddset(&sa.sa_mask, SIGINT)
        sigaddset(&sa.sa_mask, SIGTERM)
        sigaction(SIGHUP, &sa, nil)
        sigaction(SIGINT, &sa, nil)
        sigaction(SIGTERM, &sa, nil)
    }
    
    lineno = 0
    nfiles = 0
    truncofs = 0
    
    // Calculate maxfiles = 10^sufflen, ensuring we don’t overflow.
    if options.sufflen > 16 {
      throw CmdErr(1, "\(options.sufflen): suffix too long (limit 16)")
    }
    maxfiles = 10^options.sufflen
    
    var exprs = options.args
    
    // Create files based on supplied patterns
    while nfiles < maxfiles-1,
          !exprs.isEmpty {
      let expr = exprs.removeFirst()
      
      // Look ahead & see if thsi pattern has any repetitions
      if exprs.first?.first == "{" {
        var repss = exprs.removeFirst()
        let rs = repss.dropFirst()
        if rs.last == "}",
           let r = Int(rs.dropLast()) {
          reps = r
        } else {
          throw CmdErr(1, "\(repss): bad repetition count")
        }
      } else {
        reps = 0
      }
      
      // Dispatch the expression to the appropriate handler.
      if expr.first == "/" || expr.first == "%" {
        repeat {
          try await do_rexp(expr: expr, options)
          reps -= 1
        } while reps >= 0 && nfiles < maxfiles - 1
      } else if expr.first?.isNumber == true {
        try await do_lineno(expr: expr, options)
      } else {
        throw CmdErr(1, "\(expr): unrecognised pattern")
      }
    }
    
    // Copy the rest of the input into a new file.
    
    // FIXME: need to check that there is more data to read
    //    if feof(inFile) {
    
    ofp = try newfile(options)
    
    do {
      while true {
        guard let p = try await get_line() else { break }
        // FIXME: handle encoding correctly
        let pp = p.utf8
        try? ofp.write(Array(pp))
      }
      
      if !options.sflag {
        let k = try ofp.seek(offset: 0, from: .current)
        print("\(k)")
      }
      try ofp.close()
    } catch {
      throw CmdErr(1, "read or write error: \(error)")
    }
  
  try toomuch(file: nil, 0)
    doclean.withLock { $0 = false }
   await Task.yield()
}
  
  
  
  /*
   Okay, the user wants me to convert a block of C code, specifically from the csplit program, to Swift. The C code involves a lot of libraries, signals, file I/O, and regex functions. I’ll need to rewrite the code while preserving its functionality but in Swift style.
   There are several functions to convert, like usage(), handlesig(), and newfile(), plus handling things like macros and platform-specific code for macOS.
   I’ll focus on getting the behavior right, even if I can’t make it fully correct right away!
   
   This is a big task! I’ll start by converting the main function and some key pieces.
   The C code takes command-line arguments, handles file input/output, and does signal handling. In Swift, I’ll handle the arguments using CommandLine.arguments and manually parse them, instead of relying on getopt().
   I’ll also convert macOS-specific #ifdef __APPLE__ parts but keep in mind Swift is mostly for macOS. I’ll make sure to correctly implement locale setting, flags, and the file handling logic.
   
   I’ll start converting the key functions such as usage(), handlesig(), and newfile() into Swift.
   For file handling, Swift’s FileDescriptor seems a good alternative to C’s FILE*. I’ll handle reading lines and writing files similarly to how C did with fgets() and fopen(), using Swift’s capabilities like readLine() for line-by-line reading.
   I’ll need to manage output file creation, signal handling (using DispatchSourceSignal or signal() from Darwin), and error handling, which will be adjusted to Swift’s error handling style.
   
   Converting file handling in Swift will involve using FileDescriptor for reading from files, but I’ll likely load the entire file into an array and simulate line-by-line reading with an index. I’ll keep track of the current file pointer using this index, and for the overflow file (overfile), I can use a similar approach with a separate array.
   The logic for functions like get_line() and toomuch() needs to simulate file pointers, which is tricky since files may be large. I think I’ll stick to converting the structure first.
   
   In Swift, I plan to use FileDescriptor for reading and writing files. For reading lines, I’ll load the entire input content into an array and simulate reading line-by-line using an index. If there’s an overflow file (overfile), I can simulate it by using a separate array (overflowLines).
   For managing file creation and regular expressions, I’ll implement newfile() to create files based on a prefix and a counter. The do_rexp(expr:) function will use NSRegularExpression to apply pattern matching and output the results to files.
   I’ll also implement toomuch() to adjust the line reading appropriately. It’s not a complete simulation, but it should work for the conversion.
   */
  
  /*
   Explanation
   •  Global State & I/O:
   We “load” the entire input file into an array (inputLines) and use an index variable to simulate reading line–by–line. An additional array (overflowLines) stands in for the temporary overflow file.
   •  Signal Handling & Cleanup:
   The C code’s signal handler and atexit(3) registration are reproduced by installing our C–compatible handlesig function and calling atexit (available via Darwin).
   •  Pattern Dispatch:
   The functions do_rexp(expr:) and do_lineno(expr:) re–implement the behavior of splitting the input at a regular–expression match or at a given line number. In a production Swift program you might use Swift’s NSRegularExpression and more robust file I/O.
   •  File Creation:
   The function newfile() builds an output file name by combining the prefix with a zero–padded count and creates the file on disk.
   
   This Swift code is one approach to “porting” the C code. In practice you might refactor and simplify many parts (for example, using Swift’s streaming I/O or more structured error handling), but the code above shows one direct translation of the original C logic into Swift.
   
   */
  
 
  /// Create a new output file based on the current nfiles count.
  /// The filename is created by concatenating the prefix with the nfiles number,
  /// zero–padded to the requested width.
  func newfile(_ options : CommandOptions) throws(CmdErr) -> FileDescriptor {
    // Construct the file name.
    let numStr = cFormat("%0\(options.sufflen)d", nfiles)
    currfile = options.prefix + numStr

    // Create an empty file.
//    let fm = FileManager.default
//    if fm.createFile(atPath: currfile, contents: nil, attributes: nil) == false {
//      throw CmdErr(1, "Cannot create file \(currfile)")
//    }

    filesToClean.withLock { $0.append(currfile) }
    do {
      let fp = try FileDescriptor.open(currfile, .readWrite, options: [.create, .truncate], permissions: [.ownerReadWrite])
      try fp.seek(offset: 0, from: .start)
      nfiles += 1
      return fp
    } catch {
      throw CmdErr(1, "Cannot open file \(currfile): \(error)")
    }
  }
  
  
  /// Read the next line from the “input” (or overflow) and update the global line counter.
  func get_line() async throws(CmdErr) -> String? {
    // If there are overflow lines waiting, return them first.
    
    while true {
      do {
        guard let lbuf = try srcx.fgets(Int(LINE_MAX)) else {
          if isof {
            if let _overfile {
              // Truncate the previous file we overflowed into back to
              // the correct length, close it.
              //      if (fflush(overfile) != 0)
              //        err(1, "overflow");
              do {
                fsync(_overfile.rawValue)
                try _overfile.resize(to: truncofs)
                try _overfile.close()
              } catch {
                throw CmdErr(1, "overflow: \(error)" )
              }
              self._overfile = nil
            }
            isof = false
            continue
          }
          return nil
        }
        lineno += 1
        return lbuf
      } catch {
        throw CmdErr(1, "reading: \(error)")
      }
    }
  }
  


  
  /// Conceptually rewind the input (as obtained by get_line()) back `n' lines.
  func toomuch(file: FileDescriptor?, _ nn: Int) throws(CmdErr) {
    var n = nn
    /*
    if let _overfile {
      // Truncate the previous file we overflowed into back to
      // the correct length, close it.
//      if (fflush(overfile) != 0)
//        err(1, "overflow");
      do {
        try _overfile.synchronize()
        try _overfile.truncate(atOffset: truncofs)
        try _overfile.close()
      } catch {
        throw CmdErr(1, "overflow: \(error.localizedDescription)" )
      }
      self._overfile = nil
    }
*/


    if n == 0 { return }
    lineno -= Int64(n)

    
    do {
      // Wind the overflow file backwards to `n' lines before the
      // current one.

      var x = Int64.max
    outer:
      repeat {
        let k = try ofp.seek(offset: 0, from: .current)
        let kk = k < BUFSIZ ? 0 : k - Int64(BUFSIZ)
        try ofp.seek(offset: kk, from: .start)
        let buf = try ofp.readUpToCount(Int(BUFSIZ))
//f            errx(1, "can't read overflowed output");
        try ofp.seek(offset: kk, from: .start)
//            err(1, "%s", currfile);
        for (i, c) in buf.reversed().enumerated() {
          if c == 10 {
            if n == 0 {
              x = kk + Int64(buf.count - i)
              break outer }
            n -= 1
          }
        }
        if kk == 0 {
          x = 0
          break;
        }
      } while n > 0
      try ofp.seek(offset: x, from: .start)
      
    // get_line() will read from here. Next call will truncate to
    // truncofs in this file.
    _overfile = ofp
    truncofs = x
    } catch {
      throw CmdErr(1, "\(currfile): \(error)")
    }
  }
  
  
  // MARK: - Pattern Handlers
  
  /// Handle /regexp/ and %regexp% patterns.
  func do_rexp(expr: String, _ options : CommandOptions) async throws(CmdErr) {
    
    guard !expr.isEmpty else {
      throw CmdErr(1, "empty regexp")
    }
    
    let delim: Character = expr.first!
    var re = expr.dropFirst()
    let z = re.lastIndex(of: delim)
    
    var ofs = 0
    if let z,
       re[re.index(z, offsetBy: -1)] != "\\" {
      let pofs = re[z...].dropFirst()
      re = re[re.startIndex..<z]
      if !pofs.isEmpty {
        if let oo = Int(pofs) {
          ofs = oo
        } else {
          throw CmdErr(1, "\(pofs): bad offset")
        }
      }
    } else {
      throw CmdErr(1, "\(expr): missing trailing \(delim)")
    }
    
    // Compile the regex.
    var regex : Regex<Substring>
    do {
      regex = try Regex(String(re))
      //                                      options: delim == "/" ? [.anchorsMatchLines] : [])
    } catch {
      throw CmdErr(1, "\(re): bad regular expression")
    }
    
    var cre = regex_t()
    
    if regcomp(&cre, String(re), REG_BASIC|REG_NOSUB|REG_NEWLINE) != 0 {
      throw CmdErr(1, "\(re): bad regular expression")
    }
    
    
    // For a '/' pattern we create a permanent new file.
    // For a '%' pattern we create a temporary file.
    if delim == "/" {
      ofp = try newfile(options)
    } else {
      // Create a temporary file.
      let tempName = globallyUniqueString()
//      let fm = FileManager.default
//      if fm.createFile(atPath: tempName, contents: nil, attributes: nil) == false {
//        throw CmdErr(1, "tmpfile creation failed")
//      }
      do {
        ofp = try FileDescriptor.open(tempName, .readWrite, options: [.create], permissions: [.ownerReadWrite])
        try ofp.seek(offset: 0, from: .start)
      } catch {
        throw CmdErr(1, "tmpfile open failed: \(error)")
      }
      filesToClean.withLock { $0.append(tempName) }
    }
    

    
    var first = true
    var matched = false
    while let line = try await get_line() {
      // Write the line (with a newline) to the output file.
//      if let data = line.data(using: .utf8) {
//        do {
          ofp.write(line)
//        } catch {
//          throw CmdErr(1, "\(currfile): \(error)")
//        }
//      }
      // After the first line, check if the current line matches the regex.
      if !first {
        do {
          let k = try regex.firstMatch(in: line)
          
          if k != nil {
            matched = true
            break
          }
        } catch {
          throw CmdErr(1, "regex failed: \(re)")
        }
      }
      first = false
    }
    
    // If no match was found, clean up and exit.
    if !matched {
      try toomuch(file: nil, 0)
      throw CmdErr(1, "\(re): no match")
    }
    
    if ofs <= 0 {
      // For negative or zero offset: “rewind” the file by (-ofs + 1) lines.
      try toomuch(file: ofp, -ofs + 1)
    } else {
      // For positive offset: copy requested number of lines after the match
      for _ in 1..<ofs {
        if let line = try await get_line() {
//          if let data = line.data(using: .utf8) {
//            do {
              try ofp.write(line)
//            } catch {
//              throw CmdErr(1, "\(currfile): \(error)")
//            }
//          }
        }
      }
      try toomuch(file: nil, 0)
      do {
        try ofp.close()
      } catch {
        throw CmdErr(1, "\(currfile): \(error)")
      }
    }
    
    if !options.sflag && delim == "/" {
      let oo = try! ofp.seek(offset: 0, from: .current)
      print("\(oo)")
    }
    
    // Clean up the regex (NSRegularExpression releases resources automatically).
  }
  
  /// Handle splits based on line number.
  func do_lineno(expr: String, _ options : CommandOptions) async throws(CmdErr) {
    guard let tgtline = Int(expr), tgtline > 0 else {
      throw CmdErr(1, "\(expr): bad line number")
    }
    var lastline = tgtline
    if lastline <= Int(lineno) {
      throw CmdErr(1, "\(expr): can't go backwards")
    }
    
    while nfiles < Int(maxfiles) - 1 {
      let ofp = try newfile(options)
      // Write lines until we have written (lastline - 1) lines.
      while (lineno + 1) != lastline {
        guard let line = try await get_line() else {
          throw CmdErr(1, "\(lastline): out of range")
        }
//        if let data = line.data(using: .utf8) {
//          do {
            ofp.write(line)
//          } catch {
//            throw CmdErr(1, "\(currfile): \(error)")
//          }
//        }
      }
      if !options.sflag {
        let oo = try! ofp.seek(offset: 0, from: .current)
        print("\(oo)")
      }
      do {
        try ofp.close()
      } catch {
        throw CmdErr(1, "\(currfile): \(error)")
      }
      if reps <= 0 { break }
      reps -= 1
      lastline += tgtline
    }
  }
  
}

/// Our signal handler. (In the __APPLE__ case we re–raise the signal after cleanup.)
@_cdecl("handlesig")
func handlesig(signal: Int32) {
  // On non–Apple systems we could simply _exit(2), but here we do cleanup and re–raise.
  // Reset to default handler and re–raise:
  Darwin.signal(signal, SIG_DFL)
  Darwin.raise(signal)
}

/// Remove any partial output files created.
func cleanup() {
  if (doclean.withLock { $0 } ) {
    let k = filesToClean.withLock { $0 }
//    let fm = FileManager.default
    for i in k {
      unlink(i)
    }
  }
}


extension FileDescriptor {
  public func fgets(_ n : Int? = nil) throws -> String? {
    let nn = n ?? Int.max
    let off = try self.seek(offset: 0, from: .current)
    let nc = try self.readUpToCount(nn)
    if nc.isEmpty { return nil }
    let j = if let k = nc.firstIndex(of: 10) {
      Array(nc.prefix(through: k))
    } else {
      nc
    }
    // position after the last carriage return
    try self.seek(offset: off+Int64(j.count), from: .start)
    let s = String(decoding: j, as: UTF8.self)
    return s
  }
}

enum StringEncodingError: Error {
    case invalid(String)
}


// ============

private extension String {
    func leftPad(toLength: Int, withPad character: Character) -> String {
        if self.count >= toLength { return self }
        return String(repeating: character, count: toLength - self.count) + self
    }
}

public func globallyUniqueString() -> String {
    // Generate UUID
  var uuid: [UInt8] = Array(repeating: 0, count: 16)
  uuid_generate(&uuid)

    let uuidHex = uuid.map { byte in
        String(byte, radix: 16, uppercase: true).leftPad(toLength: 2, withPad: "0")
    }.joined()

    let uuidFormatted = "\(uuidHex.prefix(8))-\(uuidHex.dropFirst(8).prefix(4))-\(uuidHex.dropFirst(12).prefix(4))-\(uuidHex.dropFirst(16).prefix(4))-\(uuidHex.dropFirst(20).prefix(12))"

    // Use gettimeofday for microsecond timestamp
    var tv = timeval()
    gettimeofday(&tv, nil)
    let microseconds = UInt64(tv.tv_sec) * 1_000_000 + UInt64(tv.tv_usec)

    // Get PID
    let pid = UInt64(getpid())

    // Combine time + pid and format
    let suffix = String(microseconds ^ pid, radix: 16, uppercase: true).leftPad(toLength: 16, withPad: "0")

    return "\(uuidFormatted)-\(suffix)"
}
