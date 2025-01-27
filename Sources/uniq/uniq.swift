
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1989, 1993
 *  The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Case Larsen.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

import Foundation
import CMigration

@main final class uniq : ShellCommand {

  var usage : String = "Not yet implemented"
  
  var long_opts : [CMigration.option] = [
    option("all-repeated", .optional_argument),
    option("count",  .no_argument),
    option("repeated", .no_argument),
    option("skip-fields", .required_argument),
    option("ignore-case", .no_argument),
    option("skip-chars", .required_argument),
    option("unique", .no_argument),
  ]
  struct CommandOptions {
    var Dflag : Dflag = .DF_NONE
    var cflag = false
    var dflag = false
    var iflag = false
    var uflag = false
    var numchars : Int = 0
    var numfields : Int = 0
    var args : [String] = CommandLine.arguments
  }
  
  enum Dflag {
    case DF_NONE
    case DF_NOSEP
    case DF_PRESEP
    case DF_POSTSEP
  }

  func obsolete(_ args : ArraySlice<String>) -> [String] {
    var res = Array(args)
    for i in res.indices {
      if res[i].hasPrefix("-") || res[i].hasPrefix("+") {
        if res[i].hasPrefix("--") {
          return res
        }
        if res[i].dropFirst().first?.isNumber == true {
          res[i] = (res[i].first == "+" ? "-s" : "-f") + res[i].dropFirst()
        }
      } else {
        return res
      }
    }
    return res
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let a = CommandLine.arguments.dropFirst()
    let args = obsolete(a)
    
    let go = BSDGetopt_long("+D::cdf:is:u", long_opts, args)
    
    while let (k, v) = try go.getopt_long() {
      switch k {
          
        case "D", "all-repeated":
          if v == "none" || v.isEmpty { options.Dflag = .DF_NOSEP }
          else if v == "prepend" { options.Dflag = .DF_PRESEP }
          else if v == "separate" { options.Dflag = .DF_POSTSEP }
          else {
            throw CmdErr(1)
          }
        case "c", "count":
          options.cflag = true
        case "d", "repeated":
          options.dflag = true
        case "i", "ignore-case":
          options.iflag = true
        case "f", "skip-fields":
          if let n = Int(v) {
            options.numfields = n
          } else {
            throw CmdErr(1, "field skip value: \(v)")
          }
        case "s", "skip-chars":
          if let n = Int(v) {
            options.numchars = n
          } else {
            throw CmdErr(1, "character skip value is \(v)")
          }
        case "u", "unique":
          options.uflag = true
        case "?": throw CmdErr(1)
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    if options.args.count > 2 {
      throw CmdErr(1)
    }
    if options.Dflag != .DF_NONE && options.dflag {
      options.dflag = false
    }
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    do {
      
      if options.args.count == 0 || options.args[0] == "-" {
        for try await line in FileHandle.standardInput.bytes.lines {
          doLine(line, options)
        }
      } else {
        for try await line in URL(fileURLWithPath: options.args[0]).lines {
          doLine(line, options)
        }
      }
      doLine(nil, options)
      
    } catch(let e) {
      throw CmdErr(1, e.localizedDescription)
    }
  }
  
  func skip(_ line : String, _ options : CommandOptions) -> String {
    var lx = Substring(line)
    for _ in 0..<options.numfields {
      lx = lx.drop { $0.isWhitespace }
      lx = lx.drop { !$0.isWhitespace }
    }
    lx = lx.dropFirst(options.numchars)
    return String(lx)
  }
  
  func convert(_ line : String, _ options : CommandOptions) -> String {
    var linex : String = line
    if options.numfields > 0 || options.numchars > 0 {
      linex = skip(line, options)
    }
    
    return options.iflag ? linex.lowercased() : linex
  }
  
  func show(_ s : String, _ options : CommandOptions) {
    if options.cflag {
      print( String(format: "%4ld ", repeats+1) + s)
    } else {
      print(s)
    }
    fflush(stdout)
  }
  
  var tprev : String? = nil
  var prevline : String? = nil
  var ff = true
  var repeats = 0

  func doLine(_ line : String?, _ options : CommandOptions) {
    
    if let line, ff && (!options.cflag && options.Dflag == .DF_NONE && !options.dflag && !options.uflag) {
      show(line, options)
    }
    
    if ff {
      if let prevline,
         options.cflag || options.Dflag != .DF_NONE || options.dflag || options.uflag {
        if options.Dflag == .DF_NONE &&
            (!options.dflag || (options.cflag && repeats > 0)) &&
            (!options.uflag || repeats == 0) {
          show(prevline, options)
        }
      }
      
      prevline = line
      if let line {
        tprev = convert(line, options)
      } else {
        tprev = nil
      }
      ff = false
      
      return
    }
    
    let thisline = line
    let tthis = line == nil ? nil : convert(line!, options)
    
    let comp = tthis == tprev
    
    if comp {
      if options.Dflag != .DF_NONE {
        if repeats == 0 {
          if options.Dflag == .DF_PRESEP {
            show("", options)
          }
          show(prevline!, options)
        }
        if let thisline { show(thisline, options) }
      } else if options.dflag && !options.cflag {
        if repeats == 0 {
          show(prevline!, options)
        }
      }
      repeats += 1
    } else {
      // If different, print; set previous to new value.
      if options.Dflag == .DF_POSTSEP && repeats > 0 {
        show("", options)
      }
      if !options.cflag && options.Dflag == .DF_NONE && !options.dflag && !options.uflag {
        if let thisline { show(thisline, options) }
      } else if options.Dflag == .DF_NONE &&
                  (!options.dflag || (options.cflag && repeats > 0)) &&
                  (!options.uflag || repeats == 0) {
        show(prevline!, options)
      }
      prevline = thisline
      tprev = tthis
      repeats = 0
    }
  }
}
