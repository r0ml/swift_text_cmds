
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 
  Copyright (c) 1999 James Howard and Dag-Erling Coïdan Smørgrav
  Copyright (C) 2008-2009 Gabor Kovesdan <gabor@FreeBSD.org>
  All rights reserved.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
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

@main final class grep : ShellCommand {

  var usage : String = """
usage: grep [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] [-A num] [-B num] [-C[num]]
\t[-e pattern] [-f file] [--binary-files=value] [--color=when]
\t[--context[=num]] [--directories=action] [--label] [--line-buffered]
[--null] [pattern] [file ...]
"""
  
  struct CommandOptions {
    var dpatterns : [epat] = []
    var fpatterns : [epat] = []
    var patterns : [(String, regex_t)] = []
    
    var needpattern = true
    var lastc : String = ""
    var newarg = true
    
    var cflags : Int32 = REG_NOSUB | REG_NEWLINE
    var eflags : Int32 = REG_STARTEND
    var matchall : Bool = false
    
    var lbflag = false // line-buffered output
    
    var color : String?
    var label : String = "(standard input)"
    var Aflag : Int = 0 /* -A x: print x lines trailing each match */
    var Bflag : Int = 0 /* -B x: print x lines leading each match */
    var Hflag : Bool = false /* -H: always print file name */
    var Lflag = false    /* -L: only show names of files with no matches */
    var bflag = false    /* -b: show block numbers for each match */
    var cflag = false    /* -c: only show a count of matching lines */
    var hflag = false    /* -h: don't print filename headers */
    var iflag = false    /* -i: ignore case */
    var lflag = false    /* -l: only show names of files with matches */
    var mflag = false    /* -m x: stop reading the files after x matches */
    var mcount = 0  /* count for -m */
//    var mlimit = 0  /* requested value for -m */
    var fileeol : Character = "\n"  /* indicator for eol */
    var nflag = false    /* -n: show line numbers in front of matching lines */
    var oflag = false    /* -o: print only matching part */
    var qflag = false    /* -q: quiet mode (don't output anything) */
    var sflag = false    /* -s: silent mode (ignore errors) */
    var vflag = false    /* -v: only show non-matching lines */
    var wflag = false    /* -w: pattern must start and end on word boundaries */
    var xflag = false    /* -x: pattern must match entire line */
 //   var lbflag = false  /* --line-buffered */
    var nullflag = false  /* --null */

    var fexclude : Bool = false
    var finclude : Bool = false
    var dexclude : Bool = false
    var dinclude : Bool = false
    var binbehave : BINFILE = .BIN
    var devbehave : DEV = .READ
    var dirbehave : DIR = .READ
    var linkbehave : LINK = .DEFAULT
    var grepbehave : GREP = .BASIC
    var filebehave : FILE = .STDIO
    var args : [String] = CommandLine.arguments
  }
  
  let VERSION = "2.6.0 FreeBSD"
  
  // from grep.h
  enum GREP {
    case FIXED
    case BASIC
    case EXTENDED
  }

//  #if !defined(REG_NOSPEC) && !defined(REG_LITERAL)
//  #define WITH_INTERNAL_NOSPEC
//  #endif

  enum BINFILE {
    case BIN
    case SKIP
    case TEXT
  }
  
  enum DIR {
    case READ
    case SKIP
    case RECURSE
  }

  enum DEV {
    case READ
    case SKIP
  }

  enum LINK {
    case READ
    case EXPLICIT
    case SKIP
    case DEFAULT
  }

  enum PAT {
    case EXCL
    case INCL
  }



/*  struct pat {
    var pat : String
    var len : Int
  };
*/
  
  struct epat {
    var pat : String
    var mode : PAT
  }

  let errstr = [
      "",
    /* 1*/  "(standard input)",
    /* 2*/  "unknown %s option",
//    #ifdef __APPLE__
    /* 3*/  "usage: %s [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] [-A num] [-B num] [-C[num]]\n",
//    #else
//    /* 3*/  "usage: %s [-abcDEFGHhIiLlmnOoPqRSsUVvwxz] [-A num] [-B num] [-C[num]]\n",
//    #endif
    /* 4*/  "\t[-e pattern] [-f file] [--binary-files=value] [--color=when]\n",
    /* 5*/  "\t[--context[=num]] [--directories=action] [--label] [--line-buffered]\n",
    /* 6*/  "\t[--null] [pattern] [file ...]\n",
    /* 7*/  "Binary file %s matches\n",
    /* 8*/  "%s (BSD grep, GNU compatible) %s\n",
  ]
  
  
  func parseOptions() async throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    
  
