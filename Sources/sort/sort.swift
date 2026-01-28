
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file with the following notice:

/*-
 * SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 *
 * Copyright (C) 2009 Gabor Kovesdan <gabor@FreeBSD.org>
 * Copyright (C) 2012 Oleg Moskalenko <mom040267@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

import CMigration
import CommonCrypto

@main final class sort : ShellCommand {
  
  var VERSION = "2.3-Apple ( modernized by r0ml )"
  
  
  let MT_SORT_THRESHOLD = 10000
  var ncpu = 1
  var nthreads = 1

  
  
  var usage : String = """
Usage: %s [-bcCdfigMmnrsuz] [-kPOS1[,POS2] ... ]
  [+POS1 [-POS2]] [-S memsize] [-T tmpdir] [-t separator]
  [-o outfile] [--batch-size size] [--files0-from file]
  [--heapsort] [--mergesort] [--radixsort] [--qsort]
  [--mmap]
  [--parallel thread_no]
  [--human-numeric-sort]
  [--version-sort] [--random-sort [--random-source file]]
  [--compress-program program] [file ...]
"""
  
  var mutually_exclusive_flags : [Character] = [ "M", "n", "g", "R", "h", "V"]

  enum SortMethod {
    case SORT_DEFAULT
    case SORT_QSORT
    case SORT_MERGESORT
    case SORT_HEAPSORT
    case SORT_RADIXSORT
  }
  
  
  /*
   * Sort hint data for -n
   */
  struct n_hint {
    var n1 : UInt
    var s1 : UInt8
    var empty = false
    var neg = false
  }
  
  /*
   * Sort hint data for -g
   */
  struct g_hint {
    var d : Double
    var nan = false
    var notnum = false
  }
  
  /*
   * Sort hint data for -M
   */
  struct M_hint {
    var m : Int
  }
  
  /*
   * Sort hint data for -R
   *
   * This stores the first 12 bytes of the digest rather than the full output to
   * avoid increasing the size of the 'key_hint' object via the 'v' union.
   */
  struct R_hint {
    var cached = Array(repeating: UInt8(0), count: 12);
  }
  
  struct key_value {
    var k : String
    var hint : [key_hint]
  }
  
  /*
   * Parsed -k option data
   */
  struct key_spec {
    var sm = SortModifiers()
    var c1 = size_t(0)
    var c2 = size_t(0)
    var f1 = size_t(0)
    var f2 = size_t(0)
    var pos1b = false
    var pos2b = false
  }


  
  enum KHU {
    case nh(n_hint)
    case gh(g_hint)
    case Mh(M_hint)
    case Rh(R_hint)
  }
  
  
  /*
   * Status of a sort hint object
   */
  enum hint_status : Int {
    case HS_ERROR = -1
    case HS_UNINITIALIZED = 0
    case HS_INITIALIZED = 1
  }
  
  
  /*
   * Sort hint object
   */
  struct key_hint {
    var status : hint_status
    var v : KHU
  };
  
  /*
   * Cmp function
   */
  typealias cmpcoll_t = (_ kv1 : key_value, _ kv2 : key_value, _ offset : size_t) -> Int
  
  
  struct SortModifiers {
    var `func` : cmpcoll_t?
    var bflag = false
    var dflag = false
    var fflag = false
    var gflag = false
    var iflag = false
    var Mflag = false
    var nflag = false
    var rflag = false
    var Rflag = false
    var Vflag = false
    var hflag = false
  };
  
  // FIXME: can this go back into CommandOptions?
  var debug_sort = false
  
  struct CommandOptions {
    var field_sep : Character = ","
    var sort_method : SortMethod = .SORT_DEFAULT
    var cflag = false
    var csilentflag = false
    var kflag = false
    var mflag = false
    var sflag = false
    var uflag = false
    var zflag = false
    var tflag = false
    var complex_sort = false
    var need_hint = false
    
//    var debug_sort = false
    var use_mmap = false
    
    var random_source : String?
    var compress_program : String?
    var need_random = false
    
    var outfile : String = "-"
    var real_outfile : String = "-"
    
    var tmpdir : String = "/var/tmp"

    var gnusort_numeric_compatibility = false
    var symbol_decimal_point : Character? = "."
    var symbol_thousands_sep : Character?
    var symbol_negative_sign : Character? = "-"
    var symbol_positive_sign : Character? = "+"
    
    var max_open_files : Int = 16
    var keys : [key_spec] = []
    var defaultSortMods = SortModifiers()
    
//    var sm : SortModifiers = SortModifiers()
    var gnusort_compatible_blanks = false
    var print_symbols_on_debug = false
    
    var inputFiles = [String]()
    
    var byte_sort = false
  }
  
  let longOptions : [CMigration.option] = [
    .init("batch-size", .required_argument),
    .init("buffer-size", .required_argument),
    .init("check", .optional_argument),
    .init("check=silent|quiet", .optional_argument),
    .init("compress-program", .required_argument),
    .init("debug", .no_argument),
    .init("dictionary-order", .no_argument),
    .init("field-separator", .required_argument),
    .init("files0-from", .required_argument),
    .init("general-numeric-sort", .no_argument),
    .init("heapsort", .no_argument),
    .init("help",.no_argument),
    .init("human-numeric-sort", .no_argument),
    .init("ignore-leading-blanks", .no_argument),
    .init("ignore-case", .no_argument),
    .init("ignore-nonprinting", .no_argument),
    .init("key", .required_argument),
    .init("merge", .no_argument),
    .init("mergesort", .no_argument),
    .init("mmap", .no_argument),
    .init("month-sort", .no_argument),
    .init("numeric-sort", .no_argument),
    .init("output", .required_argument),
    .init("parallel", .required_argument),
    .init("qsort", .no_argument),
    .init("radixsort", .no_argument),
    .init("random-sort", .no_argument),
    .init("random-source", .required_argument),
    .init("reverse", .no_argument),
    .init("sort", .required_argument),
    .init("stable", .no_argument),
    .init("temporary-directory",.required_argument),
    .init("unique", .no_argument),
    .init("version", .no_argument),
    .init("version-sort", .no_argument),
    .init("zero-terminated", .no_argument),
  ]
  
  var available_free_memory : UInt = 65536
  var tmp_files = [String]()
  
  func preparse(_ options : inout CommandOptions) {

//    result = 0;
//    real_outfile = NULL;

    if let _ = ProcessInfo.processInfo.environment["GNUSORT_COMPATIBLE_BLANKS"] {
      options.gnusort_compatible_blanks = true
    }

    set_signal_handler()
    set_hw_params()
    set_locale(&options)
    set_tmpdir(&options)
    // FIXME: do I need this?
//    set_sort_opts();

  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    
    var options = CommandOptions()
    preparse(&options)

    let argv = fix_obsolete_keys(CommandLine.arguments)
    let supportedFlags = "bcCdfghik:Mmno:RrsS:t:T:uVz"
    let go = BSDGetopt_long(supportedFlags, longOptions, Array(argv.dropFirst()) )
    
    while let (k, v) = try go.getopt_long() {
      switch k {
        case "c":
          options.cflag = true
          if !v.isEmpty {
            if v == "diagnose-first" {
            }
            else if v != "silent" ||
                      v != "quiet" {
              options.csilentflag = true
            }
            else if !v.isEmpty {
              try unknown(v)
            }
          }
        case "C":
          options.cflag = true
          options.csilentflag = true
        case "k":
          options.complex_sort = true
          options.kflag = true
          
          var ks = key_spec()
          if try !parse_k(v, &ks, &options) {
            throw CmdErr(2, "invalid value: -k \(v)")
          }
          
        case "m":
          options.mflag = true
        case "o":
          options.outfile = v
        case "s":
          options.sflag = true
          break;
        case "S":
          available_free_memory =
          UInt(parse_memory_buffer_value(v))
          
        case "T":
          options.tmpdir = v
        case "t":
          var vv = v
          while vv.count > 1 {
            if (vv.first != "\\") {
              throw CmdErr(2, "invalid value: -t \(v)")
            }
            vv.removeFirst()
            if vv.first == "0" {
              vv = "\0"
              break;
            }
          }
          options.tflag = true;
          options.field_sep = vv.first ?? "\0"
 
          if (!options.gnusort_numeric_compatibility) {
            if (options.symbol_decimal_point == options.field_sep) {
              options.symbol_decimal_point = nil
            }
            if (options.symbol_thousands_sep == options.field_sep) {
              options.symbol_thousands_sep = nil
            }
            if (options.symbol_negative_sign == options.field_sep) {
              options.symbol_negative_sign = nil
            }
            if (options.symbol_positive_sign == options.field_sep) {
              options.symbol_positive_sign = nil
            }
          }
          break;
        case "u":
          options.uflag = true
          /* stable sort for the correct unique val */
          options.sflag = true;
        case "z":
          options.zflag = true
        case "sort":
          var dsm = options.defaultSortMods
          if v.isEmpty {
          } else if v == "general-numeric" {
            set_sort_modifier(&dsm, "g", &options)
          } else if v == "human-numeric" {
            set_sort_modifier(&dsm, "h", &options)
          } else if v == "numeric" {
            set_sort_modifier(&dsm, "n", &options)
          } else if v == "month" {
            set_sort_modifier(&dsm, "M", &options)
          } else if v == "random" {
            set_sort_modifier(&dsm, "R", &options)
          } else {
            try unknown(v)
          }
          options.defaultSortMods = dsm
          
        case "parallel":
          if let nt = Int(v) {
            nthreads = nt
          }
          if nthreads < 1 {
            nthreads = 1
          }
          if nthreads > 1024 {
            nthreads = 1024
          }
        case "qsort":
          options.sort_method = .SORT_QSORT
        case "mergesort":
          options.sort_method = .SORT_MERGESORT
          break;
        case "mmap":
          options.use_mmap = true
        case "heapsort":
          options.sort_method = .SORT_HEAPSORT
        case "radixsort":
          options.sort_method = .SORT_RADIXSORT
        case "random-source":
          options.random_source = v
        case "compress-program":
          options.compress_program = v
        case "files0-from":
          read_fns_from_file0(v)
        case "batch-size":
          errno = 0
          let mof = strtol(v, nil, 10);
          if (errno != 0) {
            err(2, "--batch-size");
          }
          if (mof >= 2) {
            options.max_open_files = mof + 1;
          }
        case "version":
          print(VERSION);
          exit(EXIT_SUCCESS);
        case "debug":
          debug_sort = true
        case "help":
          // FIXME: will this work?
          print(usage)
          throw CmdErr(0)
        default: throw CmdErr(2)
      }
    }
    
    options.inputFiles = go.remaining
    
    //  #ifndef WITHOUT_NLS
    let catalog = catopen("sort", NL_CAT_LOCALE);
    //  #endif
    
    if (options.cflag && options.mflag) {
      throw CmdErr(1, "m:c: mutually exclusive flags")
    }
    
    //  #ifndef WITHOUT_NLS
    catclose(catalog);
    //  #endif
    
    if options.keys.count == 0 {
      var k = key_spec()
      k.c1 = 1
      k.pos1b = options.defaultSortMods.bflag
      k.pos2b = options.defaultSortMods.bflag
      k.sm = options.defaultSortMods
      options.keys.append(k)
    }

    for var (i,ks) in options.keys.enumerated() {
      if sort_modifier_empty(ks.sm) && !ks.pos1b &&
          !ks.pos2b {
        ks.pos1b = options.defaultSortMods.bflag;
        ks.pos2b = options.defaultSortMods.bflag;
      }
      ks.sm.func = get_sort_func(ks.sm)
      options.keys[i] = ks
    }
    
    options.real_outfile = options.outfile
    
    /* Case when the outfile equals one of the input files: */
    if options.outfile != "-" {
      
      for infile in options.inputFiles {
        if infile == options.outfile {
          while true {
            options.outfile = "\(options.outfile).tmp"
            if (access(options.outfile, F_OK) < 0) {
              break;
            }
          }
          // FIXME: at this back in from cleanup at signal
//          tmp_file_atexit(options.outfile);
        }
      }
    }
    
    
    return options
  }
  
  
  func runCommand(_ optionsx: CommandOptions) throws(CmdErr) {
    
    var options = optionsx
    
    if (debug_sort) {
      print("Memory to be used for sorting: \(available_free_memory)")
      
      print("number opf CPUs \(ncpu)")
      
      let ll = Locale.current.collatorIdentifier ?? "??"
//      let ll = String(cString: setlocale(LC_COLLATE, nil))
      print("Using collate rules of \(ll) locale")

      if options.byte_sort {
        print("Byte sort is used")
      }
      if (options.print_symbols_on_debug) {
        if let sdp = options.symbol_decimal_point {
          print("Decimal Point: <\(sdp)>")
        }
        if let sts = options.symbol_thousands_sep {
          print("Thousands separator: <\(sts)>")
        }
        if let sps = options.symbol_positive_sign {
          print("Positive sign: <\(sps)>")
        }
        if let sns = options.symbol_negative_sign {
            print("Negative sign: <\(sns)>")
        }
      }
    }
    
    if options.need_random {
      get_random_seed(options.random_source);
    }
    
    // FIXME: if i'm using a tmpfile for outfile, what happens?
    if options.inputFiles.count < 1 || options.outfile == "-" {
      nthreads = 1
    }

    if (!options.cflag && !options.mflag) {
      var fl = file_list()
      var list = sort_list()
      
      
      if (options.inputFiles.count < 1) {
        procfile("-", &list, &fl);
      }
      else {
        for fn in options.inputFiles {
          procfile(fn, &list, &fl);
        }
      }
      
      if (fl.fns.count < 1) {
        sort_list_to_file(list, options.outfile, &options);
      }
      else {
        if (list.list.count > 0) {
          let flast = new_tmp_file_name(options)
          sort_list_to_file(list, flast, &options)
          fl.fns.append(flast)
        }
        merge_files(&fl, options.outfile);
      }
      
      /*
       * We are about to exit the program, so we can ignore
       * the clean-up for speed
       *
       * sort_list_clean(&list);
       */
      fl.fns = []
      list.list = []

    } else if (options.cflag) {
      fatalError("options.cflag not yet implemented")
      /*
      result = (argc == 0) ? (check("-")) : (check(*argv));
       */
    } else if (options.mflag) {
      fatalError("options.mflag not yet implemented")
      /*
      struct file_list fl;
      
      file_list_init(&fl, false);
      /* No file arguments remaining means "read from stdin." */
      if (argc == 0) {
        fl.fns.append("-")
      }
      else {
        file_list_populate(&fl, argc, argv, true);
      }
      merge_files(&fl, options.outfile);
      file_list_clean(&fl);
    }
    
    if (real_outfile) {
      unlink(real_outfile);
      if (rename(options.outfile, real_outfile) < 0) {
        err(2, NULL);
      }
       */
    }

    //   return (result);
  }
  
  
  
  
  /*
   * Check where sort modifier is present
   */
  func sort_modifier_empty(_ sm : SortModifiers?) -> Bool {
    
    guard let sm else { return true }
    return (!(sm.Mflag || sm.Vflag || sm.nflag || sm.gflag ||
              sm.rflag || sm.Rflag || sm.hflag || sm.dflag || sm.fflag || sm.iflag))
  }
  
  /*
   * Read input file names from a file (file0-from option).
   */
  func read_fns_from_file0(_ fn : String) {
    fatalError("\(#function) not yet implemented")
    /*
    FILE *f;
    char *line = NULL;
    size_t linesize = 0;
    ssize_t linelen;
    
    if (fn == NULL) {
      return;
    }
    
    f = fopen(fn, "r");
    if (f == NULL) {
      err(2, "%s", fn);
    }
    
    while ((linelen = getdelim(&line, &linesize, "\0", f)) != -1) {
      if (*line != "\0") {
        if (argc_from_file0 == (size_t) - 1) {
          argc_from_file0 = 0;
        }
        ++argc_from_file0;
        argv_from_file0 = sort_realloc(argv_from_file0,
                                       argc_from_file0 * sizeof(char *));
        if (argv_from_file0 == NULL) {
          err(2, NULL);
        }
        argv_from_file0[argc_from_file0 - 1] = line;
      } else {
        free(line);
      }
      line = NULL;
      linesize = 0;
    }
    if (ferror(f)) {
      err(2, "%s: getdelim", fn);
    }
    
    closefile(f, fn);
     */
  }
  
  /*
   * Check how much RAM is available for the sort.
   */
  func set_hw_params() {

    ncpu = 1
    var pages = sysconf(_SC_PHYS_PAGES);
    if (pages < 1) {
      perror("sysconf pages");
      pages = 1;
    }
    var psize = sysconf(_SC_PAGESIZE);
    if (psize < 1) {
      perror("sysconf psize");
      psize = 4096;
    }
    
    ncpu = sysconf(_SC_NPROCESSORS_ONLN)
    if (ncpu < 1) {
      ncpu = 1
    }
    else if(ncpu > 32) {
      ncpu = 32
    }

    nthreads = ncpu

    
    let free_memory = pages * psize
    available_free_memory = UInt(free_memory / 2)
    
    if (available_free_memory < 65536) {
      available_free_memory = 65536
    }
  }
  
  /*
   * Convert "plain" symbol to wide symbol, with default value.
   */
  // FIXME: do I need this ?  or does Swift string handling take care of it
  /*
  func conv_mbtowc(wchar_t *wc, const char *c, const wchar_t def) {
    
    if (wc && c) {
      int res;
      
      res = mbtowc(wc, c, MB_CUR_MAX);
      if (res < 1) {
        *wc = def;
      }
    }
  }
  */
  
  /*
   * Set current locale symbols.
   */
  func set_locale(_ options : inout CommandOptions) {
    
    setlocale(LC_ALL, "")
    
    // FIXME: what is all this?
    
    /*
    if var lc = localeconv() {
      /* obtain LC_NUMERIC info */
      /* Convert to wide char form */
      conv_mbtowc(&symbol_decimal_point, lc.decimal_point,
                  symbol_decimal_point);
      conv_mbtowc(&symbol_thousands_sep, lc.thousands_sep,
                  symbol_thousands_sep);
      conv_mbtowc(&symbol_positive_sign, lc.positive_sign,
                  symbol_positive_sign);
      conv_mbtowc(&symbol_negative_sign, lc.negative_sign,
                  symbol_negative_sign);
    }
    */
    
    if let _ = ProcessInfo.processInfo.environment["GNUSORT_NUMERIC_COMPATIBILITY"] {
      options.gnusort_numeric_compatibility = true
    }
    
    if let locale = setlocale(LC_COLLATE, nil) {
       
      let tmpl = locale
      if let cclocale = setlocale(LC_COLLATE, "C"),
         cclocale == tmpl {
        options.byte_sort = true;
      }
      else {
        if let pclocale = setlocale(LC_COLLATE, "POSIX"),
           pclocale == tmpl {
          options.byte_sort = true;
        }
      }
      setlocale(LC_COLLATE, tmpl)
    }
  }
  
  /*
   * Set directory temporary files.
   */
  func set_tmpdir(_ options : inout CommandOptions) {
    if let td = ProcessInfo.processInfo.environment["TMPDIR"] {
      options.tmpdir = td
    }
  }
  
  /*
   * Parse -S option.
   */
  func parse_memory_buffer_value(_ value : String?) -> Int {
    
    guard let value else {
      return Int(available_free_memory)
    }
    
    fatalError("\(#function) not implemented yet")
/*
      char *endptr;

    var membuf : UInt64
      
      endptr = NULL;
      errno = 0;
      membuf = strtoll(value, &endptr, 10);
      
      if (errno != 0) {
        warn("%s",getstr(4));
        membuf = available_free_memory;
      } else {
        switch (*endptr){
          case "Y":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "Z":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "E":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "P":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "T":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "G":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "M":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "\0":
          case "K":
            membuf *= 1024;
            /* FALLTHROUGH */
          case "b":
            break;
          case "%":
            membuf = (available_free_memory * membuf) /
            100;
            break;
          default:
            warnc(EINVAL, "%s", optarg);
            membuf = available_free_memory;
        }
      }
      return (membuf);
 */
  }
  
  /*
   * Signal handler that clears the temporary files.
   */
  func sig_handler(_ sig : Int32, _ siginfo : siginfo_t,
                   _ context : UnsafeRawPointer) {
    
    clear_tmp_files();
    
    /*
     * For conformance purposes, we can't just exit with a single static
     * exit code -- we must actually re-raise the error once we've finished
     * our cleanup to get the signal-exit bits correct.
     */
    signal(sig, SIG_DFL);
    raise(sig);
  }
  
  /*
   * Install the requested action, but *only* if the signal's not currently being
   * ignored.  sort(1) won't ignore anything itself, so this would indicate that
   * the caller is ignoring it for one reason or another and we shouldn't override
   * that just for cleanup purposes.
   */
  func sigaction_notign(_ sig : Int32, _ act : UnsafePointer<sigaction>!, _ poact : UnsafeMutablePointer<sigaction>!) -> Int32 {
    var oact = _signal.sigaction()
    var error : Int32
    
    error = sigaction(sig, nil, &oact)
    if error < 0 {
      return (error);
    }
    
    /* Silently succeed. */
    // FIXME: put this back
    /*
    if (oact.__sigaction_u.__sa_handler == SIG_IGN ) {
      if poact != nil { poact.pointee = oact }
      return 0
    }
     */
    return sigaction(sig, act, poact)
  }
  
  func sigactionx(_ s : Int32, _ a : UnsafePointer<sigaction>!, _ o : UnsafeMutablePointer<sigaction>!) -> Int32 {
    return sigaction_notign(s, a, o)
  }
  
  /*
   * Set signal handler on panic signals.
   */
  func set_signal_handler() {
    var sa = sigaction()
    // FIXME: put this back
//    sa.__sigaction_u.__sa_sigaction = sig_handler
    sa.sa_flags = SA_SIGINFO
    
    if (sigactionx(SIGTERM, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGHUP, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGINT, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGQUIT, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGBUS, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGSEGV, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGUSR1, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
    if (sigaction(SIGUSR2, &sa, nil) < 0) {
      perror("sigaction");
      return;
    }
  }
  
  /*
   * Print "unknown" message and exit with status 2.
   */
  func unknown(_ what : String) throws(CmdErr) {
    throw CmdErr(2, "Unknown feature: \(what)")
  }
  
  /*
   * Check whether contradictory input options are used.
   */
  func check_mutually_exclusive_flags(_ c : Character, _ mef_flags : inout [Bool] ) throws(CmdErr)  {

    var found_others = false
    var found_this = false;
    var fo_index = 0
    
    for (i, _) in mef_flags.enumerated() {
      let mec = mutually_exclusive_flags[i]
      if (mec != c) {
        if mef_flags[i] {
          if (found_this) {
            throw CmdErr(1, "\(c):\(mec): mutually exclusive flags")
          }
          found_others = true;
          fo_index = i;
        }
      } else {
        if (found_others) {
          throw CmdErr(1, "\(c):\(mutually_exclusive_flags[fo_index]): mutually exclusive flags")
        }
        mef_flags[i] = true
        found_this = true
      }
    }
  }
  
  /*
   * Initialise sort opts data.
   */
  /*
  func set_sort_opts() {
    
    memset(&default_sort_mods_object, 0,
           sizeof(default_sort_mods_object));
    memset(&sort_opts_vals, 0, sizeof(sort_opts_vals));
    default_sort_mods_object.func =
    get_sort_func(&default_sort_mods_object);
  }
  */
  
  /*
   * Set a sort modifier on a sort modifiers object.
   */
  func set_sort_modifier(_ sm : inout SortModifiers, _ c : Character, _ options : inout CommandOptions) -> Bool
  {
    switch (c) {
      case "b":
        sm.bflag = true
      case "d":
        sm.dflag = true
      case "f":
        sm.fflag = true
      case "g":
        sm.gflag = true
        options.need_hint = true
      case "i":
        sm.iflag = true
      case "R":
        sm.Rflag = true
        options.need_hint = true
        options.need_random = true
      case "M":
        fatalError("-M not yet implemented")
//        initialise_months()
        sm.Mflag = true
        options.need_hint = true
      case "n":
        sm.nflag = true
        options.need_hint = true
        options.print_symbols_on_debug = true
      case "r":
        sm.rflag = true
      case "V":
        sm.Vflag = true
      case "h":
        sm.hflag = true
        options.need_hint = true
        options.print_symbols_on_debug = true
      default:
        return false
    }
    
    options.complex_sort = true
    
    // FIXME: implement get_sort_func
//    sm.func = get_sort_func(sm)
    return true
  }
  
  /*
   * Parse POS in -k option.
   */
  func parse_pos(_ s : String, _ ks : inout key_spec, _ mef_flags : inout [Bool], _ second : Bool, _ options : inout CommandOptions) throws(CmdErr) -> Bool
  {
    
    let rege = /^([0-9]+)(\.[0-9]+)?([bdfirMngRhV]+)?$/
 
    let pmatch = s.matches(of: rege)
    guard pmatch.count > 0 else { return false }
    let k = pmatch[0]
    
      // This is a way of doing a jump.
      // the construct is repeat { } while false
      // which executes once, but a break within the
      // repeat block jumps to the end.
      
      repeat {
        let f = k.1
        
        if (second) {
          ks.f2 = size_t(f)!
          if ks.f2 == 0 {
            warn("0 field in key specs")
            break
          }
        } else {
          ks.f1 = size_t(f)!
          if (ks.f1 == 0) {
            warn("0 field in key specs")
            break
          }
        }
        
        if let c = k.2 {
          if (second) {
            ks.c2 = size_t(c)!
          } else {
            ks.c1 = size_t(c)!
            if (errno != 0) {
              err(2, "-k");
            }
            if (ks.c1 == 0) {
              warn("0 column in key specs")
              break // was goto end;
            }
          }
        } else {
          if (second) {
            ks.c2 = 0
          }
          else {
            ks.c1 = 1
          }
        }
        
        if let ssa = k.3 {
          for sss in ssa {
            try check_mutually_exclusive_flags(sss, &mef_flags)
            if (sss == "b") {
              if (second) {
                ks.pos2b = true
              } else {
                ks.pos1b = true
              }
            } else if (!set_sort_modifier(&(ks.sm), sss, &options)) {
              break // was goto end;
            }
          }
        }
        return true
      } while false
    return false
  }
  
  /*
   * Parse -k option value.
   */
  func parse_k(_ s : String, _ ks : inout key_spec, _ options : inout CommandOptions) throws(CmdErr) -> Bool {
    var mef_flags = [ false, false, false, false, false, false ]
    
    guard !s.isEmpty else { return false }
    
    let s2 = s.split(separator: ",", maxSplits: 1)
    if s2.count == 1 {
      return try parse_pos(s, &ks, &mef_flags, false, &options)
    }
    
    let pos1 = s2[0]
    if pos1.isEmpty { return false }
    
    guard try parse_pos(String(pos1), &ks, &mef_flags, false, &options) else { return false }
    
    let pos2 = s2[1]
    return try parse_pos(String(pos2), &ks, &mef_flags, true, &options)
  }
  
  /*
   * Parse POS in +POS -POS option.
   */
  func parse_pos_obs(_ s : Substring, _ nf : inout Int, _ nc : inout Int, _ sopts : inout String) -> Bool {

    let rege = /^([0-9]+)(\\.[0-9]+)?([A-Za-z]+)?$/
    if let k = s.matches(of: rege).first {
      let nf = Int(k.1)!
      if let k2 = k.2 {
        let nc = Int(k2.dropFirst())!
      }
      if let k3 = k.3 {
        sopts = String(k3)
      }
      return true
    }
    return false
  }
  
  
  /*
   * "Translate" obsolete +POS1 -POS2 syntax into new -kPOS1,POS2 syntax
   */
  func fix_obsolete_keys(_ args : [String]) -> [String] {
    var argv = [String]()
    var ite = args.makeIterator()
    argv.append(ite.next()!)
    while var arg1 = ite.next() {
      var again = false
      repeat {
        again = false
      if arg1 == "--" {
        /* Following arguments are treated as filenames. */
        break;
        argv.append(arg1)
      }
      
        if arg1.count > 1 && arg1.first == "+" {
          var f1 = 0
          var c1 = 0
          var sopts1 = ""
          if parse_pos_obs(arg1.dropFirst(), &f1, &c1, &sopts1) {
            f1 += 1;
            c1 += 1;
            
            var sopts2 = ""
            var c2 = 0
            var f2 = 0
            
            if let arg2 = ite.next() {
              if arg2.first == "-",
                 parse_pos_obs(arg2.dropFirst(),
                               &f2, &c2, &sopts2) {
                if (c2 > 0) {
                  f2 += 1;
                }
                let sopt = "-k\(f1).\(c1)\(sopts1),\(f2).\(c2)\(sopts2)"
                argv.append(sopt)
                continue
              }
              arg1 = arg2
              again = true
            }
            let sopt = "-k\(f1).\(c1)\(sopts1)"
            argv.append(sopt)
          }
        } else {
          argv.append(arg1)
        }
      } while again
    }
    argv.append(contentsOf: ite.map { $0 })
    return argv
  }
  
  /*
   * Seed random sort
   */
  func get_random_seed(_ random_source : String?) {
    fatalError("\(#function) not yet implemented")
    
    /*
    let randseed = Array(repeating: UInt8(0), count: 32)
    let rsfd : Int32 = -1
    let rd = randseed.count
    
    if (random_source == nil) {
      if (getentropy(&randseed, sizeof(randseed)) < 0) {
        err(Int(EX_SOFTWARE), "getentropy");
      }
    } else {
      
      rsfd = open(random_source, O_RDONLY | O_CLOEXEC);
      if (rsfd < 0) {
        err(Int(EX_NOINPUT), "open: %s", random_source);
      }
      
      if (fstat(rsfd, &fsb) != 0) {
        err(Int(EX_SOFTWARE), "fstat");
      }
      
      if (!S_ISREG(fsb.st_mode) && !S_ISCHR(fsb.st_mode)) {
        err(EX_USAGE,
            "random seed isn't a regular file or /dev/random");
      }
      
      /*
       * Regular files: read up to maximum seed size and explicitly
       * reject longer files.
       */
      if (S_ISREG(fsb.st_mode)) {
        if (fsb.st_size > (off_t)sizeof(randseed)) {
          errx(EX_USAGE, "random seed is too large (%jd >"
               " %zu)!", (intmax_t)fsb.st_size,
               sizeof(randseed));
        }
        else if (fsb.st_size < 1) {
          errx(Int(EX_USAGE), "random seed is too small ("
               "0 bytes)");
        }
        memset(randseed, 0, sizeof(randseed));
        
        rd = read(rsfd, randseed, fsb.st_size);
        if (rd < 0) {
          err(EX_SOFTWARE, "reading random seed file %s",
              random_source);
        }
        if (rd < (ssize_t)fsb.st_size) {
          errx(Int(EX_SOFTWARE), "short read from \(random_source)");
        }
      } else if (S_ISCHR(fsb.st_mode)) {
        if (stat("/dev/random", &rsb) < 0) {
          err(Int(EX_SOFTWARE), "stat");
        }
        
        if (fsb.st_dev != rsb.st_dev ||
            fsb.st_ino != rsb.st_ino) {
          errx(Int(EX_USAGE), "random seed is a character "
               "device other than /dev/random");
        }
        
        if (getentropy(randseed, sizeof(randseed)) < 0) {
          err(Int(EX_SOFTWARE), "getentropy");
        }
      }
    }
    if (rsfd >= 0) {
      close(rsfd)
    }
    
    CC_SHA256_Init(&sha256_ctx)
    CC_SHA256_Update(&sha256_ctx, randseed, rd)
     */
  }
  
}
