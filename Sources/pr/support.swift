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

import errno_h
import locale_h
import time_h
import stdlib_h

// for fstat
import Darwin

let FORMFEED = "\u{0c}"

extension pr {
  /*
   * nxtfile:  returns a FileDescriptor to next file in arg list and sets the
   *    time field for this file (or current date).
   *
   *  buf  array to store proper date for the header.
   *  dt  if set skips the date processing (used with -m)
   */
  func nxtfile(_ options : inout CommandOptions, dt : Bool) /* const char **fname, char *buf, int dt */ -> FileDescriptor?
  {
    var inf : FileDescriptor?
    var timeptr : UnsafeMutablePointer<tm>?
    var statbuf = Darwin.stat()

//    options.twice = false


    while !options.args.isEmpty {
      let thisarg = options.args.removeFirst()
      if thisarg == "-" {
        defer { options.twice = true }
        // process a "-" for filename
        inf = FileDescriptor.standardInput
        if let h = options.header {
          options.fname = h
        } else {
          options.fname = ""
        }
        if options.nohead || (dt && options.twice ) {
          return inf
        }

        var tv_sec = time_h.time(nil)
        if tv_sec == -1 {
          options.errcnt += 1
          var er = FileDescriptor.standardError
          let se = String(cString: stdlib_h.strerror(errno))
          print("pr: cannot get time of day, \(se)", to: &er)
          return nil
        }
        timeptr = localtime(&tv_sec);
      } else {
        // normal file processing
        let filename = thisarg
        do {
          inf = try FileDescriptor(forReading: filename)
        } catch(let e) {
          options.errcnt += 1
          if options.nodiag {
            continue
          }
          var er = FileDescriptor.standardError
          print("pr: cannot open \(filename), \(e)", to: &er)
          continue
        }
        if let h = options.header {
          options.fname = h
        } else if (dt) {
          options.fname = ""
        } else {
          options.fname = filename
        }

        if options.nohead || (dt && options.twice ) {
          return inf
        }

        if let inf {
          if (dt) {
            var tv_sec = time(nil)
            if tv_sec == -1 {
              options.errcnt += 1
              var er = FileDescriptor.standardError
              let se = String(cString: stdlib_h.strerror(errno))
              print("pr: cannot get time of day, \(se)", to: &er)
              try? inf.close()
              return nil
            }
            timeptr = localtime(&tv_sec);
          } else {
            if (Darwin.fstat(inf.rawValue, &statbuf) < 0) {
              options.errcnt += 1
              try? inf.close()
              var err = FileDescriptor.standardError
              let se = String(cString: stdlib_h.strerror(errno))
              print("pr: cannot stat \(filename), \(se)", to: &err)
              return nil
            }
            var stm = statbuf.st_mtime
            timeptr = localtime(&stm)
          }
        }
      }
      break;
    }

    guard let inf else { return nil }
    /*
     * set up time field used in header
     */
    if let timeptr {
      var buf = Array(repeating: CChar(0), count: HDBUF)
      let n = time_h.strftime(&buf, HDBUF, options.timefrmt, timeptr)
      if n <= 0 {
        options.errcnt += 1
        if inf != FileDescriptor.standardInput {
          try? inf.close()
        }
        var se = FileDescriptor.standardError
        print("pr: time conversion failed\n", to: &se)
        return nil
      } else {
        if let k = String(validating: buf[0..<n], as: UTF8.self) {
          options.hdrDate = k
        }
      }
    }
    return inf
  }

  /*
   * inskip():  skip over pgcnt pages with lncnt lines per page
   *    file is closed at EOF (if not stdin).
   *
   *  inf  FILE * to read from
   *  pgcnt  number of pages to skip
   *  lncnt  number of lines per page
   */
  func inskip(_ inf : inout AsyncLineReader.AsyncIterator, _ pgcnt : Int, _ lncnt : Int) async throws(CmdErr) -> Bool  {

    for _ in 0..<lncnt * pgcnt {
      do {
        let l = try await inf.next()
        if l == nil { return true }
      } catch {
        throw CmdErr(1, "inskip read error: \(error)")
      }
    }
    return false
  }