    let flags =
    "0123456789A:B:C:D:EFGHIJLMOSRUVXZabcd:e:f:hilm:nopqrsuvwxyz"
//    "0123456789A:aB:bC:cD:d:Ee:Ff:GhHIiJlLm:MnoqrsUuVvwxXzZ"
    let long_options : [CMigration.option] = [
      .init("binary-files",  .required_argument),
      .init("help",    .no_argument),
      .init("mmap",    .no_argument),
       .init("line-buffered",  .no_argument),
      .init("label",    .required_argument),
      .init("null",    .no_argument),
      .init("color",    .optional_argument),
      .init("colour",    .optional_argument),
      .init("exclude",    .required_argument),
      .init("include",    .required_argument),
      .init("exclude-dir", .required_argument),
      .init("include-dir",    .required_argument),
      .init("after-context",  .required_argument),
      .init("text",    .no_argument), // "a"
      .init("before-context",  .required_argument), // "B"
      .init("byte-offset",    .no_argument), // "b"
      .init("context",    .optional_argument), // "C"
      .init("count",    .no_argument), // "c"
      .init("devices",    .required_argument), // "D"
      .init("directories",    .required_argument), // "d"
      .init("extended-regexp",  .no_argument ), // E
      .init("regexp",    .required_argument ), // e
      .init("fixed-strings",  .no_argument  ), // F
      .init("file",    .required_argument),    // f
        .init("basic-regexp",  .no_argument  ),  // G
      .init("no-filename",    .no_argument  ), // h
      .init("with-filename",  .no_argument  ), // H
      .init("ignore-case",    .no_argument  ), // i
//      #ifdef __APPLE__
      .init("bz2decompress",  .no_argument), // J
//      #endif
        .init("files-with-matches",  .no_argument), // l
      .init("files-without-match", .no_argument),   // L
      .init("max-count",    .required_argument),   // m
 //     #ifdef __APPLE__
      .init("lzma",    .no_argument),  // M
//      #endif
        .init("line-number",    .no_argument), // n
      .init("only-matching",  .no_argument),  // 'o'},
      .init("quiet",    .no_argument), // 'q'},
      .init("silent",    .no_argument), // 'q'},
      .init("recursive",    .no_argument), // 'r'},
        .init("no-messages",    .no_argument), // 's'},
      .init("binary",    .no_argument),  // 'U'},
      .init("unix-byte-offsets",  .no_argument), // 'u'},
      .init("invert-match",  .no_argument), // 'v'},
      .init("version",    .no_argument), // 'V'},
      .init("word-regexp",    .no_argument), //  'w'},
      .init("line-regexp",    .no_argument),  // 'x'},
      // #ifdef __APPLE__
        .init("xz",      .no_argument), // 'X'},
//      #endif
        .init("null-data",    .no_argument), // 'z'},
 //     #ifdef __APPLE__
        .init("decompress",          .no_argument), // 'Z'},
//      #endif
      ]
    
    
    
    
    /*
     * Check how we've bene invoked to determine the behavior we should
     * exhibit. In this way we can have all the functionalities in one
     * binary without the need of scripting and using ugly hacks.
     */
    var pn : any StringProtocol = String(cString: getprogname())

    // #ifdef __APPLE__
    if pn.hasPrefix("bz") {
      options.filebehave = .BZIP
      pn = pn.dropFirst(2)
    } else if pn.hasPrefix("xz") {
      options.filebehave = .XZ
      pn = pn.dropFirst(2)
    } else if pn.hasPrefix("lz") {
      options.filebehave = .LZMA
      pn = pn.dropFirst(2)
    } else if pn.hasPrefix("z") {
      options.filebehave = .GZIP
      pn = pn.dropFirst()
    }
    // #endif
    
    switch pn.first {
    case "e":
        options.grepbehave = .EXTENDED
      case "f":
        options.grepbehave = .FIXED
      case "r":
        //  #ifdef __APPLE__
      /*
       * rdar://problem/25930963 -- recursive grep, skip all symlinks
       * by default as documented in the manpage.
       */
        options.linkbehave = .SKIP
    //#endif
        options.dirbehave = .RECURSE
        options.Hflag = true
      default:
        break
    }
    
    var args : [String] = CommandLine.arguments
    if let eopts = ProcessInfo.processInfo.environment["GREP_OPTIONS"], !eopts.isEmpty {
      let aargs = eopts.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
      args = [CommandLine.arguments[0]]+aargs+CommandLine.arguments.dropFirst()
    }
    
    
    let go = BSDGetopt_long(flags, long_options, Array(args.dropFirst()) )
    
