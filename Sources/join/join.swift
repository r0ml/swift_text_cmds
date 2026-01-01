
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
 * SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1991, 1993, 1994
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Steve Hayman of the Computer Science Department, Indiana University,
  Michiro Hikida and David Goodenough.
 
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

@main final class join : ShellCommand {

  var usage : String = """
usage: join [-a fileno | -v fileno ] [-e string] [-1 field] [-2 field]
            [-o list] [-t char] file1 file2
"""

  struct CommandOptions {
    var aflag = false
    var vflag = false
    var empty : String? =  nil
    var spans = true
    var joinout = true
    var tabchar : Character = "\t"
    var olist : [(fileno: Int, fieldno: Int)]? = nil
    var F1 = INPUT(fp : FileDescriptor.standardInput, number: 1)
    var F2 = INPUT(fp : FileDescriptor.standardInput, number: 2)
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "\01a:e:j:1:2:o:t:v:"
    let go = BSDGetopt(supportedFlags)

    while let (k, v) = try go.getopt() {
      switch k {
        case "\u{1}":    // See comment in obsolete().
          options.aflag = true
          options.F1.unpair = true
          options.F2.unpair = true
        case "1":
          if let vv = Int(v) {
            if vv < 1 {
              throw CmdErr(1, "-1 option field number less than 1")
            } else {
              options.F1.joinf = vv-1
            }
          } else {
            throw CmdErr(1, "illegal field number -- \(v)")
          }

        case "2":
          if let vv = Int(v) {
            if vv < 1 {
              throw CmdErr(1, "-2 option field number less than 1")
            } else {
              options.F2.joinf = vv-1
            }
          } else {
            throw CmdErr(1, "illegal field number -- \(v)")
          }
        case "a":
          options.aflag = true
          switch(v) {
            case "1":
              options.F1.unpair = true
            case "2":
              options.F2.unpair = true
              break;
            default:
              throw CmdErr(1, "-a option file number not 1 or 2")
          }
        case "e":
          options.empty = v

        case "j":
          if let vv = Int(v) {
            if vv < 1 {
              throw CmdErr(1, "-j option field number less than 1")
            } else {
              options.F1.joinf = vv-1
              options.F2.joinf = vv-1
            }
          } else {
            throw CmdErr(1, "illegal field number -- \(v)")
          }
        case "o":
          options.olist = try fieldarg(v)
        case "t":
          options.spans = false
          if v.count == 1 {
            options.tabchar = v.first!
          } else {
            throw CmdErr(1, "illegal tab character specification")
          }
        case "v":
          options.vflag = true
          options.joinout = false
          switch v {
            case "1":
              options.F1.unpair = true
            case "2":
              options.F2.unpair = true
            default:
              throw CmdErr(1, "-v option file number not 1 or 2")
          }
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }

    if options.aflag && options.vflag {
      throw CmdErr(1, "the -a and -v options are mutually exclusive");
    }

    options.args = go.remaining
    if options.args.count != 2 {
      throw CmdErr(1)
    }
    return options
  }

  func runCommand() async throws(CmdErr) {

    var f1 : FileDescriptor
    var f2 : FileDescriptor

    /* Open the files; "-" means stdin. */
    if options.args[0] == "-" {
      f1 = FileDescriptor.standardInput
    } else {
      do {
        f1 = try FileDescriptor(forReading: options.args[0])
      } catch(let e) {
        throw CmdErr(1, "\(e)")
      }
    }

    if options.args[1] == "-" {
      f2 = FileDescriptor.standardInput
    } else {
      do {
        f2 = try FileDescriptor(forReading: options.args[1])
      } catch(let e) {
        throw CmdErr(1, "\(e)")
      }
    }
    if f2 == FileDescriptor.standardInput && f1 == FileDescriptor.standardInput {
      throw CmdErr(1, "only one input file may be stdin")
    }

    var f2i = f2.bytes.lines.makeAsyncIterator()
    var f1i = f1.bytes.lines.makeAsyncIterator()

    var prev1 : [Substring]?
    var prev2 : [Substring]?

    do {
      repeat {
        prev1 = try await f1i.next()?.split(separator: options.tabchar, omittingEmptySubsequences: false)
      } while (prev1 != nil && prev1!.count <= options.F1.joinf)
                repeat {
        prev2 = try await f2i.next()?.split(separator: options.tabchar, omittingEmptySubsequences: false)
      } while (prev2 != nil && prev2!.count <= options.F2.joinf)
    } catch(let e) {
      throw CmdErr(1, "reading input file: \(e)")
    }

//    if prev1 == nil || prev2 == nil { return }

    // This version assumes that both files are sorted on the join field and does a merge
    var f1l = try await slurp(&f1i, delimiter: options.tabchar, keyfield: options.F1.joinf, nextline: &prev1)
    var f2l = try await slurp(&f2i, delimiter: options.tabchar, keyfield: options.F2.joinf, nextline: &prev2)

    while true {
      let f1k = f1l.isEmpty ? nil : f1l[0][options.F1.joinf]
      let f2k = f2l.isEmpty ? nil : f2l[0][options.F2.joinf]

      guard f1k != nil || f2k != nil else { break }
      
      if let f1k, let f2k, f1k == f2k {
        if options.joinout {
          try joinlines(f1l, f2l)
        }
        f1l = try await slurp(&f1i, delimiter: options.tabchar, keyfield: options.F1.joinf, nextline: &prev1)
        f2l = try await slurp(&f2i, delimiter: options.tabchar, keyfield: options.F2.joinf, nextline: &prev2)
      } else if let f1k, f2k == nil || f1k < f2k! {
        if options.F1.unpair {
          try joinlines(f1l, nil)
        }
        f1l = try await slurp(&f1i, delimiter: options.tabchar, keyfield: options.F1.joinf, nextline: &prev1)
      } else {
        if options.F2.unpair {
          try joinlines(nil, f2l)
        }
        f2l = try await slurp(&f2i, delimiter: options.tabchar, keyfield: options.F2.joinf, nextline: &prev2)
      }
      /*
      if prev1 == nil && prev2 == nil {
        try joinlines(f1l, f2l, options: options)
        break
      }
       */
    }
  }

