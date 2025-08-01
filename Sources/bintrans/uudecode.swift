
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1983, 1993
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

import stdlib_h
import stdio_h
import Darwin

/*
import stdlib_h
import stdio_h
import errno_h
import time_h
import locale_h
import limits_h
import stdarg_h
import stddef_h
import fenv_h
import math_h
import ctype_h
import float_h
import wchar_h
import assert_h
import iso646_h
import setjmp_h
import stdint_h
import string_h
import tgmath_h
import unwind_h
import wctype_h
import complex_h
import stdbool_h
import inttypes_h
import stdalign_h
import stdatomic_h
import stdnoreturn_h
import signal_h
*/


struct Decoder {
  var inFile : String = "stdin"
  var outFile : String = "stdout"
  var inHandle = FileDescriptor.standardInput
  var outHandle = FileDescriptor.standardOutput
  var options : bintrans.CommandOptions

}

extension bintrans {
  
  func main_base64_decode(_ inp : String?, _ outp : String?, _ options : inout CommandOptions) async throws(CmdErr) {
    options.base64 = true
    options.rflag = true
    
    var inFile : String
    var infp : FileDescriptor
    
    if let inp, inp != "-" {
      inFile = inp
      do {
//        let u = URL(filePath: inp)
        let xinfp = try FileDescriptor(forReading: inp)
        infp = xinfp
      } catch(let e) {
        throw CmdErr(1, "\(inp): Permission denied (\(e))")
      }
    } else {
      inFile = "stdin";
      infp = FileDescriptor.standardInput
    }
    
    var outfp : FileDescriptor = FileDescriptor.standardOutput
    var outFile = "stdout"
    if let outp {
      if outp == "-" {
        outfp = FileDescriptor.standardOutput
      }
      else {
//        let u = URL(filePath: outp)
        do {
          let xoutfp = try FileDescriptor(forWriting: outp)
          outFile = outp
          outfp = xoutfp
        } catch(let e) {
          throw CmdErr(1, "\(outp): Permission denied (\(e))")
        }
      }
    }
    
    var d = Decoder.init(inFile: inFile, outFile: outFile, inHandle: infp, outHandle: outfp, options: options)
    
    let res = try await decode(&d)
    stdlib_h.exit(Int32(res))
  }
  
  func parseOptions_decode(_ options : inout CommandOptions, _ bintflag : Bool) throws(CmdErr) {
    //      int rval, ch;
    
    if options.progname == "b64decode" {
      options.base64 = true;
    }
    
    let go = BSDGetopt("cimo:prsI:", args: CommandLine.arguments.dropFirst(bintflag ? 2 : 1))
    
    while let (k,v) = try go.getopt()  {
      switch k {
        case "I":
          options.inFile = v
        case "c":
          if (options.oflag || options.rflag) {
            throw CmdErr(1, decode_usage)
          }
          options.cflag = true // multiple uudecode'd files
        case "i":
          options.iflag = true // ask before override files
        case "m":
          options.base64 = true
        case "o":
          if (options.cflag || options.pflag || options.rflag || options.sflag) {
            throw CmdErr(1, decode_usage)
          }
          options.oflag = true // output to the specified file
          options.sflag = true // do not strip pathnames for output
          options.outFile = v // set the output filename
        case "p":
          if (options.oflag) {
            throw CmdErr(1, decode_usage)
          }
          options.pflag = true // print output to stdout
        case "r":
          if (options.cflag || options.oflag) {
            throw CmdErr(1, decode_usage)
          }
          options.rflag = true // decode raw data
          break;
        case "s":
          if (options.oflag) {
            throw CmdErr(1, decode_usage)
          }
          options.sflag = true // do not strip pathnames for output
        default:
          throw CmdErr(1, decode_usage)
      }
    }
    
    options.args = go.remaining
    
    // unix2003compat = true // COMPAT_MODE("bin/uudecode", "Unix2003");
  }
  
