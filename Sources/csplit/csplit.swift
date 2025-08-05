
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

import signal_h
import time_h

import Darwin // for gettimeofday and uuid_generate


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

  var _overfile : AsyncLineReader.AsyncIterator? { // Overflow file for toomuch()
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

  var origsrcx : AsyncLineReader.AsyncIterator!
  var srcx : AsyncLineReader.AsyncIterator!

  var isof : Bool = false

  // A repetition count used with patterns.
  var reps = 0


  func parseOptions() throws(CmdErr) -> CommandOptions {
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
    if options.prefix.count + options.sufflen >= MAXPATHLEN {
      throw CmdErr(1, "name too long")
    }

    options.infn = options.args.removeFirst()
    return options
  }

  func runCommand(_ options: CommandOptions) async throws(CmdErr) {

    var infn = options.infn

    // Open the input file.
    if infn == "-" {
      origsrcx = FileDescriptor.standardInput.bytes.lines.makeAsyncIterator()
      // Use standard input.
      infn = "stdin"
    } else {

      do {
        origsrcx = try FileDescriptor(forReading: infn ).bytes.lines.makeAsyncIterator()
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

    var carryover : String? = nil

    // Create files based on supplied patterns
    while nfiles < maxfiles-1,
          !exprs.isEmpty {
      let expr = exprs.removeFirst()

      // Look ahead & see if thsi pattern has any repetitions
      if exprs.first?.first == "{" {
        let repss = exprs.removeFirst()
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
          try await do_rexp(expr: expr, &carryover, options)
          reps -= 1
        } while reps >= 0 && nfiles < maxfiles - 1
      } else if expr.first?.isNumber == true {
        try await do_lineno(expr: expr, options)
      } else {
        throw CmdErr(1, "\(expr): unrecognised pattern")
      }
    }

    try await restOfFile(carryover, options)
  }

    /// Copy the rest of the input into a new file.

  func restOfFile(_ prevline : String?, _ options : CommandOptions) async throws(CmdErr) {
    // FIXME: need to check that there is more data to read
    //    if feof(inFile) {

    ofp = try newfile(options)
    if let prevline {
      print(prevline, to: &ofp)
    }

    do {
      while true {
        guard let p = try await srcx.next() else { break }
        lineno += 1
        print(p, to: &ofp)
      }

      if !options.sflag {
        let k = try ofp.seek(offset: 0, from: .current)
        print("\(k)")
      }
      try ofp.close()
    } catch {
      throw CmdErr(1, "read or write error: \(error)")
    }

    doclean.withLock { $0 = false }
    await Task.yield()
  }

  /*
   Explanation
   •  Signal Handling & Cleanup:
   The C code’s signal handler and atexit(3) registration are reproduced by installing our C–compatible handlesig function and calling atexit (available via Darwin).
   */


  /// Create a new output file based on the current nfiles count.
  /// The filename is created by concatenating the prefix with the nfiles number,
  /// zero–padded to the requested width.
  func newfile(_ options : CommandOptions) throws(CmdErr) -> FileDescriptor {
    // Construct the file name.
    let numStr = cFormat("%0\(options.sufflen)d", nfiles)
    currfile = options.prefix + numStr
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
/*  func get_line() async throws(CmdErr) -> String? {
    // If there are overflow lines waiting, return them first.

    while true {
      do {
        if let lbuf = try await srcx.next() {
          lineno += 1
          return lbuf
        }
      } catch {
        throw CmdErr(1, "reading: \(error)")
      }

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
  }
*/



  /// Conceptually rewind the input (as obtained by get_line()) back `n' lines.
  func toomuch(file: FileDescriptor?, _ nn: Int) throws(CmdErr) {
    var n = nn
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
        try ofp.seek(offset: kk, from: .start)
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
      _overfile = ofp.bytes.lines.makeAsyncIterator()
      truncofs = x
    } catch {
      throw CmdErr(1, "\(currfile): \(error)")
    }
  }


  // MARK: - Pattern Handlers

  /// Handle /regexp/ and %regexp% patterns.
  func do_rexp(expr: String, _ prevline : inout String?, _ options : CommandOptions) async throws(CmdErr) {

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

    // FIXME: convert the string to a Basic regex (see grep or sed)
    // Compile the regex.
    var regex : Regex<Substring>
    do {
      regex = try Regex(String(re))
    } catch {
      throw CmdErr(1, "\(re): bad regular expression")
    }

    // For a '/' pattern we create a permanent new file.
    // For a '%' pattern we create a temporary file.
    if delim == "/" {
      ofp = try newfile(options)
    } else {
      // Create a temporary file.
      let tempName = globallyUniqueString()
      do {
        ofp = try FileDescriptor.open(tempName, .readWrite, options: [.create], permissions: [.ownerReadWrite])
        try ofp.seek(offset: 0, from: .start)
      } catch {
        throw CmdErr(1, "tmpfile open failed: \(error)")
      }
      filesToClean.withLock { $0.append(tempName) }
    }

    var first = true
    if let prevline {
      print(prevline, to: &ofp)
      first = false
    }

    var matched = false
    do {
      while let line = try await srcx.next() {
        lineno += 1

        // After the first line, check if the current line matches the regex.
        if !first {
          do {
            let k = try regex.firstMatch(in: line)

            if k != nil {
              matched = true
              if ofs > 0 {
                print(line, to: &ofp)
              } else {
                prevline = line
              }
              break
            }
          } catch {
            throw CmdErr(1, "regex failed: \(re)")
          }
        }
        print(line, to: &ofp)
        first = false
      }
    } catch(let e) {
      throw CmdErr(1, "read error: \(e)")
    }

    // If no match was found, clean up and exit.
    if !matched {
      throw CmdErr(1, "\(re): no match")
    }

    if ofs < 0 {
      // For negative offset: “rewind” the file by (-ofs) lines.
      try toomuch(file: ofp, -ofs)
    } else {
      // For positive offset: copy requested number of lines after the match
      for _ in 0..<ofs {
        do {
          if let line = try await srcx.next() {
            lineno += 1
            print(line, to: &ofp)
          }
        } catch(let e) {
          throw CmdErr(1, "read error: \(e)")
        }
      }
    }

    if !options.sflag && delim == "/" {
      let oo = try! ofp.seek(offset: 0, from: .current)
      print("\(oo)")
    }
    do {
      try ofp.close()
    } catch {
      throw CmdErr(1, "\(currfile): \(error)")
    }
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
      var ofp = try newfile(options)
      // Write lines until we have written (lastline - 1) lines.
      while (lineno + 1) != lastline {
        do {
          guard let line = try await srcx.next() else {
            throw CmdErr(1, "\(lastline): out of range")
          }
          lineno += 1
          print(line, to: &ofp)
        } catch(let e) {
          throw CmdErr(1, "read error: \(e)")
        }
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
  signal_h.signal(signal, SIG_DFL)
  raise(signal)
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
  Darwin.uuid_generate(&uuid)

  let uuidHex = uuid.map { byte in
    String(byte, radix: 16, uppercase: true).leftPad(toLength: 2, withPad: "0")
  }.joined()

  let uuidFormatted = "\(uuidHex.prefix(8))-\(uuidHex.dropFirst(8).prefix(4))-\(uuidHex.dropFirst(12).prefix(4))-\(uuidHex.dropFirst(16).prefix(4))-\(uuidHex.dropFirst(20).prefix(12))"

  // Use gettimeofday for microsecond timestamp
  var tv = time_h.timeval()
  Darwin.gettimeofday(&tv, nil)
  let microseconds = UInt64(tv.tv_sec) * 1_000_000 + UInt64(tv.tv_usec)

  // Get PID
  let pid = UInt64(getpid())

  // Combine time + pid and format
  let suffix = String(microseconds ^ pid, radix: 16, uppercase: true).leftPad(toLength: 16, withPad: "0")

  return "\(uuidFormatted)-\(suffix)"
}
