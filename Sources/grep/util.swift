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

import Darwin

class grepDoer {

  var file_err = false
  var first_match = true
  var options : grep.CommandOptions
  var mcount : Int
  var queue : [str] = []
  var myParsec : parsec!
  var myMprintc : mprintc!
  
  let MAX_MATCHES = 32000

  init(_ options: grep.CommandOptions) {
    self.options = options
    self.mcount = options.mcount
  }
  
  
  /// Parsing context; used to hold things like matches made and other useful bits
  struct parsec {
    var matches : [Regex<AnyRegexOutput>.Match] =  [] /* Matches made */
    /* XXX TODO: This should be a chunk, not a line */
    var ln : str                 // Current line
    var f : file                 // Underlying file
    var lnstart : String.Index   // Position in line */
    var printed : Int = 0        // Metadata printed?
    var binary : Bool = false    // Binary file?
    var cntlines : Bool = false  // Count lines?

    init(f: file) {
      self.f = f
      self.ln = str(file: f.name)
      self.lnstart = ln.dat.startIndex
    }
  };

  struct str {
    var boff : Int = 0
    var off : Int = -1
    // FIXME: maybe Data?
    var dat : String = ""
    var file : String
    var line_no : Int = 0
  }

  /// Match printing context
  struct mprintc {
    var tail : Int = 0             // Number of trailing lines to record
    var last_outed : Int = 0       // Number of lines since last output
    var doctx : Bool = false       // Printing context?
    var printmatch : Bool = false  // Printing matches?
    var same_file : Bool = false   // Same file as previously printed?
  };

  func file_matching(_ fname : String) -> Bool {
    var ret = options.finclude ? false : true
    
    let fname_base = fname.withCString {
      let a = UnsafeMutablePointer<CChar>(mutating: $0)
      return String(cString: Darwin.basename(a))
    }
    
    for fp in options.fpatterns {
      if (Darwin.fnmatch(fp.pat, fname, 0) == 0 ||
          Darwin.fnmatch(fp.pat, fname_base, 0) == 0) {
        // The last pattern matched wins exclusion/inclusion rights,
        // so we can't reasonably bail out early here.
        ret = fp.mode != grep.PAT.EXCL
      }
    }
    return ret
  }
  
  func dir_matching(_ dname : String?) -> Bool {
    var ret = options.dinclude ? false : true;
    
    for ii in options.dpatterns {
      if let dname, 0 == Darwin.fnmatch(ii.pat, dname, 0) {
        // The last pattern matched wins exclusion/inclusion rights,
        // so we can't reasonably bail out early here.
        ret = ii.mode != .EXCL
      }
    }
    return ret
  }
  
  
  /// Processes a directory when a recursive search is performed with
  /// the -R option.  Each appropriate file is passed to procfile().
  func grep_tree(_ argv : [String]) throws(CmdErr) -> Bool {
    var matched = false;
    var fts_flags : Int32 = FTS_NOCHDIR;
    
    // This switch effectively initializes 'fts_flags'
    switch options.linkbehave {
      case .EXPLICIT:
        fts_flags |= FTS_COMFOLLOW | FTS_PHYSICAL

      case .DEFAULT, .SKIP:
        fts_flags |= FTS_PHYSICAL
      default:
        fts_flags |= FTS_LOGICAL | FTS_NOSTAT
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
          // Print a warning for recursive directory loop
          warnx("warning: \(String(cString: p.pointee.fts_path)): recursive directory loop")
          break
          // #ifdef __APPLE__
        case FTS_SL:
          /*
           * If we see a symlink, it's because a linkbehave has
           * been specified that should be skipping them; do so
           * silently.
           */
          break
        case FTS_SLNONE:
          /*
           * We should not complain about broken symlinks if
           * we would skip it anyways.  Notably, if skip was
           * specified or we're observing a broken symlink past
           * the root.
           */
          if options.linkbehave == .SKIP ||
              (options.linkbehave == .EXPLICIT && p.pointee.fts_level > FTS_ROOTLEVEL) {
            break
          }
          fallthrough
          // #endif
        default:
          // Check for file exclusion/inclusion
          var ok = true
          if (options.fexclude || options.finclude) {
            ok = ok && file_matching(String(cString: p.pointee.fts_path))
          }
          
          if ok {
            if try procfile(String(cString: p.pointee.fts_path),
                            (fts_flags & FTS_NOSTAT) != 0 ? nil : p.pointee.fts_statp.pointee) {
              matched = true;
            }
          }
          break
      }
    }
    if (errno != 0) {
      err(2, "fts_read")
    }
    
