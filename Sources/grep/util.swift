// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file containing the following notice:

import CMigration

/*-
  SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 
  Copyright (c) 1999 James Howard and Dag-Erling Coïdan Smørgrav
  Copyright (C) 2008-2010 Gabor Kovesdan <gabor@FreeBSD.org>
  Copyright (C) 2017 Kyle Evans <kevans@FreeBSD.org>
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

class grepDoer {

  var file_err = false
  var first_match = true
  var options : grep.CommandOptions
  var mcount : Int
  var queue : [str] = []
  var myParsec : parsec!
  var myMprintc : mprintc!
  
  let MAX_MATCHES = 32

  init(_ options: grep.CommandOptions) {
    self.options = options
    self.mcount = options.mcount
  }
  
  
  /*
   * Parsing context; used to hold things like matches made and
   * other useful bits
   */
  struct parsec {
    var matches : [Regex<AnyRegexOutput>.Match] =  [] /* Matches made */
    /* XXX TODO: This should be a chunk, not a line */
    var ln : str         /* Current line */
    var f : file         /* Underlying file */
    var lnstart : String.Index       /* Position in line */
//    var matchidx : Int = 0       /* Latest match index */
    var printed : Int = 0        /* Metadata printed? */
    var binary : Bool = false    /* Binary file? */
    var cntlines : Bool = false  /* Count lines? */
    
    init(f: file) {
      self.f = f
      self.ln = str(file: f.name)
      self.lnstart = ln.dat.startIndex
    }
  };

  struct str {
    var boff : Int = 0
    var off : Int = -1
//    var len : Int
    // FIXME: maybe Data?
    var dat : String = ""
    var file : String
    var line_no : Int = 0
  }


  /*
   * Match printing context
   */
  struct mprintc {
    var tail : Int = 0   /* Number of trailing lines to record */
    var last_outed : Int = 0  /* Number of lines since last output */
    var doctx : Bool = false    /* Printing context? */
    var printmatch : Bool = false  /* Printing matches? */
    var same_file : Bool = false  /* Same file as previously printed? */
  };
  
  /*
   static void procmatch_match(struct mprintc *mc, struct parsec *pc);
   static void procmatch_nomatch(struct mprintc *mc, struct parsec *pc);
   static bool procmatches(struct mprintc *mc, struct parsec *pc, bool matched);
   #ifdef WITH_INTERNAL_NOSPEC
   static int litexec(const struct pat *pat, const char *string,
   size_t nmatch, regmatch_t pmatch[]);
   #endif
   static bool procline(struct parsec *pc);
   static void printline(struct parsec *pc, int sep);
   static void printline_metadata(struct str *line, int sep);
   */
  
  func file_matching(_ fname : String) -> Bool {
    //  char *fname_base, *fname_buf;
    
    var ret = options.finclude ? false : true
    
    let fname_base = fname.withCString {
      let a = UnsafeMutablePointer<CChar>(mutating: $0)
      return String(cString: basename(a))
    }
    
    for fp in options.fpatterns {
      if (fnmatch(fp.pat, fname, 0) == 0 ||
          fnmatch(fp.pat, fname_base, 0) == 0) {
        /*
         * The last pattern matched wins exclusion/inclusion
         * rights, so we can't reasonably bail out early here.
         */
        ret = (fp.mode != grep.PAT.EXCL)
      }
    }
    return (ret);
  }
  
  func dir_matching(_ dname : String?) -> Bool {
    
    var ret = options.dinclude ? false : true;
    
    for ii in options.dpatterns {
      if let dname, 0 == fnmatch(ii.pat, dname, 0) {
        /*
         * The last pattern matched wins exclusion/inclusion
         * rights, so we can't reasonably bail out early here.
         */
        ret = (ii.mode != .EXCL)
      }
    }
    return (ret);
  }
  
  
  /*
   * Processes a directory when a recursive search is performed with
   * the -R option.  Each appropriate file is passed to procfile().
   */
  func grep_tree(_ argv : [String]) throws(CmdErr) -> Bool {
    //  bool ok;
    //  const char *wd[] = { ".", NULL };
    
    var matched = false;
    
    var fts_flags : Int32 = FTS_NOCHDIR;
    
    
    /* This switch effectively initializes 'fts_flags' */
    switch options.linkbehave {
      case .EXPLICIT:
        fts_flags |= FTS_COMFOLLOW | FTS_PHYSICAL;
        break;
        // #ifdef __APPLE__
        //     case .DEFAULT:
        /*
         * LINK_DEFAULT *should* have been translated to an explicit behavior
         * before we reach this point.  Assert as much, but treat it as an
         * explicit skip if assertions are disabled to maintain the documented
         * default behavior.
         */
        //    assert(0 && "Unreachable segment reached");
        //    fallthrough
        // #endif
      case .DEFAULT, .SKIP:
        fts_flags |= FTS_PHYSICAL;
        break;
      default:
        fts_flags |= FTS_LOGICAL | FTS_NOSTAT;
    }
    
    let vv = argv.isEmpty ? ["."] : argv
    var vvv = vv.map { strdup($0) }
    vvv.append(nil)
    let fts = fts_open(vvv, fts_flags, nil);
    if (fts == nil) {
      err(2, "fts_open");
    }
    while let p = fts_read(fts) {
      switch Int32((p.pointee.fts_info)) {
        case FTS_DNR, FTS_ERR:
          file_err = true;
          if(!options.sflag) {
            warnx("\(String(cString: p.pointee.fts_path)): \(String(cString: strerror(p.pointee.fts_errno)))");
          }
          break;
        case FTS_D, FTS_DP:
          if (options.dexclude || options.dinclude) {
            let ss1 = withUnsafePointer(to: p.pointee.fts_name) { pn in
              String(cString: pn)
            }
            
            if (!dir_matching(ss1) ||
                !dir_matching( String(cString: p.pointee.fts_path))) {
              fts_set(fts, p, FTS_SKIP);
            }
          }
          break;
        case FTS_DC:
          /* Print a warning for recursive directory loop */
          warnx("warning: \(String(cString: p.pointee.fts_path)): recursive directory loop")
          break;
          // #ifdef __APPLE__
        case FTS_SL:
          /*
           * If we see a symlink, it's because a linkbehave has
           * been specified that should be skipping them; do so
           * silently.
           */
          break;
        case FTS_SLNONE:
          /*
           * We should not complain about broken symlinks if
           * we would skip it anyways.  Notably, if skip was
           * specified or we're observing a broken symlink past
           * the root.
           */
          if (options.linkbehave == .SKIP ||
              (options.linkbehave == .EXPLICIT &&
               p.pointee.fts_level > FTS_ROOTLEVEL)) {
            break;
          }
          fallthrough
          // #endif
        default:
          /* Check for file exclusion/inclusion */
          var ok = true;
          if (options.fexclude || options.finclude) {
            ok = ok && file_matching(String(cString: p.pointee.fts_path))
          }
          
          if ok {
            
            if try procfile(String(cString: p.pointee.fts_path),
                            (fts_flags & FTS_NOSTAT) != 0 ? nil : p.pointee.fts_statp.pointee) {
              matched = true;
            }
          }
          break;
      }
    }
    if (errno != 0) {
      err(2, "fts_read")
    }
    
    fts_close(fts);
    return (matched)
  }
  
  func procmatch_match() throws(CmdErr) {
    
    if (myMprintc.doctx) {
      if (!first_match && (!myMprintc.same_file || myMprintc.last_outed > 0)) {
        print("--")
      }
      if (options.Bflag > 0) {
        for item in queue {
          grep_printline(item, "-")
        }
        queue = []
      }
      myMprintc.tail = options.Aflag;
    }
    
    /* Print the matching line, but only if not quiet/binary */
    if (myMprintc.printmatch) {
      printline(":")
      while (myParsec.matches.count >= MAX_MATCHES) {
        /* Reset matchidx and try again */
        myParsec.matches = []
        if (try procline() == !options.vflag) {
          printline(":")
        }
        else {
          break
        }
      }
      first_match = false
      myMprintc.same_file = true
      myMprintc.last_outed = 0
    }
  }
  
  func procmatch_nomatch() {
    
    /* Deal with any -A context as needed */
    if (myMprintc.tail > 0) {
      grep_printline(myParsec.ln, "-")
      myMprintc.tail -= 1
      if (options.Bflag > 0) {
        queue = []
      }
    } else if options.Bflag == 0 {
      myMprintc.last_outed += 1
    } else if options.Bflag > 0 {
      queue.append(myParsec.ln)
      /*
       * Enqueue non-matching lines for -B context. If we're not
       * actually doing -B context or if the enqueue resulted in a
       * line being rotated out, then go ahead and increment
       * last_outed to signify a gap between context/match.
       */
      
      while queue.count > options.Bflag {
        queue.removeFirst()
        myMprintc.last_outed += 1
      }
    }
  }
  
  /*
   * Process any matches in the current parsing context, return a boolean
   * indicating whether we should halt any further processing or not. 'true' to
   * continue processing, 'false' to halt.
   */
  func procmatches(_ matched : Bool) throws(CmdErr) -> Bool {
    
    if (options.mflag && mcount <= 0) {
      /*
       * We already hit our match count, but we need to keep dumping
       * lines until we've lost our tail.
       */
      grep_printline(myParsec.ln, "-")
      myMprintc.tail -= 1
      return (myMprintc.tail != 0)
    }
    
    /*
     * XXX TODO: This should loop over pc->matches and handle things on a
     * line-by-line basis, setting up a `struct str` as needed.
     */
    /* Deal with any -B context or context separators */
    if (matched) {
      try procmatch_match();
      
      /* Count the matches if we have a match limit */
      if (options.mflag) {
        /* XXX TODO: Decrement by number of matched lines */
        mcount -= 1;
        if (mcount <= 0) {
          return (myMprintc.tail != 0)
        }
      }
    } else if (myMprintc.doctx) {
      procmatch_nomatch()
    }
    
    return (true);
  }
  
  /*
   * Opens a file and processes it.  Each file is processed line-by-line
   * passing the lines to procline().
   */
  func procfile( _ fnx : String, _ psbp : stat?) throws(CmdErr) -> Bool {
    
    //    struct parsec pc;
    /*    struct mprintc mc;
     struct file *f;
     struct stat sb, *sbp;
     mode_t s;
     int lines;
     bool line_matched;
     */
    
    var fn : String = fnx
    var f : file?
    if fnx == "-" {
      fn = options.label
      f = file(nil, options.filebehave, options.fileeol, options.binbehave)
    } else {
      var sbp = stat()
      if let psbp  { sbp = psbp }
      else {
        if stat(fn, &sbp) == 0 {
          /* Check if we need to process the file */
          let s = sbp.st_mode & S_IFMT
          if (options.dirbehave == .SKIP && s == S_IFDIR) {
            return (false);
          }
          if (options.devbehave == .SKIP && (s == S_IFIFO ||
                                             s == S_IFCHR || s == S_IFBLK || s == S_IFSOCK)) {
            return (false)
          }
        }
      }
      f = file(fn, options.filebehave, options.fileeol, options.binbehave)
    }
    guard let f else {
      file_err = true;
      if (!options.sflag) {
        warn(fn)
      }
      return (false)
    }
    
//    let ln = str(boff: 0, off: -1, dat: "", file: fn, line_no: 0)
    myParsec = parsec(f: f)
    // Initialize here? !!
    myMprintc = mprintc()
    

    
    /*      pc.ln.file = fn
     pc.ln.line_no = 0;
     pc.ln.len = 0;
     pc.ln.boff = 0;
     pc.ln.off = -1;
     */
    //    #ifdef __APPLE__
    /*
     * The parse context tracks whether we're treating this like a binary
     * file, but some parts of the search may need to know whether the file
     * was actually detected as a binary ile.
     */
    
    myParsec.binary = f.binary && options.binbehave != .TEXT
    // #else
    //     pc.binary = f->binary;
    // #endif
    myParsec.cntlines = false;
    
    
    //    memset(&mc, 0, sizeof(mc));
    
    myMprintc = mprintc()
    
    myMprintc.printmatch = true;
    if ((myParsec.binary && options.binbehave == .BIN) || options.cflag || options.qflag ||
        options.lflag || options.Lflag) {
      myMprintc.printmatch = false;
    }
    if (myMprintc.printmatch && (options.Aflag != 0 || options.Bflag != 0)) {
      myMprintc.doctx = true;
    }
    if (myMprintc.printmatch && (options.Aflag != 0 || options.Bflag != 0 || options.mflag || options.nflag)) {
      myParsec.cntlines = true;
    }
    let mcount = options.mcount
    
    var lines = 0
    while lines == 0 || !(options.lflag || options.qflag) {
      /*
       * XXX TODO: We need to revisit this in a chunking world. We're
       * not going to be doing per-line statistics because of the
       * overhead involved. procmatches can figure that stuff out as
       * needed. */
      /* Reset per-line statistics */
      myParsec.printed = 0;
      myParsec.matches = []
      myParsec.lnstart = myParsec.ln.dat.startIndex
      myParsec.ln.boff = 0;
      myParsec.ln.off += myParsec.ln.dat.count + 1;
      
      /* XXX TODO: Grab a chunk */
      if let pld = f.grep_fgetln(&myParsec, options) {
        myParsec.ln.dat = pld
        if pld.isEmpty { break }
      } else {
        break;
      }
      
      
      if (myParsec.ln.dat.count > 0 && myParsec.ln.dat.last == options.fileeol) {
        myParsec.ln.dat.removeLast()
      }
      myParsec.ln.line_no += 1
      
      /* Return if we need to skip a binary file */
      if (myParsec.binary && options.binbehave == .SKIP) {
        f.grep_close()
        return false
      }
      
      if (options.mflag && mcount <= 0) {
        /*
         * Short-circuit, already hit match count and now we're
         * just picking up any remaining pieces.
         */
        if try !procmatches(false) {
          break;
        }
        continue;
      }
      let line_matched = try procline() == !options.vflag;
      if (line_matched) {
        lines += 1
      }
      
      /* Halt processing if we hit our match limit */
      if try !procmatches(line_matched) {
        break;
      }
    }
    
    if (options.Bflag > 0) {
      queue = []
    }
    f.grep_close()
    
    //    #ifdef __APPLE__
    /*
     * See rdar://problem/10680370 -- the `-q` flag should suppress normal
     * output, including this.  This is especially important here, as the count
     * that would typically be output here may not reflect the reality because
     * `-q` is allowed to short-circuit if it finds a match.
     */
    if (options.cflag && !options.qflag) {
      // #else
      //      if (cflag) {
      // #endif
      if (!options.hflag) {
        print("\(myParsec.ln.file):", terminator: "")
      }
      print("\(lines)")
    }
    if (options.lflag && !options.qflag && lines != 0) {
      print(fn, terminator: options.nullflag ? "" : "\n")
    }
    if (options.Lflag && !options.qflag && lines == 0) {
      print(fn, terminator: options.nullflag ? "" : "\n")
    }
    if (lines != 0 && !options.cflag && !options.lflag && !options.Lflag &&
        options.binbehave == .BIN && f.binary && !options.qflag) {
      print("Binary file \(fn) matches")
    }
    
    //      free(pc.ln.file);
    //      free(f);
    return (lines != 0);
  }
  
   