    while let (k, v) = try go.getopt_long() {
      switch k {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
          let cc = options.lastc.first?.isNumber == true
          
          // FIXME: how does "newarg" change?
          if options.newarg || !cc {
            options.Aflag = 0
          } else if options.Aflag > LLONG_MAX / 10 - 1 {
            throw CmdErr(2, "number outside range")
          }

          options.Aflag = (options.Aflag * 10) + Int(k)!
          options.Bflag = options.Aflag
        case "C", "context":
          if v.isEmpty {
            options.Aflag = 2
            options.Bflag = 2
            break
          }
          fallthrough
        case "A", "after-context":
          fallthrough
        case "B", "before-context":
          if !v.isEmpty, let l = Int(v) {
            if l < 0 {
              throw CmdErr(2, "context argument must be non-negative")
            }
            if (k == "A") {
              options.Aflag = l
            }
            else if (k == "B") {
              options.Bflag = l
            } else {
              options.Aflag = l
              options.Bflag = l
            }
          } else {
            // I prefer 'invalid number'
            throw CmdErr(2, "Invalid argument -- \(v)")
          }
        case "a", "text":
          options.binbehave = .TEXT
        case "b", "byte-offset":
          options.bflag = true
        case "c", "count":
          options.cflag = true
        case "D", "devices":
          if v.lowercased() == "skip" {
            options.devbehave = .SKIP
          } else if v.lowercased() == "read" {
            options.devbehave = .READ
          } else {
            throw CmdErr(2, "unknown --devices option: \(v)")
          }
        case "d", "directories":
          if v.lowercased() == "recurse" {
//    #ifdef __APPLE__
            /* rdar://problem/25930963 */
            if (options.linkbehave == .DEFAULT) {
              options.linkbehave = .SKIP
            }
//    #endif
            options.Hflag = true
            options.dirbehave = .RECURSE
          } else if v.lowercased() == "skip" {
            options.dirbehave = .SKIP
          } else if v.lowercased() == "read" {
            options.dirbehave = .READ
          } else {
            throw CmdErr(2, "unknown --directories option: \(v)")
          }
        case "E", "extended-regexp":
          options.grepbehave = .EXTENDED
        case "e", "regexp":
          for token in v.split(separator: "\n", omittingEmptySubsequences: false) {
            add_pattern(String(token), &options)
          }
          options.needpattern = false
        case "F", "fixed-strings":
          options.grepbehave = .FIXED
        case "f", "file":
          try await read_patterns(v, &options)
          options.needpattern = false
        case "G", "basic-regexp":
          options.grepbehave = .BASIC
        case "H", "with-filename":
          options.Hflag = true
        case "h", "no-filename":
          options.Hflag = false
          options.hflag = true
          // FIXME: the original did not recognize -I
        case "I":
          options.binbehave = .SKIP
        case "i", "y", "ignore-case":
          options.iflag =  true
          options.cflags |= REG_ICASE
//    #ifdef __APPLE__
        case "J", "bz2decompress":
          options.filebehave = .BZIP
//    #endif
        case "L", "files-without-match":
          options.lflag = false
          options.Lflag = true
        case "l", "files-with-matches":
          options.Lflag = false
          options.lflag = true
        case "m", "max-count":
          options.mflag = true
          if let mcount = Int(v), mcount > 0 {
            options.mcount = mcount
          } else {
            throw CmdErr(2, "invalid number for -m: \(v)")
          }

//    #ifdef __APPLE__
        case "M", "lzma":
          options.filebehave = .LZMA
//    #endif
        case "n", "line-number":
          options.nflag = true
          // FIXME: there is no way to invoke this
        case "O":
          options.linkbehave = .EXPLICIT
        case "o", "only-matching":
          options.oflag = true
          options.cflags &= ~REG_NOSUB
          // FIXME: there is no way to invoke this
        case "p":
          options.linkbehave = .SKIP
        case "q", "quiet", "silent":
          options.qflag = true
          // FIXME: there is no way to invoke this
        case "S":
          options.linkbehave = .READ
        case "R", "r", "recursive":
//    #ifdef __APPLE__
          /* rdar://problem/25930963 */
          if options.linkbehave == .DEFAULT {
            options.linkbehave = .SKIP
          }
//    #endif
          options.dirbehave = .RECURSE
          options.Hflag = true
        case "s", "no-messages":
          options.sflag = true
        case "U", "binary":
          options.binbehave = .BIN
        case "u","unix-byte-offsets", "mmap":
          options.filebehave = .MMAP
        case "V", "version":
          let msg = "\(pn) (BSD grep, GNU compatible) \(VERSION)"
          var fh = FileHandle.standardError
          print(msg, to: &fh)
          exit(0);
        case "v", "invert-match":
          options.vflag = true
        case "w", "word-regexp":
          options.wflag = true
          options.cflags &= ~REG_NOSUB;
        case "x", "line-regexp":
          options.xflag = true
          options.cflags &= ~REG_NOSUB;
//    #ifdef __APPLE__
        case "X", "xz":
          options.filebehave = .XZ
//    #endif
        case "z", "null-data":
          options.fileeol = "\0"
//    #ifdef __APPLE__
        case "Z":
          options.filebehave = .GZIP
//    #endif
        case "binary-files":
          if v.lowercased() == "binary" {
            options.binbehave = .BIN
          } else if v.lowercased() == "without-match" {
            options.binbehave = .SKIP
          } else if v.lowercased() == "text" {
            options.binbehave = .TEXT
          } else {
            throw CmdErr(2, "unknown --binary-files option: \(v)")
          }
        case "color", "colour":
          let vv = v.lowercased()
          if v.isEmpty || vv == "auto" ||
              vv == "tty" ||
              vv == "if-tty" {
            let term = ProcessInfo.processInfo.environment["TERM"]
            if isatty(STDOUT_FILENO) != 0 &&
                term != nil &&
                vv != "dumb" {
              options.color = init_color("01;31")
            }
          } else if vv == "always" ||
                      vv == "yes" ||
                      vv == "force" {
            options.color = init_color("01;31")
          } else if vv != "never" &&
                      vv != "none" &&
                      vv !=  "no" {
            throw CmdErr(2, "unknown --color option: \(v)")
          }
          options.cflags &= ~REG_NOSUB;
          break;
        case "label":
          options.label = v
        case "line-buffered":
          options.lbflag = true
        case "null":
          options.nullflag = true
        case "include":
          options.finclude = true
          add_fpattern(v, PAT.INCL, &options)
        case "exclude":
          options.fexclude = true
          add_fpattern(v, PAT.EXCL, &options);
        case "include-dir":
          options.dinclude = true
          add_dpattern(v, PAT.INCL, &options);
        case "exclude-dir":
          options.dexclude = true
          add_dpattern(v, PAT.EXCL, &options);
        case "help", "?":
          fallthrough
        default:
          throw CmdErr(1)
      }
      options.lastc = k

      
      
    }
    