  /*
   * Check if we should pause and write an alert character and wait for a
   * carriage return on /dev/tty.
   */
  func ttypause(_ pagecnt : Int, options: CommandOptions) async {
    if (options.pauseall || (options.pausefst && pagecnt == 1)) && stdlib_h.isatty(STDOUT_FILENO) != 0 {
      if let ttyfp = try? FileDescriptor(forReading: "/dev/tty") {
        stdlib_h.putc(7, stderr)
        var k = ttyfp.bytes.lines.makeAsyncIterator()
        let _ = try? await k.next()
        try? ttyfp.close()
      }
    }
  }


  /*
   * addnum():  adds the line number to the column
   *    Truncates from the front or pads with spaces as required.
   *    Numbers are right justified.
   *
   *  buf  buffer to store the number
   *  wdth  width of buffer to fill
   *  line  line number
   *
   *    NOTE: numbers occupy part of the column. The posix
   *    spec does not specify if -i processing should or should not
   *    occur on number padding. The spec does say it occupies
   *    part of the column. The usage of addnum  currently treats
   *    numbers as part of the column so spaces may be replaced.
   */
  func addnum(_ wdth : Int, _ line : Int) -> String {
    let pt = String(line)
    var ptx : String
    if wdth < pt.count { ptx = String(pt.dropFirst(pt.count-wdth)) }
    else { ptx = String(repeating: " ", count: wdth-pt.count)+pt }
    return ptx
  }




  /*
   * prhead():  prints the top of page header
   *
   *  buf  buffer with time field (and offset)
   *  cnt  number of chars in buf
   *  fname  fname field for header
   *  pagcnt  page number
   */
  func prhead(_ buf : String, _ fname : String, _ pagcnt : Int, options: CommandOptions) throws(CmdErr) {

    print("\n")

    /*
     * posix is not clear if the header is subject to line length
     * restrictions. The specification for header line format
     * in the spec clearly does not limit length. No pr currently
     * restricts header length. However if we need to truncate in
     * a reasonable way, adjust the length of the printf by
     * changing HDFMT to allow a length max as an argument to printf.
     * buf (which contains the offset spaces and time field could
     * also be trimmed
     *
     * note only the offset (if any) is processed for tab expansion
     */
//    try otln( String(buf.prefix(options.offst)), &ips, &ops, -1, options: options)
//    let bb = buf.dropFirst(options.offst)
    let HDFMT = "\(buf) \(fname) Page \(pagcnt)\n\n"
    print(HDFMT)
  }




  /*
   * prtail():  pad page with empty lines (if required) and print page trailer
   *    if requested
   *
   *  cnt  number of lines of padding needed
   *  incomp  was a '\n' missing from last line output
   */
  func prtail(_ cntx : Int, _ incomp : Bool, options : CommandOptions) throws(CmdErr) {
    var cnt = cntx
    if options.nohead {
      // only pad with no headers when incomplete last line
      if incomp {
        if options.dspace {
          print("")
        }
      }
      print("")

      /*
       * but honor the formfeed request
       */
      if options.formfeed {
          print(FORMFEED, terminator: "")
      }
      return
    }
    /*
     * if double space output two \n
     */
    if options.dspace {
      cnt *= 2
    }

    // if an odd number of lines per page, add an extra \n
    if options.addone {
      cnt += 1
    }

    // pad page
    if (options.formfeed) {
      if incomp {
        print("")
      }
      print(FORMFEED, terminator: "")
    } else {
      cnt += TAILLEN
      print(String(repeating: "\n", count: cnt), terminator: "")
    }
  }