//   #ifdef WITH_INTERNAL_NOSPEC
/*   /*
    * Internal implementation of literal string search within a string, modeled
    * after regexec(3), for use when the regex(3) implementation doesn't offer
    * either REG_NOSPEC or REG_LITERAL. This does not apply in the default FreeBSD
    * config, but in other scenarios such as building against libgnuregex or on
    * some non-FreeBSD OSes.
    */
  private func litexec(_ pat : String, _ string : String, _ nmatch : Int,
                       _ pmatch : [regmatch_t])
   {
   char *(*strstr_fn)(const char *, const char *);
   char *sub, *subject;
   const char *search;
   size_t idx, n, ofs, stringlen;
   
     if (cflags & REG_ICASE) {
       strstr_fn = strcasestr;
     }
     else {
       strstr_fn = strstr;
     }
   idx = 0;
   ofs = pmatch[0].rm_so;
   stringlen = pmatch[0].rm_eo;
     if (ofs >= stringlen) {
       return (REG_NOMATCH);
     }
   subject = strndup(string, stringlen);
     if (subject == NULL) {
       return (REG_ESPACE);
     }
   for (n = 0; ofs < stringlen;) {
   search = (subject + ofs);
     if ((unsigned long)pat->len > strlen(search)) {
       break;
     }
   sub = strstr_fn(search, pat->pat);
   /*
    * Ignoring the empty string possibility due to context: grep optimizes
    * for empty patterns and will never reach this point.
    */
     if (sub == NULL) {
       break;
     }
   ++n;
   /* Fill in pmatch if necessary */
   if (nmatch > 0) {
   pmatch[idx].rm_so = ofs + (sub - search);
   pmatch[idx].rm_eo = pmatch[idx].rm_so + pat->len;
     if (++idx == nmatch) {
       break;
     }
   ofs = pmatch[idx].rm_so + 1;
   } else {
     /* We only needed to know if we match or not */
     break;
   }
   }
   free(subject);
     if (n > 0 && nmatch > 0) {
       for (n = idx; n < nmatch; ++n) {
         pmatch[n].rm_so = pmatch[n].rm_eo = -1;
       }
     }
   return (n > 0 ? 0 : REG_NOMATCH);
   }
