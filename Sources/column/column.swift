
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file with the following notice:

/*
 SPDX-License-Identifier: BSD-3-Clause
 
 Copyright (c) 1989, 1993, 1994
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

@main final class column : ShellCommand {
  
  var usage : String = "usage: column [-tx] [-c columns] [-s sep] [file ...]"
  let TAB = 8
  
  struct CommandOptions {
    
    var termwidth = 80
    var separator : String = "\t "
    var tflag = false
    var xflag = false
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "c:s:tx"
    let go = BSDGetopt(supportedFlags)

    while let (k, v) = try go.getopt() {
      switch k {
        case "c":
          if let a = Int(v) {
            options.termwidth = a
          }
        case "s":
          options.separator = v
        case "t":
          options.tflag = true
        case "x":
          options.xflag = true
        case "?":
          fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand() throws(CmdErr) {
    var data = String()
    var se = FileDescriptor.standardError
    var eval = 0
    
    if options.args.count == 0 {
      do {
        let d = try FileDescriptor.standardInput.readToEnd()
        let s = String(decoding: d, as: UTF8.self)
        data.append(s)
      } catch {
        "stdin: \(error)".write(to: &se)
        eval = 1
      }
    } else {
      for a in options.args {
        do {
          let fp = try FileDescriptor(forReading: a)
          let d = try fp.readToEnd()
             let s = String(decoding: d, as: UTF8.self) 
            data.append(s)
          try fp.close()
        } catch {
          "\(a): \(error)\n".write(to: &se)
          eval = 1
        }
      }
    }
    let list = data.split(separator: "\n").map { l in l.trimmingPrefix(while:  {c in c.isWhitespace} ) }
    if list.count == 0 {
      throw CmdErr(eval, "")
    }
    
    if options.tflag {
      try maketbl(list: list, separator: options.separator)
    } else {
      let maxlength = roundup(1 + list.reduce( 0, { max($0, $1.wcwidth()) }), TAB )
      if maxlength >= options.termwidth {
        for lp in list {
          print(lp)
        }
      } else {
//        if options.xflag {
//       c_columnate(list: list, termwidth: options.termwidth)
//      } else {
        columnate(list: list, termwidth: options.termwidth, options.xflag)
      }
    }
    if eval != 0 { throw CmdErr(eval, "") }
  }
  
 
  func roundup( _ n : Int, _ m : Int) -> Int {
    return m * ( n + m - 1 ) / m  }
  
/*  func c_columnate(list: [Substring], termwidth: Int) {
    let maxlength = roundup(1 + list.reduce( 0, { max($0, $1.wcwidth()) }), TAB )
    let numcols = termwidth / maxlength
    let numrows = (list.count + numcols - 1) / numcols

    for row in 0..<numrows {
      let rr = (row*numcols)..<min((row+1)*numcols, list.count)
      for base in rr.dropLast() {
        // Print the item
        print(list[base], terminator: "")
        // Update character count for alignment
        let chcnt = list[base].wcwidth()
        let tc = (maxlength - chcnt + TAB - 1 ) / TAB
        
        print( String(repeating: "\t", count: tc), terminator: "")
      }
      print(list[rr.last!])
     }
  }
  */
  
  func columnate(list: [Substring], termwidth: Int, _ xflag: Bool) {
    let maxlength = roundup(1 + list.reduce( 0, { max($0, $1.wcwidth()) }), TAB )
    let numcols = termwidth / maxlength
    if numcols < 2 {
      for i in list {
        print(i)
      }
      return
    }
    let numrows = (list.count + numcols - 1) / numcols
    
    for row in 0..<numrows {
      let rr = xflag ? Array((row*numcols)..<min((row+1)*numcols, list.count)) :
                Array(stride(from: row, to: list.count, by: numrows))
      for base in rr.dropLast() {
        // Print the item in the current row and column
        print(list[base], terminator: "")
        
        // Update character count for alignment
        let chcnt = list[base].wcwidth()
        let tc = (maxlength - chcnt + TAB - 1 ) / TAB

        print( String(repeating: "\t", count: tc), terminator: "")
      }
      // last column
      print(list[rr.last!])
    }
  }
  
  
  func maketbl(list: [Substring], separator: String) throws(CmdErr) {
    
    let tbl = list.map { lin in lin.split(omittingEmptySubsequences: true, whereSeparator: { separator.contains($0) } ) }
    let lens = tbl.reduce(into: [Int]() ) { lens, row in
      let m = row.map { $0.wcwidth() }
      while lens.count < m .count { lens.append(0) }
      (0..<m.count).forEach { lens[$0] = max(lens[$0], m[$0]) }
    }
    // Print the table
    for t in tbl {
      for x in 0..<t.count - 1 {
        let c = t[x]
        let paddedValue = c + String(repeating: " ", count: lens[x] - c.wcwidth() + 2)
        print(paddedValue, terminator: "")
      }
      if let lastColumn = t.last {
        print(lastColumn)
      }
    }
    
  }

}