    fts_close(fts)
    return matched
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
    
    // Print the matching line, but only if not quiet/binary
    if myMprintc.printmatch {
      printline(":")

      /*
      while (myParsec.matches.count >= MAX_MATCHES) {
        // Reset matchidx and try again
        myParsec.matches = []
        if try procline() == !options.vflag {
          printline(":")
        } else {
          break
        }
      }
       */
      
      first_match = false
      myMprintc.same_file = true
      myMprintc.last_outed = 0
    }
  }
  
  func procmatch_nomatch() {
    // Deal with any -A context as needed
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
  
  /// Process any matches in the current parsing context, return a boolean
  /// indicating whether we should halt any further processing or not. 'true' to
  /// continue processing, 'false' to halt.
  func procmatches(_ matched : Bool) throws(CmdErr) -> Bool {
    
    if options.mflag && mcount <= 0 {
       // We already hit our match count, but we need to keep dumping
       // lines until we've lost our tail.
      grep_printline(myParsec.ln, "-")
      myMprintc.tail -= 1
      return (myMprintc.tail != 0)
    }
    
    /*
     * XXX TODO: This should loop over pc->matches and handle things on a
     * line-by-line basis, setting up a `struct str` as needed.
     */
    // Deal with any -B context or context separators
    if matched {
      try procmatch_match()
      
      // Count the matches if we have a match limit
      if options.mflag {
        /* XXX TODO: Decrement by number of matched lines */
        mcount -= 1
        if mcount <= 0 {
          return myMprintc.tail != 0
        }
      }
    } else if myMprintc.doctx {
      procmatch_nomatch()
    }
    return true
  }
  
  /// Opens a file and processes it.  Each file is processed line-by-line
  /// passing the lines to procline().
  func procfile( _ fnx : String, _ psbp : stat?) throws(CmdErr) -> Bool {
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
          // Check if we need to process the file
          let s = sbp.st_mode & S_IFMT
          if options.dirbehave == .SKIP && s == S_IFDIR {
            return false
          }
          if options.devbehave == .SKIP &&
              (s == S_IFIFO || s == S_IFCHR || s == S_IFBLK || s == S_IFSOCK) {
            return false
          }
        }
      }
      f = file(fn, options.filebehave, options.fileeol, options.binbehave)
    }
    guard let f else {
      file_err = true
      if !options.sflag {
        warn(fn)
      }
      return false
    }
    
    myParsec = parsec(f: f)
    myMprintc = mprintc()

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
    myParsec.cntlines = false
    myMprintc = mprintc()
    myMprintc.printmatch = true

    if (myParsec.binary && options.binbehave == .BIN)
        || options.cflag || options.qflag || options.lflag || options.Lflag {
      myMprintc.printmatch = false
    }
    if myMprintc.printmatch && (options.Aflag != 0 || options.Bflag != 0) {
      myMprintc.doctx = true
    }
    if myMprintc.printmatch && (options.Aflag != 0 || options.Bflag != 0 || options.mflag || options.nflag) {
      myParsec.cntlines = true
    }
    let mcount = options.mcount
    
    var lines = 0
    while lines == 0 || !(options.lflag || options.qflag) {
      /*
       * XXX TODO: We need to revisit this in a chunking world. We're
       * not going to be doing per-line statistics because of the
       * overhead involved. procmatches can figure that stuff out as
       * needed. */
      // Reset per-line statistics
      myParsec.printed = 0
      myParsec.matches = []
      myParsec.lnstart = myParsec.ln.dat.startIndex
      myParsec.ln.boff = 0
      myParsec.ln.off += myParsec.ln.dat.count + 1
      
      /* XXX TODO: Grab a chunk */
      if let pld = f.grep_fgetln(&myParsec, options) {
        myParsec.ln.dat = pld
        if pld.isEmpty { break }
      } else {
        break
      }
      
      if myParsec.ln.dat.count > 0 && myParsec.ln.dat.last == options.fileeol {
        myParsec.ln.dat.removeLast()
      }
      myParsec.ln.line_no += 1
      
      // Return if we need to skip a binary file
      if myParsec.binary && options.binbehave == .SKIP {
        f.grep_close()
        return false
      }
      
      if options.mflag && mcount <= 0 {
        /*
         * Short-circuit, already hit match count and now we're
         * just picking up any remaining pieces.
         */
        if try !procmatches(false) {
          break
        }
        continue
      }
      let line_matched = try procline() == !options.vflag
      if line_matched {
        lines += 1
      }
      
      // Halt processing if we hit our match limit
      if try !procmatches(line_matched) {
        break
      }
    }
    
    if options.Bflag > 0 {
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
    if options.cflag && !options.qflag {
      // #else
      //      if (cflag) {
      // #endif
      if !options.hflag {
        print("\(myParsec.ln.file):", terminator: "")
      }
      print("\(lines)")
    }
    if options.lflag && !options.qflag && lines != 0 {
      print(fn, terminator: options.nullflag ? "" : "\n")
    }
    if options.Lflag && !options.qflag && lines == 0 {
      print(fn, terminator: options.nullflag ? "" : "\n")
    }
    if lines != 0 && !options.cflag && !options.lflag
        && !options.Lflag && options.binbehave == .BIN && f.binary && !options.qflag {
      print("Binary file \(fn) matches")
    }
    return lines != 0
  }

  /// Processes a line comparing it with the specified patterns.  Each pattern
  /// is looped to be compared along with the full string, saving each and every
  /// match, which is necessary to colorize the output and to count the
  /// matches.  The matching lines are passed to printline() to display the
  /// appropriate output.
  func procline() throws(CmdErr) -> Bool {
    // Null pattern shortcuts.
    if options.matchall {
      if options.xflag && myParsec.ln.dat.count == 0 {
        // Matches empty lines (-x).
        return true
      } else if !options.wflag && !options.xflag {
        // Matches every line (no -w or -x).
        return true
      }
      
      // If we only have the NULL pattern, whether we match or not
      // depends on if we got here with -w or -x.  If either is set,
      // the answer is no.  If we have other patterns, we'll defer
      // to them.
      if options.patterns.count == 0 {
        return !(options.wflag || options.xflag)
      }
    } else if options.patterns.count == 0 {
      // Pattern file with no patterns.
      return false
    }
    
//    var lastmatch : Regex<AnyRegexOutput>.Match?

    // *** this was used to deal with matching in the middle of the string (for -o and the like)
    // var leflags = options.eflags

    // var retry : String.Index = myParsec.ln.dat.startIndex

    // Loop to process the whole line
    // the outer loop is to find multiple matches on the same line
    // the inner loop is to search multiple patterns at the same spot.
    // If using the Regex `matches` method, I will get all the matches for a single pattern.
    // But as I advance through the line, I want to get matches for other patterns which might
    // come earlier or be longer than this one (and overlap).
    // The original code uses REG_STARTEND and REG_NOTBOL to search a partial substring.
    // this won't work for Regex, because there is no way to ask it to ignore a match on '^' or '$'
    // (which is meant to apply to the original string) whilst searching a substring.
    // Regex has `anchorsMatchLineEndings` -- but the original code wants to *not* match on ^ once I've advanced,
    // but still wants to match on '$'
    // Also, can use `wholeMatch` for -x
    // One possibility is to create a single Regex that uses captures for each of the original patterns -- and then
    // sort out the results.
    // The other possibility is to cache all the matches for each pattern -- and then sort out the overlaps -- which is
    // the same thing without the complication of creating a combined pattern.

    // If I know ahead of time that I'm only getting one match per line, I can use firstMatch, otherwise, I use matches

    // One pass if we are not recording matches
    if ((options.color == nil && !options.oflag) || options.qflag || options.lflag || options.Lflag || options.xflag) {

      // Loop to compare with all the patterns -- looking for any match (not all matches)
      for pati in options.regexes {
        var pmatch : Regex<AnyRegexOutput>.Match?
        do {
          pmatch = try options.xflag ? pati.wholeMatch(in: myParsec.ln.dat) : pati.firstMatch(in: myParsec.ln.dat)
        } catch(let e) {
          throw CmdErr(2, "\(e)")
        }
        // no hit for this pattern
        guard let pmatch, pmatch.count > 0 else { continue }

//        if options.xflag {
//          guard pmatch[0].range == myParsec.ln.dat.startIndex..<myParsec.ln.dat.endIndex else { continue}
//        }

        // Check for whole word match
        if options.wflag {
          let ppmatch = pmatch[0]
          // don't match a word (-w) if the match is empty
          if ppmatch.substring == nil || ppmatch.substring!.isEmpty {
            continue
          }
        }
        myParsec.matches = [pmatch]
        return true
      }
      return false
    }





    var allmatches = options.regexes.map { (pati) -> [Regex<AnyRegexOutput>.Match] in
        let mm = myParsec.ln.dat.matches(of: pati)
      var mmx = [Regex<AnyRegexOutput>.Match]()
        if options.wflag {
          mmx = mm.filter { m in m[0].substring != nil && !m[0].substring!.isEmpty }
        } else {
          mmx = mm
        }
      guard mmx.count <= MAX_MATCHES else { return Array(mmx[0..<MAX_MATCHES]) }
      return mmx
    }

    // Now I have all matches for all patterns.
    // Starting at the beginning of the input string, find the first startIndex with a match -- and then the longest
    // match at that index.
    // Then, advance past the end of that match, and find the next first startIndex....


    var st : String.Index = myParsec.lnstart
    var nstdone = false



    while (!nstdone) && st <= myParsec.ln.dat.endIndex {

      // I'm assuming that the matches in each Regex result are ordered in ascending order by start position
      let nx = allmatches.reduce( (myParsec.ln.dat.endIndex, Int(-1), nil as Regex<AnyRegexOutput>.Match? ) ) { (ost : (String.Index, Int, Regex<AnyRegexOutput>.Match?), pati) in
        // as an optimization, I could remove the matches that are before my current position
        if let k = pati.first(where: {$0.range.lowerBound >= st }) {
          if let rl = k.output[0].range?.lowerBound,
             let sc = k.output[0].substring?.count,
             rl < ost.0 || (rl == ost.0 && sc > ost.1) {
            return (rl, sc, k)
          } else {
            return ost
          }
        }
        return ost
      }

      // So now I have the next match
      if let m = nx.2 {
        myParsec.matches.append(m)
        if myParsec.matches.count >= MAX_MATCHES {
          nstdone = true
          break
        }
        st = m.range.upperBound
        if st >= myParsec.ln.dat.endIndex {
          nstdone = true
          break
        } else {
          if m.output[0].substring!.isEmpty {
            st = myParsec.ln.dat.index(after: st)
          }
        }
      } else {
        nstdone = true
        break
      }
    }
    return !myParsec.matches.isEmpty
  }

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
        if match.output[0].substring == nil || match.output[0].substring!.isEmpty {
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
        
        let stp = myParsec.ln.dat[match.output[0].range!]
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