  /*
   * otln():  output a line of data. (Supports unlimited length lines)
   *    output is optionally contracted to tabs
   *
   *  buf:  output buffer with data
   *  cnt:  number of chars of valid data in buf
   *  svips:  buffer input column position (for large lines)
   *  svops:  buffer output column position (for large lines)
   *  mor:  output line not complete in this buf; more data to come.
   *    1 is more, 0 is complete, -1 is no \n's
   */
  func otln(_ buf : String, options: CommandOptions) throws(CmdErr) {
    /*    int ops;    /* last col output */
     int ips;    /* last col in buf examined */
     int gap = ogap;
     int tbps;
     char *endbuf;
     */

    var bufx = buf

    if (options.ogap != 0) {
      // FIXME: do the space compression -> tabs
      bufx = spaceCompress(buf, options: options)
/*
      // contracting on output

      var ops = 0
      var ips = 0
      let gap = options.ogap

      for c in buf {
        // count number of spaces and ochar in buffer
        if c == " " {
          ips += 1
          continue
        }

        // simulate ochar processing
        if c == options.ochar {
          ips += gap - (ips % gap);
          continue
        }

        // got a non space char; contract out spaces
        while (ips - ops > 1) {
          // use as many ochar as will fit
          let tbps = ops + gap - (ops % gap)
          if tbps > ips {
            break
          }
          if (gap - 1 == (ops % gap)) { // use space to get to immediately following tab stop
                                        // This was first_char -- could be " " under if not Unix2003
            print("\t", terminator: "")
          } else {
            print(options.ochar, terminator: "")
          }
          ops = tbps;
        }

        while (ops < ips) {
          // finish off with spaces
          print(" ", terminator: "")
          ops += 1
        }

        // output non space char
        print(c, terminator: "")
        ips += 1
        ops += 1
      }

      /* FIXME: where might I need this?
      if (mor < 0) {
        while (ips - ops > 1) {
          /*
           * use as many ochar as will fit
           */
          let tbps = ops + gap - (ops % gap)
          if tbps > ips {
            break
          }
          print(options.ochar, terminator: "")
          ops = tbps;
        }
        while (ops < ips) {
          // finish off with spaces
          print(" ", terminator: "")
          ops += 1
        }
        return
      }
      */


      */
    }

      // output is not contracted
      print(bufx)

 /*     if (mor != 0) {
        return
      }
  */

    /*
     * process line end and double space as required
     */
    if options.dspace {
      print("")
    }
  }

  func makelin(_ lncnt : inout Int, _ linbuf : [String], options: CommandOptions) -> String {
    var lin = ""
    if options.nmwd != 0 {
      lncnt += 1
     // add number to column
      let k = addnum(options.nmwd, lncnt) + String(options.nmchar)
      lin = k
     }

    for var (i,v) in linbuf.enumerated() {



      if v.count >= options.colwd {
        v = String(v.prefix(options.colwd)) + " "
      } else {

        // pad to end of column
        if options.sflag {
          if i != options.clcnt {
            v.append(options.schar)
          }
        } else {
          v.append( String(repeating: " ", count: options.colwd + 1 - v.count))
        }
      }
      lin.append(v)
    }
    return lin

  }


  func printPage(_ pagecnt : inout Int,_ pg : [String], options: CommandOptions) throws(CmdErr) {
    if !pg.isEmpty {
      // calculate data in line
      if !options.nohead {
        try prhead(options.hdrDate, options.fname, pagecnt, options: options)
      }

      // output line
      for buf in pg {
        try otln(buf, options: options)
      }
      // pad to end of page

      if !options.nohead {
        try prtail(options.lines-pg.count, false, options: options)
      }
    }
    pagecnt += 1

  }

  // contracting on output
  func spaceCompress(_ s : String, options: CommandOptions) -> String {
    var inp = Substring(s)
    var outp = Substring("")
    var pos = 0

    // don't need trailing blanks or tabs
    while inp.last == " " || inp.last == options.ochar {
      inp.removeLast()
    }

    while !inp.isEmpty {
      let k = inp.prefix(while: { $0 != " " && $0 != options.ochar } )
      inp.removeFirst(k.count)
      outp.append(contentsOf: k)
      pos += k.count
      let kk = inp.prefix(while: { $0 == " " })
      var nnn = kk.count
      inp.removeFirst(nnn)
      let nn = options.ogap - (pos % options.ogap)

      if nnn > 1 && nnn >= nn {
        outp.append(options.ochar)
        nnn -= nn
        pos += nn
      }
      while nnn >= options.ogap {
        outp.append(options.ochar)
        nnn -= options.ogap
        pos += options.ogap
      }

      outp.append(contentsOf: String(repeating: " ", count: nnn))
      pos += nnn

      if inp.first == options.ochar {
        let nn = options.ogap - (pos % options.ogap)
        outp.append(options.ochar)
        pos += nn
        inp.removeFirst()
      }
    }
    return String(outp)
  }

  func pfail() throws(CmdErr) {
    let se = String(cString: strerror(errno))
    throw CmdErr(1, "pr: write failure \(se)")
  }

}
