
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
 * SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1993
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


import Foundation
import CMigration

let BUFSIZ: Int = 8192
let LINE_MAX: Int = 1024 // Adjust as needed

@main final class rs : ShellCommand {

  var usage : String = "usage: rs [-[csCS][x][kKgGw][N]tTeEnyjhHmz] [rows [cols]]"
  
  struct CommandOptions {
    var colwidths: [Int16] = []
    var cord: [Int16] = []
    var icbd: [Int16] = []
    var ocbd: [Int16] = []
    var nelem: Int = 0
    var elem: [String] = []
    var irows: Int = 0
    var icols: Int = 0
    var orows: Int = 0
    var ocols: Int = 0
    var maxlen: Int = 0
    var skip: Int = 0
    var propgutter: Int = 0
    var osep: Character = " "
    var blank: String = ""
    var owidth: Int = 80
    var gutter: Int = 2

    var flags : RSFlag = []
    var isep : Character = " "
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "Ttc::s::C::S::w:K::k::mg::G::eEjnyHhzpo:b:B:"
    let go = BSDGetopt(supportedFlags)
    
    if CommandLine.arguments.count == 1 {
      options.flags.insert([.NOARGS,.TRANSPOSE])
    }
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "T":
          options.flags.insert(.MTRANSPOSE)
            fallthrough
        case "t":
          options.flags.insert(.TRANSPOSE)
        case "c":
          options.flags.insert(.ONEISEPONLY)
          fallthrough
        case "s":
          options.isep = v.isEmpty ? "\t" : v.first!
        case "C":
          options.flags.insert(.ONEOSEPONLY)
          fallthrough
        case "S":
          options.osep = v.isEmpty ? "\t" : v.first!
        case "w":
          if let o = Int(v) {
            if o <= 0 {
              throw CmdErr(1, "width must be a positive integer")
            }
            options.owidth = o
          } else {
            throw CmdErr(1, "invalid integer: \(v)")
          }
        case "K":
          options.flags.insert(.SKIPPRINT)
            fallthrough
        case "k":
          if v.isEmpty {
            options.skip = 1
          } else if let k = Int(v) {
            options.skip = k == 0 ? 1 : k
          } else {
            throw CmdErr(1, "invalid integer: \(v)")
          }
        case "m":
          options.flags.insert(.NOTRIMENDCOL)
        case "g":
          if v.isEmpty {
            options.gutter = 2
          } else if let k = Int(v) {
            options.gutter = k
          }
        case "G":
          if v.isEmpty {
            options.propgutter = 0
          } else if let k = Int(v) {
            options.propgutter = k
          }
        case "e":
          options.flags.insert(.ONEPERLINE)
        case "E":
          options.flags.insert(.ONEPERCHAR)
        case "j":
          options.flags.insert(.RIGHTADJUST)
        case "n":
          options.flags.insert(.NULLPAD)
        case "y":
          options.flags.insert(.RECYCLE)
        case "H":
          options.flags.insert(.DETAILSHAPE)
            fallthrough
        case "h":
          options.flags.insert(.SHAPEONLY)
        case "z":
          options.flags.insert(.SQUEEZE)
        case "o":
          try getlist(&options.cord, v)
            // Adjust p based on returned newP if necessary
        case "b":
          options.flags.insert(.ICOLBOUNDS)
          try getlist(&options.icbd, v)
        case "B":
          options.flags.insert(.OCOLBOUNDS)
          try getlist(&options.ocbd, v)
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    
    switch options.args.count {
    case 2:
        if let cols = Int(options.args[1]), cols >= 0 {
          options.ocols = cols
        } else {
          options.ocols = 0
        }
        fallthrough
    case 1:
        if let rows = Int(options.args.first!), rows >= 0 {
          options.orows = rows
        } else {
          options.orows = 0
        }
    case 0:
        break
    default:
        throw CmdErr(1, "too many arguments")
    }
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    var opts = options
    
    do {
      try await try_fileContents(&opts)
    } catch {
      throw CmdErr(1, "reading input: \(error.localizedDescription)")
    }
    
    if opts.flags.contains(.SHAPEONLY) {
      print("\(opts.irows) \(opts.icols)")
    } else {
      prepfile(&opts)
      putfile(opts)
    }
  }

  // MARK: - Constants

