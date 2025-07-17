// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
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
import locale_h
import stdlib_h


let SILLY: Int = Int.max // Represents a value that should never be a genuine line length
let MAX_TABSTOPS = 100    // Maximum number of tab stops

@main final class expand : ShellCommand {
  
  var usage : String = "usage: expand [-t tablist] [file ...]"
  
  struct CommandOptions {
    var nstops: Int = 0
    var tabstops: [Int] = Array(repeating: 0, count: MAX_TABSTOPS)
    
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "0123456789t:"
    let go = BSDGetopt(supportedFlags)
    
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "t":
          try getstops(cp: v, &options)
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    setlocale(LC_CTYPE, "")

    var rval : Int32 = 0
    
    if !options.args.isEmpty {
      for file in options.args {
        do {
          if file == "-" {
            // Read from standard input
            try processInput(fileHandle: FileDescriptor.standardInput, curfile: "stdin", options: options)
          } else {
            // Open the file
//            let url = URL(fileURLWithPath: file)
            let fileHandle = try FileDescriptor(forReading: file)
            try processInput(fileHandle: fileHandle, curfile: file, options: options)
            try fileHandle.close()
          }
        } catch {
          warn("Warning: \(file): \(error)")
          rval = 1
        }
      }
    } else {
      do {
        // No files provided, read from standard input
        try processInput(fileHandle: FileDescriptor.standardInput, curfile: "stdin", options: options)
      } catch {
        warn("Warning: stdin: \(error)")
        rval = 1
      }
    }
    stdlib_h.exit(rval)
  }
  
  
  /// Parses the tab stops from a given string.
  /// - Parameter cp: A string containing comma or space-separated tab stop numbers.
  func getstops(cp: String, _ options : inout CommandOptions) throws(CmdErr) {
    var currentIndex = cp.startIndex
    options.nstops = 0
    
    while currentIndex < cp.endIndex {
      // Skip any leading whitespace or commas
      while currentIndex < cp.endIndex && (cp[currentIndex].isWhitespace || cp[currentIndex] == ",") {
        currentIndex = cp.index(after: currentIndex)
      }
      
      // Parse the number
      var numberString = ""
      while currentIndex < cp.endIndex && cp[currentIndex].isNumber {
        numberString.append(cp[currentIndex])
        currentIndex = cp.index(after: currentIndex)
      }
      
      if numberString.isEmpty {
        throw CmdErr(Int(stdlib_h.EXIT_FAILURE), "Error: bad tab stop spec")
      }
      
      if let number = Int(numberString), number > 0 {
        if options.nstops > 0 && number <= options.tabstops[options.nstops - 1] {
          throw CmdErr(Int(stdlib_h.EXIT_FAILURE), "Error: bad tab stop spec")
        }
        if options.nstops >= MAX_TABSTOPS {
          throw CmdErr(Int(stdlib_h.EXIT_FAILURE), "Error: too many tab stops")
        }
        options.tabstops[options.nstops] = number
        options.nstops += 1
      } else {
        throw CmdErr(Int(stdlib_h.EXIT_FAILURE), "Error: bad tab stop spec")
      }
      
      // After a number, expect a comma or whitespace or end of string
      if currentIndex < cp.endIndex && cp[currentIndex] != "," && !cp[currentIndex].isWhitespace {
        throw CmdErr(Int(stdlib_h.EXIT_FAILURE), "Error: bad tab stop spec")
      }
    }
  }
  
  /// Writes a message to stderr.
  /// - Parameter message: The message to write.
  func warn(_ message: String) {
    FileDescriptor.standardError.write("\(message)\n")
  }
  

  
  /// Processes input from a given file handle.
  /// - Parameters:
  ///   - fileHandle: The file handle to read from.
  ///   - curfile: The current file name being processed.
  func processInput(fileHandle: FileDescriptor, curfile: String, options: CommandOptions) throws {
    var column = 0
    
    // Read data in chunks]
    while true {
      let data = try fileHandle.readUpToCount(4096)
      if data.count == 0 { break }
      
      // Convert data to a string using the current locale's encoding
      let string = String(decoding: data, as: UTF8.self)
      //else {
      //  warn("Warning: Could not decode data from \(curfile)")
      //  exit(EXIT_FAILURE)
      // }
      
      // Iterate over each Unicode scalar in the string
      for wc in string {

        switch wc {
          case "\t":
            if options.nstops == 0 {
              // Default tab stops every 8 columns
              let nextTab = ((column / 8) + 1) * 8
              let spacesToAdd = nextTab - column
              for _ in 0..<spacesToAdd {
                print(" ", terminator: "")
                column += 1
              }
            } else if options.nstops == 1 {
              // Single tab stop
              let tabStop = options.tabstops[0]
              while ((column - 1) % tabStop) != (tabStop - 1) {
                print(" ", terminator: "")
                column += 1
              }
            } else {
              // Multiple tab stops
              var n: Int = 0
              while n < options.nstops && options.tabstops[n] <= column {
                n += 1
              }
              if n == options.nstops {
                print(" ", terminator: "")
                column += 1
              } else {
                let tabStop = options.tabstops[n]
                while column < tabStop {
                  print(" ", terminator: "")
                  column += 1
                }
              }
            }
            
          case "\u{07}":
            if column > 0 {
              column -= 1
            }
            print("\u{07}", terminator: "")
            
          case "\n":
            print("\n", terminator: "")
            column = 0
            
          default:
            print(wc, terminator: "")
            let width = wc.wcwidth
            if width > 0 {
              column += width
            }
        }
      }
    }
  }
  
}