//   #endif /* WITH_INTERNAL_NOSPEC */
  */
  
  
  /*
//   #ifdef __APPLE__
   static int
   mbtowc_reverse(wchar_t *pwc, const char *s, size_t n)
   {
   int result;
   size_t i;
   
   result = -1;
   for (i = 1; i <= n; i++) {
   result = mbtowc(pwc, s - i, i);
   if (result != -1) {
   break;
   }
   }
  
   return result;
   }
//   #endif
  */
  
  
  func iswword(_ x : Character) -> Bool {
    return x.isLetter || x.isNumber || x == "_"
  }
  
  /*
   * Processes a line comparing it with the specified patterns.  Each pattern
   * is looped to be compared along with the full string, saving each and every
   * match, which is necessary to colorize the output and to count the
   * matches.  The matching lines are passed to printline() to display the
   * appropriate output.
   */
  func procline() throws(CmdErr) -> Bool {
    /*
     regmatch_t pmatch, lastmatch, chkmatch;
     wchar_t wbegin, wend;
     size_t st, nst;
     unsigned int i;
     int r = 0, leflags = eflags;
     size_t startm = 0, matchidx;
     unsigned int retry;
     bool lastmatched, matched;
     */
    
//    var matchidx = myParsec.matchidx;
    
    /* Null pattern shortcuts. */
    if (options.matchall) {
      if (options.xflag && myParsec.ln.dat.count == 0) {
        /* Matches empty lines (-x). */
        return (true);
      } else if (!options.wflag && !options.xflag) {
        /* Matches every line (no -w or -x). */
        return (true);
      }
      
      /*
       * If we only have the NULL pattern, whether we match or not
       * depends on if we got here with -w or -x.  If either is set,
       * the answer is no.  If we have other patterns, we'll defer
       * to them.
       */
      if (options.patterns.count == 0) {
        return (!(options.wflag || options.xflag));
      }
    } else if (options.patterns.count == 0) {
      /* Pattern file with no patterns. */
      return (false);
    }
    
    var matched = false;
    var st : String.Index = myParsec.lnstart
    var nst : String.Index = myParsec.ln.dat.endIndex
    var nstdone = false
    
    /* Initialize to avoid a false positive warning from GCC. */
    var lastmatch : Regex<AnyRegexOutput>.Match?
//    lastmatch.rm_so = 0
//    lastmatch.rm_eo = 0
    var leflags = options.eflags
    
//    var r : Int32 = 0
    var retry : String.Index = myParsec.ln.dat.startIndex

    /* Loop to process the whole line */
    while ( (!nstdone) && st <= myParsec.ln.dat.endIndex) {
      var lastmatched = false;
      retry = myParsec.ln.dat.startIndex
      let startm = myParsec.matches.count;
//      if (st > myParsec.ln.dat.startIndex && myParsec.ln.dat[myParsec.ln.dat.index(before: st)] != options.fileeol) { leflags |= REG_NOTBOL; }

 //     var pmatch = regmatch_t()

      /* Loop to compare with all the patterns */
      for pati in options.regexes {
        
        // FIXME: does this do anything?
        //          #ifdef __APPLE__
        /* rdar://problem/10462853: Treat binary files as binary. */
        if (myParsec.f.binary) {
          setlocale(LC_ALL, "C");
        }
        
        // #endif /* __APPLE__ */
//        pmatch.rm_so = Int64(myParsec.ln.dat.distance(from: myParsec.ln.dat.startIndex, to: st))
//        pmatch.rm_eo = Int64(myParsec.ln.dat.count)
        
        //          #ifdef WITH_INTERNAL_NOSPEC
        //        if (options.grepbehave == .FIXED) {
        //          r = litexec(pati, pc.ln.dat, 1, &pmatch);
        //        }
        //        else {
        // #endif
        
        var pmatch : Regex<AnyRegexOutput>.Match?
        
        do {
          if myParsec.f.binary {
            fatalError("should I be using a regex? -- the index st is not correct")
            let ll = encodeLatin1Lossy(myParsec.ln.dat)
            // FIXME: what about leflags?
            pmatch = try pati.firstMatch(in: myParsec.ln.dat[st...])
        } else {
          // FIXME: what about leflags
          pmatch = try pati.firstMatch(in: myParsec.ln.dat[st...])
        }
      } catch(let e) {
        throw CmdErr(2, "\(e)")
      }
                // FIXME: does this do anything?
        //          #ifdef __APPLE__
        /* rdar://problem/10462853: Treat binary files as binary. */
        if (myParsec.f.binary) {
          setlocale(LC_ALL, "");
        }
        // #endif /* __APPLE__ */
//                if (pmatch == nil || pmatch?.count == 0) {
//          continue;
//        }
        guard var pmatch, pmatch.count > 0 else { continue }
        
        
        /* Check for full match */
        // FIXME: put me back
        if options.xflag {
          
    // (pmatch.rm_so != 0 || pmatch.rm_eo != myParsec.ln.dat.count)) {
          fatalError("not yet implemented")
          continue;
        }


        let ppmatch = pmatch[options.wflag ? 1 : 0]
        /* Check for whole word match */
        if (options.wflag) {
/*
          
          if pmatch.range.lowerBound != myParsec.ln.dat.startIndex &&
              
              //                #ifdef __APPLE__
              iswword(myParsec.ln.dat[ myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_so) - 1) ]) {
//              mbtowc_reverse(&wbegin, myParsec.ln.dat[pmatch.rm_so], MAX(MB_CUR_MAX, pmatch.rm_so)) == -1) {
            //                #else
            //                sscanf(&pc->ln.dat[pmatch.rm_so - 1],
            //                       "%lc", &wbegin) != 1)
            // #endif /* __APPLE__ */
            r = REG_NOMATCH;
          }
          else if pmatch.range.upperBound !=
                    myParsec.ln.dat.endIndex &&
                   
                   iswword(myParsec.ln.dat[ myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_eo))]) {
                   //                     #ifdef __APPLE__
//                   mbtowc(&wend, &myParsec.ln.dat[pmatch.rm_eo], max(MB_CUR_MAX, myParsec.ln.len - pmatch.rm_eo)) == -1) {
            //                      #else
            //                      sscanf(&pc->ln.dat[pmatch.rm_eo],
            //                             "%lc", &wend) != 1)
            // #endif /* __APPLE__ */
            r = REG_NOMATCH;
          }
//          else if (iswword(wbegin) ||
//                   iswword(wend)) {
//            r = REG_NOMATCH;
//          }
          /*
           * If we're doing whole word matching and we
           * matched once, then we should try the pattern
           * again after advancing just past the start of
           * the earliest match. This allows the pattern
           * to  match later on in the line and possibly
           * still match a whole word.
           */
          if (r == REG_NOMATCH &&
              (retry == myParsec.lnstart ||
               (myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_so+1)) < retry))) {
//               pmatch.rm_so + 1 < retry)) {
            retry = myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_so+1))
          }
          if (r == REG_NOMATCH) {
            continue;
          }
 */
        }
        lastmatched = true;
        lastmatch = pmatch;
        
        if (myParsec.matches.count == 0) {
          matched = true;
        }
        
        /*
         * Replace previous match if the new one is earlier
         * and/or longer. This will lead to some amount of
         * extra work if -o/--color are specified, but it's
         * worth it from a correctness point of view.
         */
        if (myParsec.matches.count > startm) {
          let chkmatch = myParsec.matches.last!
          
          
          if (pmatch.startIndex < chkmatch.startIndex ||
              (pmatch.startIndex == chkmatch.startIndex &&
               pmatch.endIndex > chkmatch.endIndex)) {
            myParsec.matches[myParsec.matches.count - 1] = pmatch;
       //     nst = myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_eo))
            nst = pmatch.range.upperBound
            
            //              #ifdef __APPLE__
            /* rdar://problem/86536080 */
            if (pmatch.startIndex == pmatch.endIndex) {
/*              if (MB_CUR_MAX > 1) {
                wchar_t wc;
                
                let advance = mbtowc(&wc,
                                     &myParsec.ln.dat[nst],
                                 MB_CUR_MAX);
                
                nst += max(1, advance);
              } else {
 */
              nst = myParsec.ln.dat.index(after: nst)
//              }
            }
            // #endif
          }

          
        } else {
          /* Advance as normal if not */
          myParsec.matches.append(pmatch)
            //          matchidx += 1
            
            // new start
            nst = pmatch.range.upperBound
            // myParsec.ln.dat.index(myParsec.ln.dat.startIndex, offsetBy: Int(pmatch.rm_eo))
            //            #ifdef __APPLE__
            /*
             * rdar://problem/86536080 - if our first match
             * was 0-length, we wouldn't progress past that
             * point.  Incrementing nst here ensures that if
             * no other pattern matches, we'll restart the
             * search at one past the 0-length match and
             * either make progress or end the search.
             */
            if pmatch.output.isEmpty {
              // I'm always using Unicode...
              /*            if (MB_CUR_MAX > 1) {
               var wc : wchar_t
               
               let advance = mbtowc(&wc,
               myParsec.ln.dat[nst],
               MB_CUR_MAX);
               
               nst += max(1, advance);
               } else {
               */
              if nst < myParsec.ln.dat.endIndex {
                nst = myParsec.ln.dat.index(after: nst)
              } else {
                nstdone = true
              }
              //            }
            }
            // #endif
        }
        /* avoid excessive matching - skip further patterns */
        if ((options.color == nil && !options.oflag) || options.qflag || options.lflag ||
            myParsec.matches.count >= MAX_MATCHES) {
          myParsec.lnstart = nst
          lastmatched = false;
          break;
        }
      }
      
      /*
       * Advance to just past the start of the earliest match, try
       * again just in case we still have a chance to match later in
       * the string.
       */
      if (!lastmatched && retry > myParsec.lnstart) {
        st = retry;
        continue;
      }
      
      /* XXX TODO: We will need to keep going, since we're chunky */
      /* One pass if we are not recording matches */
      if (!options.wflag && ((options.color == nil && !options.oflag) || options.qflag || options.lflag || options.Lflag)) {
        break;
      }
      
      /* If we didn't have any matches or REG_NOSUB set */
      if (!lastmatched || ((options.cflags & REG_NOSUB) != 0)) {
        nst = myParsec.ln.dat.endIndex
      }
      
      if (!lastmatched) {
        /* No matches */
        break;
      }
      //        #ifdef __APPLE__
      /* rdar://problem/86536080 */
      assert( /* nst >= myParsec.ln.dat.endIndex || */ nstdone ||  nst > st);
