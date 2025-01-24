
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1990, 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Kevin Ruddy.
 
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


import Foundation
import Shared

// Constants
let DEFLINEWIDTH = 80

@main final class fold : ShellCommand {
  

  var usage : String = "usage: fold [-bs] [-w width] [file ...]"
  
  struct CommandOptions {
    // Global Flags
    var bflag = false   // Count bytes, not columns
    var sflag = false   // Split on word boundaries
    var width : Int = DEFLINEWIDTH
    
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "0123456789bsw:"
    let go = BSDGetopt(supportedFlags)
    
    var previousCh: Character? = nil

    theWhile: while let (k, v) = try go.getopt() {
      switch k {
        case "-":
          break theWhile
        case "b":
          options.bflag = true
        case "s":
          options.sflag = true
        case "w":
            if let w = Int(v), w > 0 {
              options.width = w
            } else {
            throw CmdErr(1, "illegal width value")
          }
        case "0"..."9":
          if let prev = previousCh, ("0"..."9").contains(prev) {
            options.width = options.width * 10 + Int(String(k))!
          } else if options.width == DEFLINEWIDTH {
            options.width = Int(String(k))!
          }
        default: throw CmdErr(1)
      }
      previousCh = k
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    // Collect remaining arguments as files
    let files = options.args
    
    var rval : Int32 = 0
    
    if files.isEmpty {
      // Read from standard input
      if let input = readStdin() {
        let folded = fold(width: options.width, input: input, options: options)
        print(folded, terminator: "")
      }
    } else {
      for file in files {
        if file == "-" {
          if let input = readStdin() {
            let folded = fold(width: options.width, input: input, options: options)
            print(folded, terminator: "")
          }
          continue
        }
        
        do {
          let input = try String(contentsOfFile: file, encoding: .utf8)
          let folded = fold(width: options.width, input: input, options: options)
          print(folded, terminator: "")
        } catch {
          FileHandle.standardError.write("fold: \(file): \(error.localizedDescription)\n".data(using: .utf8)!)
          rval = 1
        }
      }
    }
    
    exit(rval)
  }
  
  // ==========================================================
  
  
  // Function to update the current column position for a character
  func newpos(col: Int, ch: Character, _ options : CommandOptions) -> Int {
    var column = col
    if options.bflag {
      // In Swift, counting bytes can be done using UTF8 encoding
      if let byte = ch.utf8.first {
        column += 1
      }
    } else {
      switch ch {
        case "\u{8}": // Backspace
          if column > 0 {
            column -= 1
          }
        case "\r": // Carriage return
          column = 0
        case "\t": // Tab
          column = (column + 8) & ~7
        default:
          // Using Unicode scalar width
          let width = wcwidthSwift(ch: ch)
          if width > 0 {
            column += width
          }
      }
    }
    return column
  }
  
  // Helper function to determine character width
  func wcwidthSwift(ch: Character) -> Int {
    // Simplified version: Assume width 1 for most characters
    // Implement more accurate width calculation if needed
    return 1
  }
  
  // Fold Function
  func fold(width: Int, input: String, options: CommandOptions) -> String {
    var output = ""
    var col = 0
    var buf = ""
    var spaceIndex: Int? = nil
    
    for ch in input {
      if ch == "\n" {
        output += buf + "\n"
        buf = ""
        col = 0
        spaceIndex = nil
        continue
      }
      
      let newColumn = newpos(col: col, ch: ch, options)
      if newColumn > width {
        if options.sflag, let space = spaceIndex {
          // Split at the last space
          let splitIndex = buf.index(buf.startIndex, offsetBy: space + 1)
          let line = String(buf[..<splitIndex])
          output += line + "\n"
          buf = String(buf[splitIndex...])
          col = newpos(col: 0, ch: ch, options)
        } else {
          // Split at the current position
          output += buf + "\n"
          buf = ""
          col = newpos(col: 0, ch: ch, options)
        }
      }
      
      buf.append(ch)
      col = newColumn
      
      if options.sflag, ch.isWhitespace {
        spaceIndex = buf.count - 1
      }
    }
    
    // Append any remaining buffer
    if !buf.isEmpty {
      output += buf
    }
    
    return output
  }
  
  // Helper function to read from standard input
  func readStdin() -> String? {
    let inputHandle = FileHandle.standardInput
    let data = inputHandle.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)
  }
  
}