  /*
   * There's a structure per input file which encapsulates the state of the
   * file.  We repeatedly read lines from each file until we've read in all
   * the consecutive lines from the file with a common join field.  Then we
   * compare the set of lines with an equivalent set from the other file.
   */
  struct LINE {
    var line : String
    var fields : [Substring]   // line field(s)
                               //  u_long fieldcnt;  /* line field(s) count */
                               //  u_long fieldalloc;  /* line field(s) allocated count */
  }

  struct INPUT {
    var fp : FileDescriptor
    var joinf : Int = 0        // join field (-1, -2, -j)
    var unpair = false          // output unpairable lines (-a)
    var number : UInt           // 1 for file 1, 2 for file 2

    var set : [LINE] = []       // set of lines with same field
    var pushbool : Bool = false // if pushback is set
    var pushback : Int = 0     // line on the stack
    var setcnt : Int = 0       // set count
  }

  /// Read all of the lines from an input file that have the same join field.
  func slurp(_ F : inout AsyncLineReader.AsyncIterator, delimiter: Character, keyfield joinf: Int, nextline lastlp : inout [Substring]?) async throws(CmdErr) -> [[Substring]] {
    var res = [[Substring]]()
    guard let lastk = lastlp?[joinf] else { return res }
    while true {
      do {
        let fields = lastlp!
        if fields.count > joinf { // && !fields[joinf].isEmpty {
          if fields[joinf] == lastk {
            res.append(fields)
          } else {
            lastlp = fields
            return res
          }
        }
        lastlp = try await F.next()?.split(separator: delimiter, omittingEmptySubsequences: false)
        if lastlp == nil {
          return res
        }
      } catch(let e) {
        throw CmdErr(1, "\(e)")
      }
    }
  }

  func joinlines(_ F1 : [[Substring]]?, _ F2 : [[Substring]]? ) throws(CmdErr) {

    /*
     * Output the results of a join comparison.  The output may be from
     * either file 1 or file 2 (in which case the first argument is the
     * file from which to output) or from both.
     */
    if F2 == nil {
      F1!.forEach{ outoneline(1, $0) }
    } else if F1 == nil {
      F2!.forEach { outoneline(2, $0) }
    } else {
      for f1 in F1! {
        for f2 in F2! {
          outtwolines(f1, f2)
        }
      }
    }
  }

  func outoneline(_ number : Int, _ line : [Substring]) {
    /*
     * Output a single line from one of the files, according to the
     * join rules.  This happens when we are writing unmatched single
     * lines.  Output empty fields in the right places.
     */
    if let olist = options.olist {
      var needsep = false
      for ol in olist {
        if ol.fileno == number {
          outfield(line, ol.fieldno-1, false, needsep)
        }
        else if ol.fileno == 0 {
          outfield(line, number == 1 ? options.F1.joinf : options.F2.joinf, false, needsep)
        } else {
          outfield(line, 0, true, needsep)
        }
        needsep = true
      }
    } else {
      /*
       * Output the join field, then the remaining fields.
       */
      outfield(line, number == 1 ? options.F1.joinf : options.F2.joinf, false, false)
      for i in 0..<line.count {
        if (number == 1 ? options.F1.joinf : options.F2.joinf) != i {
          outfield(line, i, false, true)
        }
      }
    }
    print("")
  }