    options.args = go.remaining
    
    
//    #ifdef __APPLE__
      /* rdar://problem/25930963 -- non-recursive grep, read any symlinks. */
    if options.linkbehave == .DEFAULT {
      options.linkbehave = .READ
    }
//    #endif

      /* xflag takes precedence, don't confuse the matching bits. */
    if (options.wflag && options.xflag) {
      options.wflag = false
    }

      /* Fail if we don't have any pattern */
    if options.args.count == 0 && options.needpattern {
      throw CmdErr(1)
    }

      /* Process patterns from command line */
    if (options.args.count != 0 && options.needpattern) {
      for token in options.args[0].split(separator: "\n", omittingEmptySubsequences: false) {
        add_pattern(String(token), &options )
      }
      options.args.removeFirst()
    }

    switch (options.grepbehave) {
      case .BASIC:
//    #ifdef __APPLE__
        options.cflags |= REG_ENHANCED;
//    #endif
        break;
      case .FIXED:
        /*
         * regex(3) implementations that support fixed-string searches generally
         * define either REG_NOSPEC or REG_LITERAL. Set the appropriate flag
         * here. If neither are defined, GREP_FIXED later implies that the
         * internal literal matcher should be used. Other cflags that have
         * the same interpretation as REG_NOSPEC and REG_LITERAL should be
         * similarly added here, and grep.h should be amended to take this into
         * consideration when defining WITH_INTERNAL_NOSPEC.
         */
//    #if defined(REG_NOSPEC)
        options.cflags |= REG_NOSPEC;
//    #elif defined(REG_LITERAL)
//        cflags |= REG_LITERAL;
//    #endif
//        break;
      case .EXTENDED:
        options.cflags |= REG_EXTENDED
//    #ifdef __APPLE__
        options.cflags |= REG_ENHANCED
//    #endif
//        break;
      default:
        /* NOTREACHED */
        throw CmdErr(1)
      }

//    var r_pattern = Array(repeating: regex_t(), count: options.patterns.count)

//    #ifdef WITH_INTERNAL_NOSPEC
//    if options.grepbehave != .FIXED {
//    #else
//      {
//    #endif
        /* Check if cheating is allowed (always is for fgrep). */
      for i in 0..<options.patterns.count {
        let c = regcomp(&options.patterns[i].1, options.patterns[i].0, options.cflags)
          if (c != 0) {
            
            let RE_ERROR_BUF = 512
            let re_error = calloc(1, RE_ERROR_BUF)
            regerror(c, &options.patterns[i].1, re_error,
                RE_ERROR_BUF);
            throw CmdErr(2, String(cString: re_error!.assumingMemoryBound(to: CChar.self)))
          }
        }
      