  func main_decode(_ options : CommandOptions) async throws(CmdErr) {
    var d = Decoder(options: options)

    if let inf = options.inFile {
      d.inFile = inf
      do {
        d.inHandle = try FileDescriptor(forReading: inf)
      } catch(let e) {
        throw CmdErr(1, "failed to open \(inf): \(e)")
      }
    }
    
    var rval : Int32 = 0
    if options.args.isEmpty {
      rval = try await decode(&d)
    } else {
      for inFile in options.args {
        do {
          if let di = d.options.inFile { d.inFile = di }
          d.inHandle = try FileDescriptor(forReading: d.inFile)
          d.inFile = inFile
          rval |= try await decode(&d)
          try d.inHandle.close()
        } catch(let e) {
          warn(inFile)
          rval = 1
          continue
        }
      }
    }
    
    stdlib_h.exit( Int32(rval) )
  }
  
  func decode(_ d : inout Decoder ) async throws(CmdErr) -> Int32 {
    //    int r, v;
    
    /*
     Decode raw (or broken) input, which is missing the initial and possibly the final framing lines. The input is assumed to be in the traditional uuencode encoding, but if the -m flag is used, or if the utility is invoked as b64decode, then the input is assumed to be in Base64 format.
     */
    if (d.options.rflag) {
      /* relaxed alternative to decode2() */
      
      /*      if (d.outHandle == nil) {
       d.outFile = "/dev/stdout";
       d.outHandle = FileDescriptor.standardOutput
       }
       */
      var leftover = ""
      
      do {
        for try await buf in d.inHandle.bytes.lines {
          
          if (d.options.base64) {
            let (o, m) = base64_decode(buf, &leftover)
            if let o {
              try d.outHandle.write(o)
              if !m {
                break
              }
            } else {
              break
            }
          }
          else {
            if let o = uu_decode(buf) {
              try d.outHandle.write(o)
            } else {
              OUT_OF_RANGE(d.inFile, d.outFile)
              break
            }
          }
        }
      } catch(let e) {
        throw CmdErr(1, "read error \(d.inFile): \(e)")
      }
      return 0
      
    } else {
      
      var r : Int32 = 0
      var first = true
      
      while d.options.cflag || first {
        first = false
        var v = try await decode2(&d)
        if first && v == stdlib_h.EOF {
          warn("\(d.inFile): missing or bad \"begin\" line")
          return 1
        }
        if v == stdlib_h.EOF {
          break
        }
        r |= v
      }
      return r
    }
  }
  
  func decode2(_ d : inout Decoder ) async throws(CmdErr) -> Int32 {
    //      int flags, fd, mode;
    //      size_t n, m;
    //      char *p, *q;
    //      void *handle;
    //      struct passwd *pw;
    //      struct stat st;
    //      char buf[MAXPATHLEN + 1];
    
    d.options.base64 = false;
    /* search for header line */
    
    //    while true {
    // var isEOF = true
    
//    var fn = ""
//    var modestr = ""
    
    enum readState {
      case header
      case body
      case footer
    }
    
    var state = readState.header
    var leftover = ""
    do {
      for try await buf in d.inHandle.bytes.lines {
        //      if (fgets(buf, sizeof(buf), infp) == NULL) {
        //        return (EOF);
        //      }
        switch state {
          case .header:
            let m = try doDecodeHeader(buf, &d)
            if m == 2 {
              state = .body
            }
          case .body:
            let k = try doDecodeBody(buf, d, &leftover)
            if !k {
              state = .footer
            }
          case .footer:
            doDecodeFooter(buf, d)
            state = .header
        }
      }
    } catch(let e){
      throw CmdErr(1, "read error: \(d.inFile): \(e)")
    }
    return 0
  }
  