  struct RSFlag : OptionSet {
    let rawValue : Int
    
    static let TRANSPOSE = RSFlag(rawValue: 0o000001)
    static let MTRANSPOSE = RSFlag(rawValue: 0o000002)
    static let ONEPERLINE = RSFlag(rawValue: 0o000004)
    static let ONEISEPONLY = RSFlag(rawValue: 0o000010)
    static let ONEOSEPONLY = RSFlag(rawValue: 0o000020)
    static let NOTRIMENDCOL = RSFlag(rawValue: 0o000040)
    static let SQUEEZE = RSFlag(rawValue: 0o000100)
    static let SHAPEONLY = RSFlag(rawValue: 0o000200)
    static let DETAILSHAPE = RSFlag(rawValue: 0o000400)
    static let RIGHTADJUST = RSFlag(rawValue: 0o001000)
    static let NULLPAD = RSFlag(rawValue: 0o002000)
    static let RECYCLE = RSFlag(rawValue: 0o004000)
    static let SKIPPRINT = RSFlag(rawValue: 0o010000)
    static let ICOLBOUNDS = RSFlag(rawValue: 0o020000)
    static let OCOLBOUNDS = RSFlag(rawValue: 0o040000)
    static let ONEPERCHAR = RSFlag(rawValue: 0o0100000)
    static let NOARGS = RSFlag(rawValue: 0o0200000)
  }
  

  // MARK: - Global Variables


  // Buffer equivalent
  var ibuf: [Character] = Array(repeating: "\0", count: LINE_MAX * 2)

  /*
  func INCR(ep: inout Int) {
      ep += 1
      if ep >= endelem.count {
          endelem = getptrs(Array(elem[ep...]))
      }
  }
   */

  func try_fileContents(_ options : inout CommandOptions) async throws {
    var multisep = !options.flags.contains(.ONEISEPONLY) ? 1 : 0
    let nullpad = options.flags.contains(.NULLPAD)
      
    
    var flines = FileHandle.standardInput.bytes.lines.makeAsyncIterator()
    
    for _ in 0..<options.skip {
      if let curline = try await flines.next() {
        if options.flags.contains(.SKIPPRINT) {
          print(curline)
        }
      } else {
        return
      }
    }
      
    guard let firstLine = try await flines.next() else {
      return
    }
    
    if options.flags.contains(.NOARGS) && firstLine.count < options.owidth {
      options.flags.insert(.ONEPERLINE)
    }
      
    if options.flags.contains(.ONEPERLINE) {
      options.icols = 1
      } else {
        let m = firstLine.split(separator: options.isep, omittingEmptySubsequences: !options.flags.contains(.ONEISEPONLY) )          // Count columns on first line
        options.icols = m.count
      }
      
    while let curline = try await flines.next() {
        if options.flags.contains(.ONEPERLINE) {
          options.elem.append(curline)
          if curline.count > options.maxlen {
            options.maxlen = curline.count
              }
          options.irows += 1
              continue
          }
          
      let components = curline.split(separator: options.isep, omittingEmptySubsequences: !options.flags.contains(.ONEISEPONLY)).map { String($0) }
          for component in components {
            if component == String(options.isep) {
              options.elem.append(options.blank)
              } else {
                options.elem.append(component)
                if component.count > options.maxlen {
                    options.maxlen = component.count
                  }
              }
          }
        options.irows += 1
          
          if nullpad {
            while options.elem.count < options.irows * options.icols {
              options.elem.append(options.blank)
              }
          }
      }
      
    options.nelem = options.elem.count
  }

  /*
  func get_line() -> Int {
      guard let line = readLine() else {
          return EOF
      }
      curline = line
      curlen = line.count
      return 0 // Indicate not EOF
  }
*/
  
  func getlist(_ list: inout [Int16], _ p: String) throws(CmdErr) {
      let components = p.split(separator: ",")
      for component in components {
          if let num = Int16(component) {
              list.append(num)
          } else {
            throw CmdErr(1, "option requires a list of unsigned numbers separated by commas")
          }
      }
  }

  func getnum(_ num: inout Int, _ p: String, _ strict: Bool) -> String {
      if let parsedNum = Int(p) {
          num = parsedNum
      } else {
          if strict {
              fatalError("option \(p.prefix(1)) requires an unsigned integer")
          }
          num = 0
      }
      return "" // Placeholder
  }
  