        if (options.lbflag) {
          setlinebuf(stdout)
        }

    if options.args.count < 2 && !options.Hflag {
      options.hflag = true
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    return options
  }
  
  func init_color(_ d : String) -> String {
    if let c = ProcessInfo.processInfo.environment["GREP_COLOR"], !c.isEmpty {
      return c
    } else {
      return d
    }
  }

  // Adds a file include/exclude pattern to the internal array.
  func add_fpattern(_ pat : String , _ mode : PAT, _ options : inout CommandOptions)
  {
    options.fpatterns.append(epat(pat: pat, mode: mode) )
  }

  // Adds a directory include/exclude pattern to the internal array.
  func add_dpattern(_ pat : String , _ mode : PAT, _ options: inout CommandOptions)
  {
    options.dpatterns.append(epat(pat: pat, mode: mode) )
  }

  // Adds a searching pattern to the internal array.
  func add_pattern(_ pat : String, _ options : inout CommandOptions ) {

    // Check if we can do a shortcut
    if pat.isEmpty {
      options.matchall = true;
      return;
    }

    var patx = pat
    while patx.last == "\n" { patx.removeLast() }
    options.patterns.append((patx, regex_t()))
  }


   // Reads searching patterns from a file and adds them with add_pattern().
  func read_patterns(_ fn : String, _ options : inout CommandOptions) async throws(CmdErr) {
    var f : FileHandle
    if fn == "-" {
      f = FileHandle.standardInput
    } else {
      do {
        try f = FileHandle(forReadingFrom: URL(fileURLWithPath: fn))
      } catch {
        throw CmdErr(2, "read error: \(fn): \(error.localizedDescription)")
      }
    }
    defer { if f != FileHandle.standardInput { try? f.close() } }

/*    if ((fstat(fileno(f), &st) == -1) || (S_ISDIR(st.st_mode))) {
      fclose(f);
      return;
    }
    len = 0;
    line = NULL;
 */
    do {
      for try await var line in f.bytes.linesNLX {
        //    while ((rlen = getline(&line, &len, f)) != -1) {
        if line.isEmpty || line.first == "\0" { continue }
        if line.last == "\n" { line.removeLast() }
        add_pattern(line, &options)
      }
    } catch {
      throw CmdErr(2, "read error: \(fn): \(error.localizedDescription)")
    }
  }

  func runCommand(_ optionsx: CommandOptions) throws(CmdErr) {
    // FIXME: create the queue when I know what it does
    //    initqueue();
    let options = optionsx
    let grepDoer = grepDoer(options)
    
    //  #ifdef __APPLE__
    if options.args.count == 0 && options.dirbehave != .RECURSE {
      let matched = grepDoer.procfile("-", nil)
      //      if (ferror(stdout) != 0 || fflush(stdout) != 0)
      //        err(2, "stdout");
      exit(matched ? 0 : 1);
    }
    //  #else
    //    if (aargc == 0 && dirbehave != DIR_RECURSE)
    //      exit(!procfile("-", NULL));
    //  #endif
    var matched = false
    if (options.dirbehave == .RECURSE) {
      matched = grepDoer.grep_tree(options.args);
    }
    else {
      for aa in options.args {
        if ((options.finclude || options.fexclude) && !grepDoer.file_matching(aa)) {
          continue
        }
        if (grepDoer.procfile(aa, nil)) {
          matched = true;
        }
      }
    }
    //  #ifndef __APPLE__
    //    /* rdar://problem/88986027 - The -L flag's exit status is inverted. */
    //   if (Lflag)
    //      matched = !matched;
    //  #endif
    
    //  #ifdef __APPLE__
    //    if (ferror(stdout) != 0 || fflush(stdout) != 0)
    //      err(2, "stdout");
    //  #endif
    
    /*
     * Calculate the correct return value according to the
     * results and the command line option.
     */
    
    // FIXME: implement file_err ?
    if matched {
      if grepDoer.file_err {
        exit(options.qflag ? 0 : 2)
      } else {
        exit(0)
      }
    } else {
      if grepDoer.file_err {
        exit(2)
      } else {
        exit(1)
      }
    }
  }
}
