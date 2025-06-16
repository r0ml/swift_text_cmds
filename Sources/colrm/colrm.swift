
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  Copyright (c) 1991, 1993
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

@main final class colrm : ShellCommand {

  var usage : String = "usage: colrm [start [stop]]"
  
  struct CommandOptions {
    var start = 0
    var stop = 0
    var args : [String] = CommandLine.arguments
    var inFile : FilePath = "-"
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "f:"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "f":
          options.inFile = FilePath(v)
        default: throw CmdErr(1)
      }
    }
    let a = go.remaining
    switch a.count {
      case 2:
          if let stop = Int(a[1]),
             stop > 0 {
            options.stop = stop
          } else {
            throw CmdErr(1, "illegal column -- \(a[1])")
          }
        fallthrough
      case 1:
        if let start = Int(a[0]),
           start > 0 {
          options.start = start
        } else {
          throw CmdErr(1, "illegal column -- \(a[0])")
        }
      case 0:
        break
      default:
        throw CmdErr(1)
    }
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    let TAB = 8
    do {
      var fd = options.inFile == "-" ? FileDescriptor.standardInput : try FileDescriptor(forReading: options.inFile.string)
      for try await buf in fd.bytes.lines(true) {
        var column = 0
        let bx = buf.compactMap { ch in
          switch ch {
            case "\u{08}":
              if column > 0 { column -= 1 }
            case "\t":
              column = (column + TAB) & ~(TAB - 1)
            case "\n":
              column = 0
            default:
              let width =
              ch.unicodeScalars.reduce(0, { $0 +  Darwin.wcwidth(Int32($1.value) ) } )
              if width > 0 {
                column += Int(width)
              }
          }
          if options.start == 0 || column < options.start || (options.stop > 0 && column > options.stop) {
            return ch
          } else {
            return nil
          }
        }
        print(String(bx), terminator: "")
      }
    } catch {
      throw CmdErr(1, "error reading input: \(error)")
    }
               
  }
}