  func doDecodeHeader(_ buf : String, _ d : inout Decoder) throws(CmdErr) -> Int32 {
    var p = Substring(buf)
    if p.hasPrefix("begin-base64 ") {
      d.options.base64 = true;
      p = p.dropFirst(13)
    } else if p.hasPrefix("begin ") {
      p = p.dropFirst(6)
    } else {
      return 0
    }
    /* p points to mode */
    let q = p.split(separator: " ", maxSplits: 1)
    if q.count < 2 {
      return 0
    }
    
    /* q[0] points to mode, q[1] points to filename */
    var fn = String(q[1].drop { $0.isNewline }.reversed().drop { $0.isNewline }.reversed() )
    var modestr = String(q[0])
    
    /* found valid header? */
    if fn.isEmpty || modestr.isEmpty {
//      isEOF = false
      return 0
    }
    
   //  if isEOF { return EOF }
    
    guard let handle = stdlib_h.setmode(modestr) else {
      warnx("\(modestr): unable to parse file mode")
      return 1
    }
    let mode = stdlib_h.getmode(handle, 0)

    // POSIX says "/dev/stdout" is a 'magic cookie' not a special file.
    if fn == "/dev/stdout" {
      d.outHandle = FileDescriptor.standardOutput
      d.outFile = fn
    }
    
    
    if (d.options.sflag) {
      /* don't strip, so try ~user/file expansion */
      let q = fn
      if q.hasPrefix("~") {
        let j = q.split(separator: "/", maxSplits: 1)
        if j.count > 1 {
          if let dd = getPasswd(for: String(j[0].dropFirst())) {
            fn = dd.home + "/" + String(j[1])
          }
        }
      }
    } else {
      /* strip down to leaf name */
      if let ll = fn.lastIndex(of: "/") {
        fn = String(fn[ll...].dropFirst())
      }
    }
    if (!d.options.oflag) {
      d.outFile = fn
    }
    
    // FIXME: the test for outHandle?
    if d.options.oflag {
      do {
        d.outFile = d.options.outFile!
        d.outHandle = try FileDescriptor(forWriting: d.outFile)
      } catch(let e) {
        throw CmdErr(1, "\(d.outFile): \(e)")
      }
      return 2
    } else
    
    /* POSIX says "/dev/stdout" is a 'magic cookie' not a special file. */
    if (d.options.pflag || d.outFile == "/dev/stdout") {
      d.outFile = "/dev/stdout"
      d.outHandle = FileDescriptor.standardOutput
      return 2
    }
    else {
      var flags = Darwin.O_WRONLY | Darwin.O_CREAT | Darwin.O_EXCL
      var st = Darwin.stat()
      if (Darwin.lstat(d.outFile, &st) == 0) {
        if d.options.iflag && !S_ISFIFO(st.st_mode) {
          warnc(errno_h.EEXIST, "\(d.inFile): \(d.outFile)")
          return 0
        }
        switch st.st_mode & Darwin.S_IFMT {
          case Darwin.S_IFREG:
            flags |= Darwin.O_NOFOLLOW | Darwin.O_TRUNC
            flags &= ~Darwin.O_EXCL

          case Darwin.S_IFLNK:
            /* avoid symlink attacks */
            
            /*
             * Section 2.9.1.4, P1003.3.2/D8 mandates
             * following symlink.
             */
            if (true /* unix2003compat */) {
              flags |= Darwin.O_TRUNC
              flags &= ~Darwin.O_EXCL
              break
            }
            
            if (unlink(d.outFile) == 0 || errno == errno_h.ENOENT) {
              break
            }
            warn("\(d.inFile): unlink \(d.outFile)")
            return 1
          case Darwin.S_IFDIR:
            warnc(errno_h.EISDIR, "\(d.inFile): \(d.outFile)")
            return 1
            
          case S_IFIFO:
            flags &= ~O_EXCL
            break
            
          default:
            if (d.options.oflag) {
              /* trust command-line names */
              flags &= ~O_EXCL
              break;
            }
            warnc(errno_h.EEXIST, "\(d.inFile): \(d.outFile)")
            return 1
        }
      } else if errno != errno_h.ENOENT {
        warn("\(d.inFile): \(d.outFile)")
        return 1
      }
      do {
        d.outHandle = try FileDescriptor.open(d.outFile, .writeOnly, options: [.create], permissions: [.ownerReadWrite])
      } catch(let e) {
        warn("failed to create outfile \(d.outFile): \(e) from \(d.inFile)")
        return 1
      }
      
//      do {
      let ee = Darwin.chmod(d.outFile, mode)
      if 0 != ee {
        //      if (0 != fchmod(d.outHandle.fileDescriptor, mode) && EPERM != errno) {
//      } catch(let e) {
        warn("\(Errno(rawValue: ee))\(d.inFile): \(d.outFile)")
        // FIXME: handle the error
        try? d.outHandle.close()
        return 1
      }
      return 2
    }
  }