//      assert(nst > st)
      // #else
      //        else if (st == nst && lastmatch.rm_so == lastmatch.rm_eo)
      //                  /* Zero-length match -- advance one more so we don't get stuck */
      //                  nst++;
      // #endif
      
      /* Advance st based on previous matches */
      st = nst;
      myParsec.lnstart = st
    }
    
    /* Reflect the new matchidx in the context */
//    myParsec.matchidx = matchidx;
    return matched;
  }
  
  
  /*
   * Safe malloc() for internal use.
   */
  /*   func grep_malloc(_ size : Int) {
   void *ptr;
   
   if ((ptr = malloc(size)) == NULL)
   err(2, "malloc");
   return (ptr);
   }
   */
  /*
   /*
    * Safe calloc() for internal use.
    */
   void *
   grep_calloc(size_t nmemb, size_t size)
   {
   void *ptr;
   
   if ((ptr = calloc(nmemb, size)) == NULL)
   err(2, "calloc");
   return (ptr);
   }
   
   /*
    * Safe realloc() for internal use.
    */
   void *
   grep_realloc(void *ptr, size_t size)
   {
   
   if ((ptr = realloc(ptr, size)) == NULL)
   err(2, "realloc");
   return (ptr);
   }
   
   /*
    * Safe strdup() for internal use.
    */
   char *
   grep_strdup(const char *str)
   {
   char *ret;
   
   if ((ret = strdup(str)) == NULL)
   err(2, "strdup");
   return (ret);
   }
   */
  
  /*
   * Print an entire line as-is, there are no inline matches to consider. This is
   * used for printing context.
   */
  func grep_printline(_ line : str, _ sep : String) {
    printline_metadata(line, sep);
    print(line.dat, terminator: String(options.fileeol) )
  }
  
  private func printline_metadata(_ line : str, _ sep : String)
  {
    var printsep = false
    if (!options.hflag) {
      if (!options.nullflag) {
        print(line.file, terminator: "")
        printsep = true
      } else {
        print(line.file, terminator: "\0")
      }
    }
    if (options.nflag) {
      if (printsep) {
        print(sep, terminator: "")
      }
      print(line.line_no, terminator: "")
      printsep = true;
    }
    if (options.bflag) {
      if (printsep) {
        print(sep, terminator: "");
      }
      print(line.off + line.boff, terminator: "")
      printsep = true;
    }
    if (printsep) {
      print(sep, terminator: "");
    }
  }
  
  /*
   * Prints a matching line according to the command line options.
   */
  private func printline(_ sep : String) {
    //      size_t a = 0;
    //      size_t i, matchidx;
    //      regmatch_t match;
    
    /* If matchall, everything matches but don't actually print for -o */
    if (options.oflag && options.matchall) {
      return;
    }
    
//    let matchidx = myParsec.matchidx;
    var a = myParsec.lnstart
    
    /* --color and -o */
    if ((options.oflag || options.color != nil) && myParsec.matches.count > 0) {
      /* Only print metadata once per line if --color */
      if (!options.oflag && myParsec.printed == 0) {
        printline_metadata(myParsec.ln, sep);
      }
      for match in myParsec.matches {
        /* Don't output zero length matches */
        if match.output.isEmpty {
          continue;
        }
        /*
         * Metadata is printed on a per-line basis, so every
         * match gets file metadata with the -o flag.
         */
        
        if (options.oflag) {
          myParsec.ln.boff = myParsec.ln.dat.distance(from: myParsec.ln.dat.startIndex, to: match.range.lowerBound) //   match.range.lowerBound
          printline_metadata(myParsec.ln, sep);
        } else {
          let stp = myParsec.ln.dat[a..<match.range.lowerBound]
          print(stp, terminator: "") //  match.rm_so - a, 1, stdout);
        }
        if let color = options.color {
          print("\u{1b}[\(color)m\u{1b}[K", terminator: "")
        }
        let stp = match.output
        print(stp, terminator: "");
        if (options.color != nil) {
          print("\u{1b}[m\u{1b}[K", terminator: "")
        }
        a = match.range.upperBound
        if (options.oflag) {
          print("\n", terminator: "");
        }
         
      }
      if (!options.oflag) {
        if ( a < myParsec.ln.dat.endIndex) {
          print(myParsec.ln.dat[a...], terminator: "")
        }
        print("\n", terminator: "");
      }
    } else {
      grep_printline(myParsec.ln, sep);
    }
    myParsec.printed += 1
  }
  
}


public func encodeLatin1Lossy(_ string: String) -> [UInt8] {
    string.unicodeScalars.map { scalar in
        scalar.value <= 0xFF ? UInt8(scalar.value) : UInt8(ascii: "?")
    }
}
