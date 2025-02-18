
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

import Foundation
import CMigration

@main final class tail : ShellCommand {
  
  var usage : String = """
Usage: tail [-F | -f | -r] [-q] [-b # | -c # | -n #] [file ...]
"""
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "belnstuv"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    throw CmdErr(1, usage)
  }
  
  // Enum to define different tail styles
  enum TailStyle {
    case notSet
    case fBytes
    case rBytes
    case fLines
    case rLines
    case reverse
  }
  
  // Global variables for command-line options
  var byteOffset: Int64 = 0
  var chunkOffset: Int64 = 0
  var numLines: Int64 = 0
  var followFlag: Bool = false
  var followWithRetry: Bool = false
  var quietFlag: Bool = false
  var verboseFlag: Bool = false
  var reverseFlag: Bool = false
  var style: TailStyle = .notSet
  
  // MARK: - Command-line Argument Parsing
  
  func parseArguments() {
    var args = CommandLine.arguments.dropFirst() // Ignore the first argument (executable name)
    
    while !args.isEmpty {
      let arg = args.removeFirst()
      
      switch arg {
        case "-F":
          followWithRetry = true
          followFlag = true
        case "-f":
          followFlag = true
        case "-q":
          quietFlag = true
          verboseFlag = false
        case "-v":
          verboseFlag = true
          quietFlag = false
        case "-r":
          reverseFlag = true
        case "-b":
          if let value = args.first, let num = Int64(value) {
            args.removeFirst()
            setTailStyle(units: 512, offset: num, forward: .fBytes, backward: .rBytes)
          } else {
            usage()
          }
        case "-c":
          if let value = args.first, let num = Int64(value) {
            args.removeFirst()
            setTailStyle(units: 1, offset: num, forward: .fBytes, backward: .rBytes)
          } else {
            usage()
          }
        case "-n":
          if let value = args.first, let num = Int64(value) {
            args.removeFirst()
            setTailStyle(units: 1, offset: num, forward: .fLines, backward: .rLines)
          } else {
            usage()
          }
        default:
          // Treat argument as a filename
          filePaths.append(arg)
      }
    }
    
    if style == .notSet {
      if reverseFlag {
        byteOffset = 0
        style = .reverse
      } else {
        byteOffset = 10
        style = .rLines
      }
    }
    
    if reverseFlag, followFlag {
      usage() // Reverse and follow flags are incompatible
    }
  }
  
  // Helper function to determine forward/backward tail styles
  func setTailStyle(units: Int64, offset: Int64, forward: TailStyle, backward: TailStyle) {
    guard style == .notSet else { usage() }
    
    if offset > Int64.max / units || offset < Int64.min / units {
      print("Illegal offset: \(offset)")
      exit(1)
    }
    
    let offsetValue = offset * units
    switch String(offset).prefix(1) {
      case "+":
        byteOffset = offsetValue - units
        style = forward
      case "-":
        byteOffset = -offsetValue
        style = backward
      default:
        style = backward
    }
  }
  
  // MARK: - Tail Implementation
  
  var filePaths: [String] = []
  
  func tailFiles() {
    if filePaths.isEmpty {
      tailFile(stdin, fileName: "stdin")
    } else {
      for (index, filePath) in filePaths.enumerated() {
        if let file = fopen(filePath, "r") {
          if verboseFlag || (!quietFlag && filePaths.count > 1) {
            print("\(index > 0 ? "\n" : "")==> \(filePath) <==")
          }
          tailFile(file, fileName: filePath)
          fclose(file)
        } else {
          print("Cannot open file: \(filePath)")
        }
      }
    }
  }
  
  // Tail implementation for a single file
  func tailFile(_ file: UnsafeMutablePointer<FILE>, fileName: String) {
    var statBuffer = stat()
    
    if fstat(fileno(file), &statBuffer) == -1 {
      print("Error accessing file: \(fileName)")
      return
    }
    
    if S_ISDIR(statBuffer.st_mode) {
      return // Ignore directories
    }
    
    if reverseFlag {
      tailReverse(file, fileName: fileName, style: style, offset: byteOffset, statBuffer: statBuffer)
    } else {
      tailForward(file, fileName: fileName, style: style, offset: byteOffset, statBuffer: statBuffer)
    }
  }
  
  // Placeholder function for forward tail
  func tailForward(_ file: UnsafeMutablePointer<FILE>, fileName: String, style: TailStyle, offset: Int64, statBuffer: stat) {
    var buffer = [CChar](repeating: 0, count: 8192)
    while fgets(&buffer, Int32(buffer.count), file) != nil {
      print(String(cString: buffer), terminator: "")
    }
  }
  
  // Placeholder function for reverse tail
  func tailReverse(_ file: UnsafeMutablePointer<FILE>, fileName: String, style: TailStyle, offset: Int64, statBuffer: stat) {
    print("Reverse tail for \(fileName) is not implemented yet")
  }

}
