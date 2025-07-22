// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-4-Clause
 
  Copyright (c) 1991 Keith Muller.
  Copyright (c) 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Keith Muller of the University of California, San Diego.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  3. All advertising materials mentioning features or use of this software
     must display the following acknowledgement:
   This product includes software developed by the University of
   California, Berkeley and its contributors.
  4. Neither the name of the University nor the names of its contributors
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

import Darwin

/*
 * parameter defaults
 */
let CLCNT  = 1
let INCHAR : Character = "\t"
let INGAP  = 8
let OCHAR : Character = "\t"
let OGAP   = 8
let LINES  = 66
let NMWD   = 5
let NMCHAR : Character = "\t"
let SCHAR : Character = "\t"
let PGWD   = 72
let SPGWD  = 512

/*
 * misc default values
 */
let HDFMT    = "%s %s Page %d\n\n\n"
let HEADLEN  = 5
let TAILLEN  = 5
let TIMEFMTD = "%e %b %H:%M %Y"
let TIMEFMTM = "%b %e %H:%M %Y"
let FNAME    = ""
let LBUF     = 8192
let HDBUF    = 512

// structure for vertical columns. Used to balance cols on last page
/*struct vcol {
  var pt : Int // col (offset into buf)
  var cnt : Int   // char count
}
*/

@main final class pr : ShellCommand {

  var usage : String = """
usage: pr [+page] [-col] [-adFfmprt] [-e[ch][gap]] [-h header]
          [-i[ch][gap]] [-l line] [-n[ch][width]] [-o offset]
          [-L locale] [-s[ch]] [-w width] [-] [file ...]
"""

  struct CommandOptions {
    var c = 0
    var d_first = false
    var eflag = false
    var iflag = false
    var wflag = false
    var cflag = false
    var Lflag : String?

    var pgnm = 0         // starging page number
    var clcnt = 0        // number of columns
    var colwd = 0        // column data width - multiple columns
    var across = false   // mult col flag; write across page
    var dspace = false   // double space flag
    var inchar : Character = " " // expand input char
    var ingap = 0        // expand input gap
    var pausefst = false // pause before first page
    var pauseall = false // pause before each page
    var formfeed = false // use formfeed as trailer
    var header : String? // header name instead of file name
    var ochar : Character = " " // contract output char
    var ogap = 0        // contract output gap
    var lines = 0       // number of lines per page
    var merge = false   // merge multiple files in output
    var nmchar : Character = " " // line numbering append char
    var nmwd = 0        // width of line number field
    var offst = 0       // number of page offset spaces
    var nodiag = false  // do not report file open errors
    var schar : Character = "\t" // text column separation character
    var sflag = false  // -s option for multiple columns
    var nohead = false // do not write head and trailer
    var pgwd : Int = 0 // page width with multiple col output
    var addone = false // page length is odd with double space
    var timefrmt : String? // time conversion string

    var args : [String] = CommandLine.arguments

    var twice : Bool = false
    var fname : String = ""
    var errcnt : Int = 0
    var hdrDate : String = ""
  }

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "#adFfmrte?h:i?L:l:n?o:ps?w:"
    let go = Egetopt(supportedFlags)