  func doDecodeBody(_ buf : String, _ d : Decoder, _ leftover : inout String) throws -> Bool {
    if (d.options.base64) {
      let (outp, more) = base64_decode(buf, &leftover)
      if let outp {
        try d.outHandle.write(outp)
        return more
      } else {
        return false
      }
    }
    else {
      if let outp = uu_decode(buf) {
        if outp.isEmpty { return false }
        else { try d.outHandle.write(outp) }
        return true
      } else {
        OUT_OF_RANGE(d.inFile, d.outFile)
        return false
      }
    }
  }
  
  
  /*
  func get_line(_ buf : inout Data, size_t size) -> Int {
    
    if (fgets(buf, (int)size, infp) != NULL) {
      return (2);
    }
    if (rflag) {
      return (0);
    }
    warnx("%s: %s: short file", inFile, outfile);
    return (1);
  }
  */
  
  func doDecodeFooter(_ buf : String, _ d : Decoder) {
    if d.options.base64 {
      checkend(buf, "====", "error decoding base64 input stream", d)
    } else {
      checkend(buf, "end", "no \"end\" line", d)
    }
  }
  
  // FIXME: add this function back in

  func checkend(_ buf : String, _ end : String, _ msg : String, _ d : Decoder) -> Bool {
    //      size_t n;
    
    if !buf.hasPrefix(end) {
      //      if (strncmp(ptr, end, n) != 0 ||
   //   || !(buf.dropFirst(n).filter { " \t\r\n".contains($0) }).isEmpty {
        //          strspn(ptr + n, " \t\r\n") != strlen(ptr + n)) {
        warnx("\(d.inFile): \(d.outFile): \(msg)")
        return false
      }
    return true
    }
  
  func checkout(_ d : inout Decoder, _ rvalx : Int) -> Int {
    var rval = rvalx
    if d.outHandle != FileDescriptor.standardOutput {
      do {
        try d.outHandle.close()
      } catch(let e) {
        warn("\(d.inFile): \(d.outFile): \(e)")
        rval = 1
      }
      d.outHandle = FileDescriptor.standardOutput
      d.outFile = "/dev/stdout"
      }
      return rval
    }
    
  
  func DEC(_ c : Character) -> UInt8 {
    return UInt8((((c.unicodeScalars.first!.value) - 0x20) & 0x3F)) // single character decode
  }
  
  func IS_DEC(_ c : Character) -> Bool {
    if let cc = c.asciiValue {
      // FIXME: 0x60?
      return  cc > 0x20  && cc <= 0x60
    }
    return false
  }
  
  func OUT_OF_RANGE(_ inFile : String, _ outfile : String) -> Int32 {
      warnx("\(inFile): \(outfile): character out of range: [0x20-0x60]")
      return 1
  }
  
