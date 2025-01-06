// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1989, 1993, 1994
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Case Larsen.
 
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

@main final class comm : ShellCommand {

  var usage : String = "usage: comm [-123i] file1 file2"
  
  struct CommandOptions {
    var flag1 = true
    var flag2 = true
    var flag3 = true
    var iflag = false
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "123i?"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        case "1":
          options.flag1 = false
        case "2":
          options.flag2 = false
        case "3":
          options.flag3 = false
        case "i":
          options.iflag = true
        case "?":
          fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    if options.args.count != 2 { throw CmdErr(1, usage) }
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    var fp1 : FileHandle
    var fp2 : FileHandle
    do {
      fp1 = try FileHandle(forReadingFrom: URL(filePath: options.args[0]))
      fp2 = try FileHandle(forReadingFrom: URL(filePath: options.args[1]))
    } catch {
      throw CmdErr(1, "unable to read input files: \(error.localizedDescription)")
    }

    /* for each column printed, add another tab offset */
   let col1 = options.flag1 ? "" : nil
    let col2 = options.flag2 ? String(repeating: "\t", count: col1 != nil ? 1 : 0) : nil
    let col3 = options.flag3 ? String(repeating: "\t", count: (col1 != nil ? 1 : 0) + (col2 != nil ? 1 : 0) ) : nil
    
    var fpi1 = fp1.bytes.lines.makeAsyncIterator()
    var fpi2 = fp2.bytes.lines.makeAsyncIterator()
    
    var read1 = true
    var read2 = true
    var line1 : String?
    var line2 : String?

    while true {
      /* read next line, check for EOF */
      if read1 {
        do {
          line1 = try await fpi1.next()
        } catch {
          throw CmdErr(1, "\(options.args[0]): \(error.localizedDescription)")
        }
      }
      if read2 {
        do {
          line2 = try await fpi2.next()
        } catch {
          throw CmdErr(1, "\(options.args[1]): \(error.localizedDescription)")
        }
      }
      
      if line1 == nil {
        if let line2 {
          try await show(fpi2, options.args[1], col2, line2)
          break
          
        }
      }
      if line2 == nil {
        if let line1 {
          try await show(fpi1, options.args[0], col1, line1)
          break
        }
      }
      
      let tline1 = options.iflag ? line1?.lowercased() : line1
      let tline2 = options.iflag ? line2?.lowercased() : line2
      let cmp = tline1!.compare(tline2!)
      
      if cmp == .orderedSame {
        read1 = true
        read2 = true
        if let col3 {
          print("\(col3)\(line1!)")
        }
      } else if cmp == .orderedAscending {
        read1 = true
        read2 = false
        if let col1 {
          print("\(col1)\(line1!)")
        }
      } else {
        read1 = false
        read2 = true
        if let col2 {
          print("\(col2)\(line2!)")
        }
      }
      
    }
    
  }
  
  
  
  func show(_ fp : AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator, _ fn : String, _ offset : String?, _ line2 : String) async throws(CmdErr) {
    var fpi = fp
    var buf2 : String? = line2
    do {
      while buf2 != nil {
        /* offset is NULL when draining fp, not printing (rdar://89062040) */
        if let offset {
          print("\(offset)\(buf2!)")
        }
        buf2 = try await fpi.next()
      }
    } catch {
      throw CmdErr(1, "\(fn): \(error.localizedDescription)")
    }
  }

}