    while let (k, v) = try go.egetopt() {
      switch k {
        case "+":
          if let k = Int(v), k >= 1 {
            options.pgnm = k
          } else {
            throw CmdErr(1, "pr: +page number must be 1 or more")
          }
        case "-":
          if let cc = Int(v), cc >= 1 {
            options.clcnt = cc
          } else {
            throw CmdErr(1, "pr: -columns must be 1 or more")
          }
          if options.clcnt > 1 {
            options.cflag = true
          }
        case "a":
          options.across = true
        case "d":
          options.dspace = true
        case "e":
          options.eflag = true
          var vv = v
          if !v.isEmpty {
            if !v.first!.isNumber {
              options.inchar = vv.removeFirst()
            } else {
              options.inchar = INCHAR
            }
          }

          if !vv.isEmpty && vv.first!.isNumber {
            if let k = Int(vv), k >= 0 {
              options.ingap = k
            } else {
              throw CmdErr(1, "pr: -e gap must be 0 or more")
            }

            if options.ingap == 0 {
              options.ingap = INGAP
            }
          } else if !vv.isEmpty {
            throw CmdErr(1, "pr: invalid value for -e \(vv)")
          } else {
            options.ingap = INGAP
          }
        case "f":
          options.pausefst = true
          fallthrough
        case "F":
          options.formfeed = true
        case "h":
          options.header = v
        case "i":
          options.iflag = true
          var vv = v
          if !v.isEmpty && !v.first!.isNumber {
            options.ochar = vv.removeFirst()
          } else {
            options.ochar = OCHAR
          }
          if !vv.isEmpty && vv.first!.isNumber {
            if let k = Int(vv) {
              if k >= 0 {
                options.ogap = k
              } else {
                throw CmdErr(1, "pr: -i gap must be 0 or more")
              }
              if options.ogap == 0 {
                options.ogap = OGAP
              }
            } else if !vv.isEmpty {
              throw CmdErr(1, "pr: invalid value for -i \(v)")
            }
          } else {
            options.ogap = OGAP
          }
          break;
        case "L":
          options.Lflag = v
        case "l":
          if let k = Int(v), k >= 1 {
            options.lines = k
          } else {
            throw CmdErr(1, "pr: number of lines must be 1 or more")
          }
        case "m":
          options.merge = true
        case "n":
          var vv = v
          if !v.isEmpty && !v.first!.isNumber {
            options.nmchar = vv.removeFirst()
          } else {
            options.nmchar = NMCHAR
          }
          if !vv.isEmpty, let k = Int(vv) {
            if k >= 1 {
              options.nmwd = k
            } else {
              throw CmdErr(1, "pr: -n width must be 1 or more")
            }
          } else if !v.isEmpty {
            throw CmdErr(1, "pr: invalid value for -n \(v)")
          } else {
            options.nmwd = NMWD
          }
        case "o":
          if let offst = Int(v), offst >= 1 {
            options.offst = offst
          } else {
            throw CmdErr(1, "pr: -o offset must be 1 or more")
          }
        case "p":
          options.pauseall = true
        case "r":
          options.nodiag = true
        case "s":
          options.sflag = true
          if v.isEmpty {
            options.schar = SCHAR
          } else {
            options.schar = v.first!
            if v.count > 1 {
              throw CmdErr(1, "pr: invalid value for -s \(v)")
            }
          }
          break;
        case "t":
          options.nohead = true
        case "w":
          options.wflag = true
          if let pgwd = Int(v), pgwd >= 1 {
            options.pgwd = pgwd
          } else {
            throw CmdErr(1, "pr: -w width must be 1 or more")
          }
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining

    // default and sanity checks
    if options.clcnt == 0 {
      if options.merge {
        options.clcnt = options.args.count
        if options.clcnt < 1 {
          options.clcnt = 1
          options.merge = false
        }
      } else {
        options.clcnt = 1
      }
    }
    if options.across {
      if options.clcnt == 1 {
        throw CmdErr(1, "pr: -a flag requires multiple columns")
      }
      if options.merge {
        throw CmdErr(1, "pr: -m cannot be used with -a")
      }
    }
    if !options.wflag {
      if options.sflag {
        options.pgwd = SPGWD
      } else {
        options.pgwd = PGWD
      }
    }
    if options.cflag || options.merge {
      if !options.eflag {
        options.inchar = INCHAR
        options.ingap = INGAP
      }
      if !options.iflag {
        options.ochar = OCHAR
        options.ogap = OGAP
      }
    }
    if options.cflag {
      if options.merge {
        throw CmdErr(1, "pr: -m cannot be used with multiple columns")
      }
      if options.nmwd != 0 {
        options.colwd = (options.pgwd + 1 - (options.clcnt * (options.nmwd + 2)))/options.clcnt
        options.pgwd = ((options.colwd + options.nmwd + 2) * options.clcnt) - 1
      } else {
        options.colwd = (options.pgwd + 1 - options.clcnt)/options.clcnt
        options.pgwd = ((options.colwd + 1) * options.clcnt) - 1
      }
      if options.colwd < 1 {
        throw CmdErr(1, "pr: page width is too small for \(options.clcnt) columns")
      }
    }
    if options.lines == 0 {
      options.lines = LINES
    }

    // make sure long enough for headers. if not disable
    if options.lines <= HEADLEN + TAILLEN {
      options.nohead = true
    }
    else if !options.nohead {
      options.lines -= HEADLEN + TAILLEN
    }

    // adjust for double space on odd length pages
    if options.dspace {
      if options.lines == 1 {
        options.dspace = false
      } else {
        if (options.lines & 1) != 0 {
          options.addone = true
        }
        options.lines /= 2;
      }
    }

    // FIXME: setlocale is gone -- so what does this do?
    //    Darwin.setlocale(Darwin.LC_TIME, (options.Lflag != nil) ? options.Lflag : "");

    options.d_first = nl_langinfo(D_MD_ORDER).pointee == "d".first!.asciiValue!
    options.timefrmt = options.d_first ? TIMEFMTD : TIMEFMTM

    if options.args.isEmpty {
      // no file listed; default, use standard input
      options.args.append("-")
    }
    return options
  }

  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    if options.merge {
      try await mulfile(options)
    } else if options.clcnt == 1 {
      try await onecol(options)
    } else if options.across {
      try await horzcol(options)
    } else {
      try await vertcol(options)
    }
  }

}