  func uu_decode( _ bufx : String ) -> [UInt8]? {
    //     int i, ch;
    //      char *p;
    //      char buf[MAXPATHLEN+1];
     var buf = bufx
    /* for each input line */
    
        // FIXME: what to do with the checks?
        //        switch (get_line(buf, sizeof(buf))) {
        //          case 0:
        //            return (checkout(d, 0));
        //          case 1:
        //            return (checkout(d, 1));
        //        }
        
        /*
         * `i' is used to avoid writing out all the characters
         * at the end of the file.
         */
    if buf.isEmpty { return nil }
        var i = DEC(buf.first!)
        if i <= 0 {
          return [UInt8]()
        }
        buf.removeFirst()
        var outp = [UInt8]()
    
        while i > 0 {
          var p = Array(buf.prefix(4))
          buf.removeFirst(p.count)
          while p.count < 4 { p.append(" ") }
          if (i >= 3) {
            if !(IS_DEC(p[0])
                 && IS_DEC(p[1])
                 && IS_DEC(p[2])
                 && IS_DEC(p[3])) {
              return nil // OUT_OF_RANGE(d.inFile, d.outFile)
            }
            
            var chx = [UInt8]()
            chx.append( DEC(p[0]) << 2 | DEC(p[1]) >> 4 )
            chx.append( DEC(p[1]) << 4 | DEC(p[2]) >> 2 )
            chx.append( DEC(p[2]) << 6 | DEC(p[3]) )
            outp.append(contentsOf: chx)
          } else {
            if (i >= 1) {
              if !(IS_DEC(p[0]) && IS_DEC(p[1])) {
                return nil // OUT_OF_RANGE(d.inFile, d.outFile)
              }
              let ch = DEC(p[0]) << 2 | DEC(p[1]) >> 4
              outp.append(contentsOf: [ch])
            }
            if (i >= 2) {
              if !(IS_DEC(p[1]) &&
                    IS_DEC(p[2])) {
                return nil // OUT_OF_RANGE(d.inFile, d.outFile)
              }
              
              let ch = DEC(p[1]) << 4 | DEC(p[2]) >> 2
              outp.append(contentsOf: [ch])
            }
          }
          i -= min(3,i)
        }

      
      // FIXME: this seems like last-line-handling
      /*
      switch (get_line(buf, sizeof(buf))) {
        case 0:
          return (checkout(0));
        case 1:
          return (checkout(1));
        default:
          return (checkout(checkend(buf, "end", "no \"end\" line")));
      }
      */

  // FIXME: returning error codes and throwing
    return outp
  }
    
  func base64_decode(_ inb : String, _ leftover : inout String) -> ([UInt8]?, Bool) {
    
    //      ptrdiff_t count4;
    //      int n, count;
    
    //      char inbuf[MAXPATHLEN + 1], *p;
    //      unsigned char outbuf[MAXPATHLEN * 4];
    //      char leftover[MAXPATHLEN + 1];
    
      //        strcpy(inbuf, leftover);
      //        switch (get_line(inbuf + strlen(inbuf),
      //                         sizeof(inbuf) - strlen(inbuf))) {
      let inbuf = leftover + inb
      // FIXME: what to do with the checks?
      /*
       case 0:
       return (checkout(0));
       case 1:
       return (checkout(1));
       }
       */
//      count = 0;
//      count4 = -1;
//      p = inbuf;
//      while (*p != '\0') {
      var count = 0
      var count4 = 0
      var nn = 0

    for ch in inbuf {
        nn += 1
        /*
         * Base64 encoded strings have the following
         * characters in them: A-Z, a-z, 0-9 and +, / and =
         */
        
        /* base64url may include - and _. */
        if ch.isLetter || ch.isNumber
            || "+=/-_".contains(ch) {
          count+=1
        }
        if (count % 4 == 0) {
          count4 = nn
        }
      }
      
      leftover = String(inbuf.dropFirst(count4)) // count4+1 ??
      let ibf = inbuf.prefix(count4)
      
      let (outbuf, done) = apple_b64_pton(String(ibf))
      
    return (outbuf, done)
    
    // FIXME: check the end
//      return (checkout(checkend(inbuf, "====", "error decoding base64 input stream")));
    // FIXME: returning error codes and throwing
    }
    
  var decode_usage : String {"""
usage: uudecode [-cimprs] [file ...]
       uudecode [-i] -o output_file [file]
""" }
    
  }

func S_ISFIFO(_ m : Darwin.mode_t) -> Bool {
  return (((m) & Darwin.S_IFMT) == Darwin.S_IFIFO)     /* fifo or socket */
}
