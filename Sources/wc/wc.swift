
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  Copyright (c) 1980, 1987, 1991, 1993
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
import libxo
import Synchronization

// import stdlib_h

@main final class wc : ShellCommand {

  var usage : String = "usage: wc [-Lclmw] [file ...]"
  
  struct CommandOptions {
    var doline = false
    var doword = false
    var dochar = false
    var domulti = false
    var dolongline = false
    var stderr_handle : OpaquePointer? = nil
    var stdout_handle : OpaquePointer? = nil
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "clmwL"
    
    let argv = CommandLine.unsafeArgv
    var argc = CommandLine.argc
    argc = xo_parse_args(argc, argv)
    if argc < 0 {
      throw CmdErr(1)
    }
    
    let jj = (1..<argc).map { String(cString: argv[Int($0)]!) }
    let go = BSDGetopt(supportedFlags, args: ArraySlice(jj) )
    
    while let (k, _) = try go.getopt() {
      switch k {
        case "l": options.doline = true
        case "w": options.doword = true
        case "c": options.dochar = true
          options.domulti = false
        case "L": options.dolongline = true
        case "m": options.domulti = true
          options.dochar = false
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    
    if (!(options.doline || options.doword || options.dochar || options.domulti || options.dolongline)) {
      options.doline = true
      options.doword = true
      options.dochar = true
      options.stderr_handle = xo_create_to_file(stderr, xo_style_t(XO_STYLE_TEXT), 0)
      options.stdout_handle = xo_create_to_file(stdout, xo_style_t(XO_STYLE_TEXT), 0)
    }
    
    return options
  }
  
  
  func runCommand() throws(CmdErr) {
    xo_open_container("wc")
    xo_open_list("file")
    
    var errors = 0
    var total = 0
    if options.args.count == 0 {
      xo_open_instance("file")
      if cnt(xfile: nil) {
        errors += 1
      }
      xo_close_instance("file")
    } else {
      for a in options.args {
        xo_open_instance("file")
        if cnt(xfile: a) {
          errors += 1
        }
        xo_close_instance("file")
        total += 1
      }
    }
    
    xo_close_list("file")
    
    if total > 1 {
      xo_open_container("total")
      show_cnt(file: "total", linect: tlinect, wordct: twordct, charct: tcharct, llct: tlongline)
      xo_close_container("total")
    }
    
    xo_close_container("wc")
    if xo_finish() < 0 {
      throw CmdErr( 1, "stdout")
    }
    exit(errors == 0 ? 0 : 1)
  }
  
  func show_cnt(file : String, linect : UInt, wordct : UInt, charct : UInt, llct : UInt) {
    var xop : OpaquePointer?
    
    if !(siginfo.withLock {$0}) {
      xop = nil
    } else {
      xop = options.stderr_handle!
      siginfo.withLock { $0 = false }
    }

    if options.doline {
      xo_emit_hv(xop, " {:lines/%7ju/%ju}", linect);
    }
    if options.doword {
      xo_emit_hv(xop, " {:words/%7ju/%ju}", wordct);
    }
    if (options.dochar || options.domulti) {
      xo_emit_hv(xop, " {:characters/%7ju/%ju}", charct);
    }
    if (options.dolongline) {
      xo_emit_hv(xop, " {:long-lines/%7ju/%ju}", llct);
    }
    if (file != "stdin") {
      xo_emit_hv(xop, " {:filename/\(file)}\n");
    }
    else {
      xo_emit_hv(xop, "\n");
    }

  }
  
  var tlinect : UInt = 0, twordct : UInt = 0, tcharct : UInt = 0,
      tlongline : UInt = 0
  
  func cnt(xfile : String?) -> Bool {
//    var buf = Data(capacity: Int(MAXBSIZE))
    var sb = stat()
    //     var mbs = mbstate_t()
    // const char *p;
    var linect : UInt = 0, wordct : UInt = 0, charct : UInt = 0,
        llct : UInt = 0, tmpll : UInt = 0
    var len : UInt = 0
//    var clen : UInt
//    var fd : Int32
    var gotsp = false
    var warned = false
    var file : String
    var fh : FileDescriptor
    
    if xfile != nil {
      file = xfile!
//      let u = URL(filePath: file)
      do {
        let fhh = try FileDescriptor(forReading: file)
        fh = fhh
        //      fd = open(file, O_RDONLY)
        //      if (fd < 0) {
      } catch(let e) {
        xo_warn( "\(file): open \(e))")
        return true
      }
    } else {
      fh = FileDescriptor.standardInput
//      fd = STDIN_FILENO
      file = "stdin"
    }
    
    let mbcm = ___mb_cur_max()
    if !(options.doword || (options.domulti && mbcm != 1)) {
      /*
       * If all we need is the number of characters and it's a regular file,
       * just stat it.
       */
      if (!options.doline && !options.dolongline) {
        if (fstat(fh.rawValue, &sb) != 0) {
          xo_warn("\(file): fstat")
          try? fh.close()
          return true
        }
        if (S_ISREG(sb.st_mode)) {
          reset_siginfo();
          charct = UInt(sb.st_size)
          show_cnt(file: file, linect: linect, wordct: wordct, charct: charct, llct: llct);
          tcharct += charct;
          try? fh.close()
          return false
        }
      }
      /*
       * For files we can't stat, or if we need line counting, slurp the
       * file.  Line counting is split out because it's a lot faster to get
       * lines than to get words, since the word count requires locale
       * handling.
       */
      while true {
        var buf : [UInt8]
        do {
          buf = try fh.readUpToCount(Int(MAXBSIZE))
          if buf.count == 0 { break }
          len = UInt(buf.count)
        } catch( let e) {
          xo_warn("\(file): read");
          try? fh.close()
          return true
        }
        if (siginfo.withLock { $0 } ) {
          show_cnt(file: file, linect: linect, wordct: wordct, charct: charct, llct: llct);
        }
        charct += len;
        if (options.doline || options.dolongline) {
          for d in buf {
            if (d == Character("\n").asciiValue) {
              if (tmpll > llct) {
                llct = tmpll
              }
              tmpll = 0;
              linect += 1
            } else {
              tmpll += 1
            }
          }
        }
      }
      reset_siginfo();
      if (options.dochar) {
        tcharct += charct;
      }
    } else {
      /* Do it the hard way... */
      gotsp = true;
      warned = false;
//      var mbs = mbstate_t()
      var buf = [UInt8]()
      while true {
        do {
          let bufx = try fh.readUpToCount(Int(MAXBSIZE))
          if bufx.count == 0 { break }
          buf.append(contentsOf: bufx)
        } catch(let e) {
          xo_warn("\(file): read")
          try? fh.close()
          return true
        }
        
        len = UInt(buf.count)
        let rem = buf.withUnsafeBytes { (pp : UnsafeRawBufferPointer) in
          var wch : wchar_t = Int32(UnicodeScalar("?").value)
          var p = pp.baseAddress!.assumingMemoryBound(to: UInt8.self)
          while (len > 0) {
            if (siginfo.withLock { $0 }) {
              show_cnt(file: file, linect: linect, wordct: wordct, charct: charct, llct: llct);
            }
            var clen : Int
            if (!options.domulti || mbcm == 1) {
              clen = 1;
              wch = Int32(p.pointee)
            } else {
              clen = mbrtowc(&wch, p, Int(len), nil)
              if (clen == 0) {
              clen = 1;
            } else
              if (clen == -1) {
              if (!warned) {
                errno = EILSEQ;
                xo_warn(file)
                warned = true;
              }
              clen = 1;
              wch = Int32(p.pointee)
            } else if (clen == -2) {
              return len
              break;
            }
          }
            charct += 1
            if (wch != UnicodeScalar("\n").value) {
              tmpll += 1
            }
            len -= UInt(clen)
            p += clen
            if (wch == UnicodeScalar("\n").value) {
              if (tmpll > llct) {
                llct = tmpll
              }
              tmpll = 0
              linect += 1
            }
            if (iswspace(wch) != 0) {
              gotsp = true;
            } else if (gotsp) {
              gotsp = false;
              wordct += 1
            }
          }
          return 0
          
        }
        buf = buf.suffix(Int(rem))
        
      }
      reset_siginfo();
      if (options.domulti && mbcm > 1) {
        if (mbrtowc(nil, nil, 0, nil) == -1 && !warned) {
          xo_warn(file);
        }
      }

      if (options.doword) {
        twordct += wordct;
      }
      if (options.dochar || options.domulti) {
        tcharct += charct
      }

    }
    if (options.doline) {
      tlinect += linect
    }
    if (options.dolongline && llct > tlongline) {
      tlongline = llct
    }

    show_cnt(file: file, linect: linect, wordct: wordct, charct: charct, llct: llct)
    try? fh.close()
    return false

  }

  
  
  
}

// var siginfo : sig_atomic_t = 0
let siginfo : Mutex<Bool> = Mutex(false)

func siginfo_handler(_ sig : Int) {
  siginfo.withLock { $0 = true }
}

func reset_siginfo() {
  signal(SIGINFO, SIG_DFL);
  siginfo.withLock { $0 = false }
}


func xo_warn(_ fmt : String, _ args : CVarArg...) {
  let code = errno
  withVaList( args ) {
    //    va_start(vap, fmt);
    xo_warn_hcv(nil, code, 0, fmt, $0);
    //    va_end(vap);
  }
}

@discardableResult
func xo_emit_hv(_ xop : OpaquePointer?, _ fmt : String, _ args : CVarArg...) -> Int {
  return withVaList( args ) { args in
    xo_emit_hv(xop, fmt, args)
  }
}

