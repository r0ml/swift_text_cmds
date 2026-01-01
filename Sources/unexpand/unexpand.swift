
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1980, 1993
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

@main final class unexpand : ShellCommand {
  
  var usage : String = "usage: unexpand [-a | -t tablist] [file ...]"
  
  struct CommandOptions {
    var all = false
    var tabstops : [Int] = [8]
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "at:"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "a": // Un-expand all spaces, not just leading
          options.all = true
        case "t": // Specify tab list, implies -a.
          options.tabstops = try getstops(v)
          options.all = true
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand() async throws(CmdErr) {
    if options.args.isEmpty {
      do {
        try await tabify(FileDescriptor.standardInput, "stdin")
      } catch {
        warn("stdin")
      }
    } else {
      for filename in options.args {
        do {
//          let u = URL(filePath: filename)
          let fh = try FileDescriptor(forReading: filename)
          try await tabify(fh, filename)
        } catch {
          warn(filename)
        }
      }
    }
  }
  
  
  func tabify(_ fh : FileDescriptor, _ curfile : String) async throws(CmdErr) {
//    int dcol, doneline, limit, n, ocol, width;
//    wint_t ch;

    let limit = options.tabstops.count == 1 ? Int.max : options.tabstops.last! - 1;

    var dcol = 0
    var ocol = 0
    var doneline = false
    var n = 0
    var writingRestOfLine = false
    do {
      for try await ch in fh.characters {
        if writingRestOfLine {
          if ch != "\n" {
            FileDescriptor.standardOutput.write(String(ch))
            continue
          }
          FileDescriptor.standardOutput.write(String(ch))
          writingRestOfLine = false
          dcol = 0
          ocol = 0
          doneline = false
        }
        
        
        //    while ((ch = getwchar()) != WEOF) {
        if (ch == " " && !doneline) {
          dcol += 1
          if dcol >= limit {
            doneline = true
          }
          continue
        } else if ch == "\t" {
          if options.tabstops.count == 1 {
            dcol = (1 + dcol / options.tabstops[0]) * options.tabstops[0];
            continue
          } else {
            n = 0
            while n < options.tabstops.count &&
                    options.tabstops[n] - 1 < dcol {
              n += 1
            }
            if (n < options.tabstops.count - 1 && options.tabstops[n] - 1 < limit) {
              dcol = options.tabstops[n];
              continue;
            }
            doneline = true
          }
        }
        
        /* Output maximal number of tabs. */
        if options.tabstops.count == 1 {
          while (((ocol + options.tabstops[0]) / options.tabstops[0])
                 <= (dcol / options.tabstops[0])) {
            if (dcol - ocol < 2) {
              break;
            }
            FileDescriptor.standardOutput.write("\t")
            ocol = (1 + ocol / options.tabstops[0]) * options.tabstops[0]
          }
        } else {
          n = 0
          while n < options.tabstops.count && options.tabstops[n] - 1 < ocol {
            n += 1
          }
          while (ocol < dcol && n < options.tabstops.count && ocol < limit) {
            FileDescriptor.standardOutput.write("\t")
            n += 1
            ocol = options.tabstops[n]
          }
        }
        
        /* Then spaces. */
        while (ocol < dcol && ocol < limit) {
          FileDescriptor.standardOutput.write(" ")
          ocol += 1
        }
        
        if (ch == "\u{08}") {
          FileDescriptor.standardOutput.write("\u{08}")
          if ocol > 0 {
            ocol -= 1
            dcol -= 1
          }
        } else if (ch == "\n") {
          FileDescriptor.standardOutput.write("\n");
          doneline = false
          ocol = 0
          dcol = 0
          continue;
        } else if (ch != " " || dcol > limit) {
          FileDescriptor.standardOutput.write( String(ch) )
//          let cc = ch.unicodeScalars.first!.value
          let width = ch.wcwidth // Int(wcwidth(wchar_t(cc)))
          if (width > 0) {
            ocol += width
            dcol += width
          }
        }
        
        /*
         * Only processing leading blanks or we've gone past the
         * last tab stop. Emit remainder of this line unchanged.
         */
        if (!options.all || dcol >= limit) {
          writingRestOfLine = true
        }
      }
    } catch {
//    if (ferror(stdin)) {
      warn(curfile)
    }
  }
  
  
  func getstops(_ cpx: String) throws(CmdErr) -> [Int] {
    var cp = Substring(cpx)
    let digits = "0123456789"
    var tabstops : [Int] = []
    while true {
      var i = 0
      
      // Parse the number
      
      while let n = digits.firstIndex(of: cp.first ?? " ") {
        let nn = digits.distance(from: digits.startIndex, to: n)
        i = i * 10 + nn
        cp.removeFirst()
      }
      
      // Check if the number is valid
      if i <= 0 {
        throw CmdErr(1, "bad tab stop spec")
      }
      if !tabstops.isEmpty && i <= tabstops.last! {
        throw CmdErr(1, "bad tab stop spec")
      }
      // don't worry about "too many tab stops"
      
      // Add the stop
      tabstops.append(i)
      
      if cp.isEmpty { break }
      let fcp = cp.removeFirst()
      if fcp != "," && !fcp.isWhitespace  {
        throw CmdErr(1, "bad tab stop spec")
      }
    }
    return tabstops
  }
}