  /*
  func getptrs(_ sp: [String]) -> [String] {
      allocsize *= 2
      elem.reserveCapacity(allocsize)
      return elem
  }
   */

  func prepfile(_ opts : inout CommandOptions) {
    if opts.nelem == 0 {
          exit(0)
      }
      
    opts.gutter += Int(Double(opts.maxlen) * Double(opts.propgutter) / 100.0)
    let colw = opts.maxlen + opts.gutter
      
    if opts.flags.contains(.MTRANSPOSE) {
      opts.orows = opts.icols
      opts.ocols = opts.irows
    } else if opts.orows == 0 && opts.ocols == 0 {
      opts.ocols = opts.owidth / colw
      if opts.ocols == 0 {
        warnx("display width \(opts.owidth) is less than column width \(colw)")
        opts.ocols = 1
          }
      opts.ocols = min(opts.ocols, opts.nelem)
      opts.orows = opts.nelem / opts.ocols + (opts.nelem % opts.ocols > 0 ? 1 : 0)
    } else if opts.orows == 0 {
      opts.orows = opts.nelem / opts.ocols + (opts.nelem % opts.ocols > 0 ? 1 : 0)
    } else if opts.ocols == 0 {
      opts.ocols = opts.nelem / opts.orows + (opts.nelem % opts.orows > 0 ? 1 : 0)
      }
      
    let lp = opts.orows * opts.ocols
    while opts.elem.count < lp {
      if opts.flags.contains(.RECYCLE) {
        opts.elem.append(contentsOf: opts.elem)
          } else {
            opts.elem.append(opts.blank)
          }
      }
      
    if opts.flags.contains(.RECYCLE) {
      opts.nelem = lp
      }
      
    if opts.flags.contains(.SQUEEZE) {
      opts.colwidths = Array(repeating: 0, count: opts.ocols)
      if opts.flags.contains(.TRANSPOSE) {
        for i in 0..<opts.ocols {
                  var max = 0
          for j in 0..<opts.orows {
            let index = j * opts.ocols + i
            if index < opts.nelem {
              let length = opts.elem[index].count
                          if length > max {
                              max = length
                          }
                      }
                  }
          opts.colwidths[i] = Int16(max + opts.gutter)
              }
          } else {
            for i in 0..<opts.ocols {
                  var max = 0
              for j in stride(from: i, to: opts.nelem, by: opts.ocols) {
                    let length = opts.elem[j].count
                      if length > max {
                          max = length
                      }
                  }
              opts.colwidths[i] = Int16(max + opts.gutter)
              }
          }
      } else {
        opts.colwidths = Array(repeating: Int16(colw), count: opts.ocols)
      }
      
    if !opts.flags.contains(.NOTRIMENDCOL) {
      if opts.flags.contains(.RIGHTADJUST) {
        opts.colwidths[0] -= Int16(opts.gutter)
      } else if opts.ocols > 0 {
        opts.colwidths[opts.ocols - 1] = 0
          }
      }
      
    let n = opts.orows * opts.ocols
    if n > opts.nelem && opts.flags.contains(.RECYCLE) {
      opts.nelem = n
      }
  }

  func prints(_ s: String, _ col: Int, _ opts : CommandOptions) {
      let n: Int
    if opts.flags.contains(.ONEOSEPONLY) {
          n = 1
      } else {
        n = Int(opts.colwidths[col]) - s.count
      }
      
    if opts.flags.contains(.RIGHTADJUST) {
          for _ in 0..<n {
            print(String(opts.osep), terminator: "")
          }
      }
      
      print(s, terminator: "")
      
      for _ in 0..<n {
        print(String(opts.osep), terminator: "")
      }
  }

  func putfile(_ opts : CommandOptions) {
    if opts.flags.contains(.TRANSPOSE) {
      for i in 0..<opts.orows {
        for j in stride(from: i, to: opts.nelem, by: opts.orows) {
          prints(opts.elem[j], j / opts.orows, opts)
              }
              print("")
          }
      } else {
          var k = 0
        for _ in 0..<opts.orows {
          for j in 0..<opts.ocols {
            if k < opts.nelem {
              prints(opts.elem[k], j, opts)
                      k += 1
                  }
              }
              print("")
          }
      }
  }

}