  func outtwolines(_ line1 : [Substring], _ line2 : [Substring]) {
    /* Output a pair of lines according to the join list (if any). */
    if let olist = options.olist {
      var needsep = false
      for ol in olist {
        if ol.fileno == 0 {
          if line1.count > options.F1.joinf {
            outfield(line1, options.F1.joinf, false, needsep)
            needsep = true
          }
          else {
            outfield(line2, options.F2.joinf, false, needsep)
            needsep = true
          }
        } else if ol.fileno == 1 {
          outfield(line1, ol.fieldno-1, false, needsep)
          needsep = true
        }
        else { /* if (olist[cnt].filenum == 2) */
          outfield(line2, ol.fieldno-1, false, needsep)
        }
      }
    } else {
      /*
       * Output the join field, then the remaining fields from F1
       * and F2.
       */
      outfield(line1, options.F1.joinf, false, false)
      for i in 0..<line1.count {
        if options.F1.joinf != i {
          outfield(line1, i, false, true)
        }
      }
      for i in 0..<line2.count {
        if options.F2.joinf != i {
          outfield(line2, i, false, true)
        }
      }
    }
    print("")
  }

  func outfield(_ line : [Substring], _ fieldno : Int, _ out_empty : Bool, _ needsep : Bool) {
    if needsep { print(options.tabchar, terminator: "") }
    if line.count <= fieldno || out_empty {
      if let empty = options.empty  {
        print( empty, terminator: "")
      }
    } else {
      if line[fieldno].isEmpty {
        if /* unix2003_compat && */ let empty = options.empty {
          print(empty, terminator: "")
        } else {
          return
        }
      } else {
        print(line[fieldno], terminator: "")
      }
    }
  }


  /// Convert an output list argument "2.1, 1.3, 2.4" into an array of output fields.
  func fieldarg(_ option : String) throws(CmdErr) -> [(Int, Int)] {
    var fieldno : Int
    var filenum : Int
    var olist : [(fileno: Int, fieldno: Int)] = []

    let fs = option.split(omittingEmptySubsequences: true, whereSeparator: { d in ", \t".contains(d) } )
    for token in fs {
      if token.first == "0" {
        filenum = 0
        fieldno = 0
      }
      else if token.hasPrefix("1.") || token.hasPrefix("2.") {
        filenum = token.first == "1" ? 1 : 2
        if let fn = Int(token.dropFirst(2)) {
          fieldno = fn
        } else {
          throw CmdErr(1, "malformed -o option field: \(token.dropFirst(2))")
        }
        if fieldno == 0 {
          throw CmdErr(1, "field numbers are 1 based")
        }
      } else {
        throw CmdErr(1, "malformed -o option field: \(token)")
      }
      olist.append((fileno: filenum, fieldno: fieldno))
    }

    return olist
  }

    /*
     static void
     obsolete(char **argv)
     {
     size_t len;
     char **p, *ap, *t;

     while ((ap = *++argv) != NULL) {
     /* Return if "--". */
     if (ap[0] == '-' && ap[1] == '-')
     return;
     /* skip if not an option */
     if (ap[0] != '-')
     continue;
     switch (ap[1]) {
     case 'a':
     /*
      * The original join allowed "-a", which meant the
      * same as -a1 plus -a2.  POSIX 1003.2, Draft 11.2
      * only specifies this as "-a 1" and "a -2", so we
      * have to use another option flag, one that is
      * unlikely to ever be used or accidentally entered
      * on the command line.  (Well, we could reallocate
      * the argv array, but that hardly seems worthwhile.)
      */
     if (ap[2] == '\0' && (argv[1] == NULL ||
     (strcmp(argv[1], "1") != 0 &&
     strcmp(argv[1], "2") != 0))) {
     ap[1] = '\01';
     warnx("-a option used without an argument; "
     "reverting to historical behavior");
     }
     break;
     case 'j':
     /*
      * The original join allowed "-j[12] arg" and "-j arg".
      * Convert the former to "-[12] arg".  Don't convert
      * the latter since getopt(3) can handle it.
      */
     switch(ap[2]) {
     case '1':
     if (ap[3] != '\0')
     goto jbad;
     ap[1] = '1';
     ap[2] = '\0';
     break;
     case '2':
     if (ap[3] != '\0')
     goto jbad;
     ap[1] = '2';
     ap[2] = '\0';
     break;
     case '\0':
     break;
     default:
     jbad:        errx(1, "illegal option -- %s", ap);
     usage();
     }
     break;
     case 'o':
     /*
      * The original join allowed "-o arg arg".
      * Convert to "-o arg -o arg".
      */
     if (ap[2] != '\0')
     break;
     for (p = argv + 2; *p; ++p) {
     if (p[0][0] == '0' || ((p[0][0] != '1' &&
     p[0][0] != '2') || p[0][1] != '.'))
     break;
     len = strlen(*p);
     if (len - 2 != strspn(*p + 2, "0123456789"))
     break;
     if ((t = malloc(len + 3)) == NULL)
     err(1, NULL);
     t[0] = '-';
     t[1] = 'o';
     memmove(t + 2, *p, len + 1);
     *p = t;
     }
     argv = p - 1;
     break;
     }
     }
     }

     */
  }
