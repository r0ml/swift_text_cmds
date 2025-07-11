
// Generated by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

/*
   Copyright (c) 2008, 2009 The NetBSD Foundation, Inc.
   All rights reserved.
 
   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:
   1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
   THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
   BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
   POSSIBILITY OF SUCH DAMAGE.
 */

import ShellTesting

@Suite(.serialized) struct grepTest : ShellTest {
  
  var cmd = "grep"
  let suiteBundle = "text_cmds_grepTest"
  
  @Test("Checks basic functionality") func basic() async throws {
    let inp = ((1...10000).map { String($0)+"\n" }).joined()
    let expected = try fileContents("d_basic.out")
    try await run(withStdin: inp, output: expected, args: "123")
  }
  
  @Test("Checks handling of binary files") func binary() async throws {
    let tf = try tmpfile("test.file", "\0foobar")
    let expected = try fileContents("d_binary.out")
    try await run(output: expected, args: "foobar", tf)
    rm(tf)
  }
  
  @Test("Checks recursive searching") func recurse() async throws {
    _ = try tmpfile("recurse/d/fish", "cod\ndover sole\nhaddock\nhalibut\npilchard\n")
    _ = try tmpfile("recurse/a/f/favourite-fish", "cod\nhaddock\nplaice\n")
    let expected = try fileContents("d_recurse.out")
    
    try await run(output: expected, args: "-r", "haddock", "recurse")
    
    rm( FileManager.default.temporaryDirectory.appending(path: "recurse", directoryHint: .isDirectory))
  }
  
  @Test("Checks symbolic link recursion") func recurse_symlink() async throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "test", directoryHint: .isDirectory)
    rm(dir)
    let _ = try tmpfile("test/c/match", "Test string\n")
    let f2 = FileManager.default.temporaryDirectory.appending(path: "test/c/d")
    try FileManager.default.createDirectory(at: f2, withIntermediateDirectories: true)
    
    rm(f2.appending(path: "d", directoryHint: .isDirectory))
    try FileManager.default.createSymbolicLink(at: f2.appending(path: "d", directoryHint: .isDirectory), withDestinationURL: f2)
    
    let expected = try fileContents("d_recurse_symlink.out")
    let exp2 = try fileContents("d_recurse_symlink.err")
    let (r, j, e) = try await ShellProcess(cmd, "-rS", "string", "test").run()
    #expect(r == 0)
    #expect( j == expected)
    #expect( e == exp2)
    rm(dir)
  }
  
  @Test("Checks word-regexps-1") func word_regexps1() async throws {
    let inf = try inFile("d_input")
    let expected = try fileContents("d_word_regexps.out")
    try await run(output: expected, args: "-w", "separated", inf)
  }

  @Test("Checks word-regexps-2") func word_regexps2() async throws {
    try await run(withStdin: "xmatch pmatch\n", output: "pmatch\n", args: "-Eow", "(match )?pmatch")
  }

  @Test("Checks handling of line beginnings and ends") func begin_end() async throws {
    let inf = try inFile("d_input")
    let expected = try fileContents("d_begin_end_a.out")
    try await run(output: expected, args: "^Front", inf)
    
    let expected2 = try fileContents("d_begin_end_b.out")
    try await run(output: expected2, args: "ending$", inf)
  }
  
  @Test("Checks ignore case option") func ignore_case() async throws {
    let inf = try inFile("d_input")
    let expected = try fileContents("d_ignore_case.out")
    try await run(output: expected, args: "-i", "Upper", inf)
  }
  
  @Test("Checks selecting non-matching lines with -v option") func invert() async throws {
    let inf = try inFile("d_invert.in")
    let expected = try fileContents("d_invert.out")
    try await run(output: expected, args: "-v", "fish", inf)
  }
  
  @Test("Checks whole line matching with -x flag") func whole_line() async throws {
    let inf = try inFile("d_input")
    let expected = try fileContents("d_whole_line.out")
    try await run(output: expected, args: "-x", "matchme", inf)
  }
  
  @Test("Checks handling of files with no matches") func negative() async throws {
    let inf = try inFile("d_input")
    try await run(status: 1, args: "not even remotely possible", inf)
  }
  
  @Test("Checks displaying context with -A, -B and -C flags",
        arguments: [
          ("a", "-C2", "bamboo"),
          ("b", "-A3", "tilt"),
          ("c", "-B4", "Whig"),
        ]) func context(_ ex : String, _ opt : String, _ srch : String) async throws {
    let dd = try geturl()
    let inf = URL(fileURLWithPath: "d_context_a.in", relativeTo: dd)
    
    let expected = try fileContents("d_context_\(ex).out")
    try await run(output: expected, args: opt, srch, inf)
    
    let expected2 = try fileContents("d_context_\(ex).out")
    try await run(output: expected2, args: opt, srch, inf)
    
    let expected3 = try fileContents("d_context_\(ex).out")
    try await run(output: expected3, args: opt, srch, inf)
  }
  
  @Test("More checks displaying context with -A, -B and -C flags") func context3() async throws {
    // this command needs to be run from the directory containing the input files
    let dd = try geturl()
    let inf = URL(fileURLWithPath: "d_context_a.in", relativeTo: dd)
    let inf2 = URL(filePath: "d_context_b.in", relativeTo: dd)
    
    let expected4 =  try fileContents("d_context_d.out")
    try await run(output: expected4, args: "-C1", "pig", inf, inf2, cd: dd)
  }
    
    
    @Test("Even more checks displaying context with -A, -B and -C flags",
          arguments: [
            ("e", "-E", "-C1", "(banana|monkey)"),
            ("f", "-Ev", "-B2", "(banana|monkey|fruit)"),
            ("g", "-Ev", "-A1", "(banana|monkey|fruit)"),
          ]) func context4( _ ex : String, _ ev : String, _ opt : String, _ exp : String) async throws {
    let inf5 = try inFile("d_context_e.in")
    let expected5 = try fileContents("d_context_\(ex).out")
    try await run(output: expected5, args: ev, opt, exp, inf5)
  }
  
  @Test("Checks reading expressions from file") func file_exp() async throws {
    let inf = try inFile("d_file_exp.in")
    let expected = try fileContents("d_file_exp.out")
    let inp = stride(from: -1, to: 1, by: 0.1).map { String(format: "%.2lf",$0)+"\n" }
    try await run(withStdin: inp.joined(), output: expected, args: "-f", inf)
  }
  
  @Test("Checks matching special characters with egrep") func egrep() async throws {
    let inf = try inFile("d_input")
    let expected = try fileContents("d_egrep.out")
    try await run(output: expected, args: "-E", "\\?|\\*$$", inf)
  }
  
  @Test("Checks handling of gzipped files with zgrep") func zgrep() async throws {
    let inf = try inFile("d_input.gz")
    let expected = try fileContents("d_zgrep.out")
    try await run(output: expected, args: "-Z", "-h", "line", inf)
  }
  
  @Test("Checks for zgrep wrapper problems with combined flags (PR 247126)"
        //        , .disabled("On macOS, zgrep is not a wrapper script")
  ) func zgrep_combined_flags() async throws {
    let inf = try tmpfile("test3", "foo bar\n")
    
    try await run(output: "foo bar\n", args: "-Z", "-we", "foo", inf)
    
    try await run(withStdin: FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/null")), output: "foo bar\n", args: "-Z", "-wefoo", inf)
    rm(inf)
  }
  
  @Test("Checks for zgrep wrapper problems with -e PATTERN (PR 247126)") func zgrep_eflag() async throws {
    let inf = try tmpfile("test4", "foo bar\n")
    let null = try FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/null"))
    try await run(withStdin: null, output: "foo bar\n", args: "-Z", "-e", "foo bar", inf)
    
    try await run(withStdin: null, output: "foo bar\n", args: "-Z", "--regexp=foo bar",  inf)
    rm(inf)
  }
  
  @Test("Checks for zgrep wrapper problems with -f FILE (PR 247126)", arguments: [false, true]) func zgrep_fflag(_ lo : Bool) async throws {
    let inf = try tmpfile("test5", "foobar\n")
    let inf2 = try tmpfile("pattern", "foo\n")
    let null = try FileHandle(forReadingFrom: URL(fileURLWithPath: "/dev/null"))
    try await run(withStdin: null, output: "foobar\n", args:
                    lo ? ["-Z","--file=\(inf2.path)", inf]
                  : ["-Z", "-f", inf2, inf])
    rm(inf, inf2)
  }
  
  @Test("Checks for zgrep wrapper problems with --ignore-case reading from stdin (PR 247126)") func zgrep_long_eflag() async throws {
    try await run(withStdin: "foobar\n", output: "foobar\n", args: "-Z", "-e", "foo")
  }
  
  @Test("Checks for zgrep wrapper problems with multiple -e flags (PR 247126)") func zgrep_multiple_eflags() async throws {
    let inf = try tmpfile("test6", "foobar\n")
    try await run(output: "foobar\n", args: "-Z", "-e", "foo", "-e", "xxx", inf)
    rm(inf)
  }
  
  @Test("Checks for zgrep wrapper problems with empty -e flags pattern (PR 247126)") func zgrep_empty_eflag() async throws {
    let inf = try tmpfile("test7", "foobar\n")
    try await run(output: "foobar\n", args: "-Z", "-e", "", inf)
    rm(inf)
  }
  
  @Test("Checks that -s flag suppresses error messages about nonexistent files") func nonexistent() async throws {
    try await run(status: 2, args: "-s", "foobar", "nonexistent")
  }
  
  @Test("Checks display context with -z flag") func context2() async throws {
    let t1 = try tmpfile("test1", "haddock\0cod\0plaice\0")
    let t2 = try tmpfile("test2", "mackeral\0cod\0crab\0")
    let expected = try fileContents("d_context2_a.out")
    try await run(output: expected, args: "-z", "-A1", "cod", t1, t2)
    rm(t1, t2)
  }
  
  // Begin FreeBSD
  
  @Test("Check behavior of zero-length matches with -o flag (PR 195763)",
        arguments: [
          ("a", "(^|:)0*"),
          ("b", "(^|:)0*"),
          ("c", "[[:alnum:]]*"),
        ])
  func oflag_zerolen(_ s : String, _ p : String) async throws {
    let inp = try inFile("d_oflag_zerolen_\(s).in")
    let expected = try fileContents("d_oflag_zerolen_\(s).out")
    try await run(output: expected, args: "-Eo", p, inp)
  }
  
  @Test("Check behavior of zero-length matches with -o flag (PR 195763)") func oflag_zerolen_d() async throws {
    let inp = try inFile("d_oflag_zerolen_d.in")
    try await run(output: "", args: "-Eo", "", inp)
  }
  
  @Test("Check behavior of zero-length matches with -o flag (PR 195763)", arguments: [
    false, true
  ]) func oflag_zerolen_e(_ f : Bool) async throws {
    let inp = try inFile("d_oflag_zerolen_e.in")
    let vv = f ? ["ab", "bc"] : ["bc", "ab"]
    let expected = try fileContents("d_oflag_zerolen_e.out")
    try await run(output: expected, args: "-o", "-e", vv[0], "-e", vv[1], inp)
  }
  
  
  @Test("Check behavior of zero-length matches with -o flag (PR 195763)") func oflag_zerolen_f() async throws {
    let inp = try inFile("d_oflag_zerolen_apple_f.in")
    let expected = try fileContents("d_oflag_zerolen_apple_f.out")
    try await run(output: expected, args: "-o", "-e", "[A-Z]", inp,
                  env: ["LANG":"C", "LC_ALL":"C"])
  }
  
  @Test("Check that we actually get a match with -x flag (PR 180998)") func xflag() async throws {
    let pf = try tmpfile("pattern_file", ((1...128).map { String($0) + "\n"}).joined() )
    let mf = try tmpfile("match_file", "128\n")
    try await run(output: "128\n", args: "-xf", pf, mf)
    rm(pf, mf)
  }
  
  @Test("Check --color support") func color() async throws {
    let inf = try inFile("d_color_a.in")
    let expected = try fileContents("d_color_a.out")
    try await run(output: expected, args: "--color=auto", "-e", ".*", "-e", "a", inf)
  }
  
  @Test("Check --color support", arguments: [
    false, true
  ]) func color_b(_ f : Bool) async throws {
    let inf = try inFile("d_color_b.in")
    let grepfile = try tmpfile("grepfile", "abcd*\nabc$\n^abc\n")
    let expected = try fileContents("d_color_\(f ? "b":"c").out")
    
    try await run(output: expected, args: "--color=\(f ? "auto":"always")", "-f", grepfile, inf)
    rm(grepfile)
  }
  
  @Test("Check for handling of a null byte in empty file, specified by -f (PR 202022)") func f_file_empty() async throws {
    let inf = try inFile("d_f_file_empty.in")
    let nulpat = try tmpfile("nulpat", "\0\n")
    try await run(status: 1, args: "-f", nulpat, inf)
    rm(nulpat)
  }
  
  @Test("Check proper handling of escaped vs. unescaped do expressions (PR 175314)") func escmap() async throws {
    let inf = try inFile("d_escmap.in")
    try await run(status: 1, args: "-o", "f.o\\.", inf)
    try await run(output: "f.oo\n", args: "-o", "f.o.", inf)
  }
  
  @Test("Check for handling of an invalid empty pattern (PR 194823)") func egrep_empty_invalid() async throws {
    try await run(status: 1, args: "-E", "{", "/dev/null")
  }
  
  @Test("Check for successful zero-length matches with ^$", arguments: [1, 2]) func zerolen(_ n : Int) async throws {
    switch n {
      case 1: try await run(withStdin: "Eggs\n\nCheese", output: "\n", args: "-e", "^$")
      case 2: try await run(withStdin: "Eggs\n\nCheese", output: "Eggs\nCheese\n", args: "-v", "-e", "^$")
      default:
        break
    }
  }
  
  @Test("Check for proper handling of -w with an empty pattern (PR 105221)",
        arguments: ["", "qaz"], [false, true]) func wflag_emptypat(_ fc : String, _ vflag : Bool) async throws {
    let test = try tmpfile("test", fc + (vflag ? "\n" : ""))
    if vflag {
      try await run(output: fc + "\n", args: "-vw" , "-e", "", test)
    } else {
      try await run(status: 1, output: "", args: "-w", "-e", "", test)
    }
    rm(test)
  }
  
  @Test("Check for handling of an invalid empty pattern with -x") func xflag_emptypat() async throws {
    let test1 = try tmpfile("test1", "")
    let test2 = try tmpfile("test2", "\n")
    let test3 = try tmpfile("test3", "qaz")
    let test4 = try tmpfile("test4", " qaz\n")
    
    try await run(status: 1, output: "", args: "-x", "-e", "", test1)
    try await run(output: "\n", args: "-x", "-e", "", test2)
    try await run(status: 1, output: "", args: "-x", "-e", "", test3)
    try await run(status: 1, output: "", args: "-x", "-e", "", test4)
    rm(test1, test2, test3, test4)
  }
  
  @Test("Simple checks that grep -x with an empty pattern isn't matching every line.") func xflag_emptypat2() async throws {
    let fc = try fileContents("COPYRIGHT")
    let lines = fc.count { $0 == "\n"}
    
    let (r, j, _) = try await ShellProcess(cmd, "-Fxc", "").run(fc)
    let (r2, j2, _) = try await ShellProcess(cmd, "-Fvxc", "").run(fc)
    #expect(r == 0)
    #expect(r2 == 0)
    let n = Int(j!.dropLast() ) // remove trailing newline
    let n2 = Int(j2!.dropLast()) // remove trailing newline
    #expect(n != lines)
    #expect(n2 != lines)
    #expect(n != n2)
  }
  
  @Test("More checks for handling empty patterns with -x", arguments: Array(1...5)) func xflag_emptypat_plus(_ n : Int) async throws {
    let target = "foo\n\nbar\n\nbaz\n"
    let target_spacelines = "foo\n \nbar\n \nbaz\n"
    let matches = "foo\nbar\nbaz\n"
    let spacelines = " \n \n"
    let patlist1 = try tmpfile("patlist1", "foo\n\nbar\n\nbaz\n")
    let patlist2 = try tmpfile("patlist2", "foo\n\nba\n\nbaz\n")
    let matches_not2 = "foo\n\n\nbaz\n"
    
    switch n {
      case 1:   try await run(withStdin: target, output: target , args: "-Fxf", patlist1)
      case 2:  try await run(withStdin: target_spacelines, output:  matches, args: "-Fxf", patlist1)
      case 3: try await run(withStdin: target, output: matches_not2, args: "-Fxf", patlist2)
        // -v handling
      case 4: try await run(withStdin: target, status: 1, output: "", args: "-Fvxf", patlist1)
      case 5: try await run(withStdin: target_spacelines, output: spacelines, args: "-Fxvf", patlist1)
      default: break
    }
    rm(patlist1, patlist2)
  }
  
  @Test("Check for proper handling of empty pattern files (PR 253209)") func emptyfile() async throws {
    let epatfile = try tmpfile("epatfile", "")
    try await run(withStdin: "blubb\n", status: 1, output: "", args: "-Ff", epatfile)
    rm(epatfile)
  }
  
  @Test("Check for proper handling of lines with excessive matches (PR 218811") func excessive_matches() async throws {
    let intest = String(repeating: "x", count: 4096)
    let (r, j, _) = try await ShellProcess(cmd, "-o", "x").run(intest)
    #expect(r == 0)
    #expect( (j!.count { $0 == "\n" }) == intest.count)
    let (r2, j2, _) = try await ShellProcess(cmd, "-on", "x").run(intest)
    #expect(r2 == 0)
    let (r3, j3, _) = try await ShellProcess(cmd, "-v", "1:x").run(j2!)
    #expect(r3 == 1)
  }
  
  @Test("Check for fgrep sanity, literal expressions only") func fgrep_sanity() async throws {
    try await run(withStdin: "Foo", output: "Foo\n", args: "-Fe", "Foo")
    try await run(withStdin: "Foo", status: 1, output: "", args: "-Fe", "Fo.")
  }
  
  @Test("Check for egrep sanity (EREs only)") func egrep_sanity() async throws {
    let test1 = "Foobar(ed)"
    let test2 = "M{1}"
    let args: [String] = ["-E", "-o", "-e"]
    try await run(withStdin: test1, output: "Foo\n", args: args + ["F.."] )
    try await run(withStdin: test1, output: "Foobar\n", args: args + ["F[a-z]*"] )
    try await run(withStdin: test1, output: "Fo\n", args: args + ["F(o|p)"] )
    try await run(withStdin: test1, output: "(ed)\n", args: args + ["\\(ed\\)"] )
    try await run(withStdin: test2, output: "M\n", args: args + ["M{1}"] )
    try await run(withStdin: test2, output: "M{1}\n", args: args + ["M\\{1\\}"] )
  }

  @Test("Check for grep sanity (BREs only)", arguments: [
    ("Foo\n", "F..", "Foobar(ed)"),
    ("Foobar\n", "F[a-z]*", "Foobar(ed)"),
    ("Fo\n", "F\\(o\\)", "Foobar(ed)"),
    ("(ed)\n", "(ed)", "Foobar(ed)"),
    ("M{1}\n", "M{1}", "M{1}"),
    ("M\n", "M\\{1\\}", "M{1}"),
  ]) func grep_sanity(_ x : String, _ p : String, _ t : String) async throws {
    let args: [String] = ["-o", "-e"]
    try await run(withStdin: t, output: x, args: args + [p] )
  }
  
  @Test("Check for incorrectly matching lines with both -w and -v flags (PR 218467)",
        arguments: [
          "x xx\n", "xx x\n"
          ],
        [false, true]
  ) func wv_combo_break(_ io : String, _ vb : Bool) async throws {
      
    if vb {
      try await run(withStdin: io, status: 1, args: "-v", "-w", "x")
    } else {
      try await run(withStdin: io, output: io, args: "-w", "x")
    }
  }
  
  @Test("Check for -n/-b producing per-line metadata output", arguments: [
    ("1:1:xx\n", "-bon", "xx$"),("2:4:yyyy\n", "-bn", "yy"), ("2:6:yy\n", "-bon", "yy$")
  ]) func ocolor_metadata(_ outp : String, _ arg1 : String, _ arg2: String) async throws {
    let test1 = "xxx\nyyyy\nzzz\nfoobarbaz\n"
    try await run(withStdin: test1, output: outp, args: arg1, arg2)
  }
  
  
  @Test("Check for -n/-b producing per-line metadata output") func ocolor_metadata_2() async throws {
    let test1 = "xxx\nyyyy\nzzz\nfoobarbaz\n"
    // these checks ensure that grep isn't producing bogus line numbering in the middle of a line
    let check_expr = "^[^:]*[0-9][^:]*:[^:]+$"
    let (r, j, _) = try await ShellProcess(cmd, "-Eon", "x|y|z|f").run(test1)
    #expect(r == 0)
    
    try await run(withStdin: j!, status: 1, args: "-Ev", check_expr)

    let (r2, j2, _) = try await ShellProcess(cmd, "-En", "x|y|z|f", "--color=always").run(test1)
    #expect(r2 == 0)
    try await run(withStdin: j2!, status: 1, args: "-Ev", check_expr)
    
    let (r3, j3, _) = try await ShellProcess(cmd, "-Eon", "x|y|z|f", "--color=always").run(test1)
    #expect(r3 == 0)
    try await run(withStdin: j3!, status: 1, args: "-Ev", check_expr)
  }
  
  @Test("Check for no match (-c, -l, -L, -q) flags not producing line matches or context (PR 219077)", arguments: [
    "-C", "-B", "-A",
  ]) func grep_nomatch_flags(_ f : String) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    try await run(output: "1\n", args: "-c", f, "1", "-e", "B", test1)
    rm(test1)
  }
  
  @Test("Check for no match (-c, -l, -L, -q) flags not producing line matches or context (3) (PR 219077)", arguments: [
    "-C", "-B", "-A",
  ]) func grep_nomatch_flags3(_ f : String) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    try await run(output: "test1\n", args: "-l", f, "1", "-e", "B", test1)
    rm(test1)
  }
  
  @Test("Check for no match (-c, -l, -L, -q) flags not producing line matches or context (2) (PR 219077)", arguments: Array(1...4) ) func grep_nomatch_flags2(_ n : Int) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    let test2 = try tmpfile("test2", "D\n")
    switch n {
      case 1: try await run(output: "test1\n", args: "-l", "-e", "B", test1)
      case 2: try await run(status: 1, output: "test1\n", args: "-L", "-e", "D", test1)
      case 3: try await run(output: "test1\n", args: "-L", "-e", "D", test1, test2)
        
      case 4: try await run(output: "", args: "-q", "-e", "B", test1)
      default:
        break
    }
    rm(test1, test2)
  }
  
  @Test("Check for no match (-c, -l, -L, -q) flags not producing line matches or context (4) (PR 219077) (2)", arguments: ["-B", "-C", "-A"]) func grep_nomatch_flags4(_ f : String) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    try await run(output: "", args: "-q", f, "1", "-e", "B", test1)
    rm(test1)
  }
  
  @Test("Check for handling of invalid context arguments", arguments: Array(1...6) ) func badcontext(_ n : Int) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    switch n {
      case 1: try await run(status: 2, error: /context argument must be non-negative/, args: "-A", "-1", "B", test1)
      case 2: try await run(status: 2, error: /context argument must be non-negative/, args: "-B", "-1", "B", test1)
      case 3: try await run(status: 2, error: /context argument must be non-negative/, args: "-C", "-1", "B", test1)
      case 4: try await run(status: 2, error: /Invalid argument/, args: "-A", "B", "B", test1)
      case 5: try await run(status: 2, error: /Invalid argument/, args: "-B", "B", "B", test1)
      case 6: try await run(status: 2, error: /Invalid argument/, args: "-C", "B", "B", test1)
      default:
        break
    }
    rm(test1)
  }
  
  @Test("Check output for binary flags (-a, -I, -U, --binary-files)", arguments:
    [false, true], [false, true]
  ) func binary_flags(_ u : Bool, _ c : Bool) async throws {
    let test1 = try tmpfile("test1", "A\0B\0C")
    let binmatchtext = "Binary file test1 matches\n"
    
    // Binaries not treated as text (default, -U)
    let a = u ? ["-U", "B"] : ["B"]
    let b = c ? ["-C", "1"] : []
    let aa = (a+b) as [Arguable]
    try await run(output: binmatchtext, args: aa + [test1] )
    rm(test1)
  }
  
  @Test("Check output for binary flags (-a, -I, -U, --binary-files) (2)", arguments: Array(1...8) ) func binary_flags2(_ n : Int) async throws {
      let binmatchtext = "Binary file test1 matches\n"

      let test1 = try tmpfile("test1", "A\0B\0C")
      let test2 = try tmpfile("test2", "A\n\0B\n\0C")
    switch n {
        // Binary, -a, no newlines
      case 1: try await run(output: "A\0B\0C\n", args: "-a", "B", test1)
      case 2: try await run(output: "A\0B\0C\n", args: "-a", "B", "-C", "1", test1)
        
        // Binary, -a, newlines
      case 3: try await run(output: "\0B\n", args: "-a", "B", test2)
      case 4: try await run(output: "A\n\0B\n\0C\n", args: "-a", "B", "-C", "1", test2)
        
        // Binary files ignored
      case 5: try await run(status: 1, args: "-I", "B", test2)
        
        // --binary-files equivalence
      case 6: try await run(output: binmatchtext, args: "--binary-files=binary", "B", test1)
      case 7: try await run(output: "A\0B\0C\n", args: "--binary-files=text", "B", test1)
      case 8: try await run(status: 1, args: "--binary-files=without-match", "B", test2)
      default:
        break
    }
    rm(test1, test2)
  }
  
  @Test("Check basic matching with --mmap flag", arguments: [1, 2]) func mmap(_ n : Int) async throws {
    let test1 = try tmpfile("test1", "A\nB\nC\n")
    switch n {
      case 1: try await run(output: "B\n", args: "--mmap", "-oe", "B", test1)
      case 2:try await run(status: 1, args: "--mmap", "-e", "Z", test1)
      default:
        break
    }
    rm(test1)
  }
  
  @Test("Check proper behavior of matching all with an empty string", arguments: [0,1,2] ) func matchall(_ n : Int) async throws {
    let test1 = try tmpfile("test1", "")
    let test2 = try tmpfile("test2", "A")
    let test3 = try tmpfile("test3", "A\nB")
    
    let output = n == 1 ? "test3:A\ntest3:B\ntest2:A\n" :
    "test2:A\ntest3:A\ntest3:B\n"
    let j = [test1, test2, test3]
    let k = [""] + (Array(j.dropFirst(3-n) + j.prefix(3-n)) as [Arguable])
    
    try await run(output: output, args: k)
    rm(test1, test2, test3)
  }
  
  @Test("Check proper behavior of matching with an empty string (2)") func matchall2() async throws {
    let test1 = try tmpfile("test1", "")
    try await run(status: 1, args: "", test1)
    rm(test1)
  }
  
  @Test("Check proper behavior with multiple patterns supplied to fgrep") func fgrep_multipatterns() async throws {
    let test1 = try tmpfile("test1", "Foo\nBar\nBaz")
    try await run(output: "Foo\nBaz\n", args: "-F", "-e", "Foo", "-e", "Baz", test1)
    try await run(output: "Foo\nBaz\n", args: "-F", "-e", "Baz", "-e", "Foo", test1)
    try await run(output: "Bar\nBaz\n", args: "-F", "-e", "Bar", "-e", "Baz", test1)
    rm(test1)
  }
  
  @Test("Check proper handling of -i supplied to fgrep") func fgrep_icase() async throws {
    let test1 = try tmpfile("test1", "Foo\nBar\nBaz")
    try await run(output: "Foo\nBaz\n", args: "-Fi", "-e", "foo", "-e", "baz", "-e", "Baz", test1)
    try await run(output: "Foo\nBaz\n", args: "-Fi", "-e", "baz", "-e", "foo", test1)
    try await run(output: "Bar\nBaz\n", args: "-Fi", "-e", "bar", "-e", "baz", test1)
    try await run(output: "Bar\nBaz\n", args: "-Fi", "-e", "BAR", "-e", "bAz", test1)
    rm(test1)
  }
  
  @Test("Check proper handling of -o supplied to fgrep") func fgrep_oflag() async throws {
    let test1 = try tmpfile("test1", "abcdefghi\n")
    try await run(output: "a\n", args: "-Fo", "a", test1)
    try await run(output: "i\n", args: "-Fo", "i", test1)
    try await run(output: "abc\n", args: "-Fo", "abc", test1)
    try await run(output: "fgh\n", args: "-Fo", "fgh", test1)
    try await run(output: "cde\n", args: "-Fo", "cde", test1)
    try await run(output: "bcd\n", args: "-Fo", "-e", "bcd", "-e", "cde", test1)
    try await run(output: "bcd\nefg\n", args: "-Fo", "-e", "bcd", "-e", "efg", test1)
    
    try await run(status: 1, args: "-Fo", "xabc", test1)
    try await run(status: 1, args: "-Fo", "abcx", test1)
    try await run(status: 1, args: "-Fo", "xghi", test1)
    try await run(status: 1, args: "-Fo", "ghix", test1)
    try await run(status: 1, args: "-Fo", "abcdefghiklmnopqrstuvwxyz", test1)
    rm(test1)
  }
  
  @Test("Check proper handling of -c") func cflag() async throws {
    let test1 = try tmpfile("test1", "a\nb\nc\n")
    try await run(output: "1\n", args: "-Ec", "a", test1)
        try await run(output: "2\n", args: "-Ec", "a|b", test1)
        try await run(output: "3\n", args: "-Ec", "a|b|c", test1)
    
    try await run(output: "test1:2\n", args: "-EHc", "a|b", test1)
    rm(test1)
  }
  
  @Test("Check proper handling of -m", arguments: [
    ("1", "a"), ("2", "a|b"), ("3", "a|b|c|f"),
  ]) func mflag(_ n : String, _ p : String) async throws {
    let test1 = try tmpfile("test1", "a\nb\nc\nd\ne\nf\n")
    
    try await run(output: "\(n)\n", args: "-m", n, "-Ec", p, test1)
    rm(test1)
  }

    @Test("Check proper handling of -m") func mflag2() async throws {
      let test1 = try tmpfile("test1", "a\nb\nc\nd\ne\nf\n")
    try await run(output: "test1:2\n", args: "-m", "2", "-EHc", "a|b|e|f", test1)
    rm(test1)
  }
  
  @Test("Check proper handling of -m with trailing context ({PR 253350)") func mflag_trail_ctx() async throws {
    let test1 = try tmpfile("test1", "foo\nfoo\nbar\nfoo\nbar\nfoo\nbar\n")
    
    // Should pick up the next line after matching the first.
    try await run(output: "foo\nfoo\n", args: "-A1", "-m1", "foo", test1)
    
    // Make sure the trailer is picked up as a non-match!
    try await run(output: "1:foo\n2-foo\n", args: "-A1", "-nm1", "foo", test1)
    rm(test1)
  }
  
  @Test("Ensures that zgrep functions properly with multiple files") func zgrep_multiple_files() async throws {
    let test1 = try tmpfile("test1", "foo\n")
    let test2 = try tmpfile("test2", "foo\n")
    
    try await run(output: "test1:foo\ntest2:foo\n", args: "-Z", "foo", test1, test2)
    let test11 = try tmpfile("test1", "bar\n")
    try await run(output: "test2:foo\n", args: "-Z", "foo", test11, test2)
    
    let test22 = try tmpfile("test2", "bar\n")
    try await run(status: 1, args: "-Z", "foo", test11, test22)
    rm(test11, test22)
  }
  
  @Test("rdar://problem/112930177 - binary files have no locale") func binlocale() async throws {
    //d_binlocale.in has a nul terminator to make it a binary file, and the
    // character immediately preceding "Hello" would make it look like a two
    //  byte UTF-8 sequence.  Therefore, if we aren't handling this properly,
    //  we won't match on "Hello" because the "H" has been consumed by the
    //  preceding character.
    let a = try inFile("d_binlocale.in")
    try await run(output: "Hello\n", args: "-ao", "Hello", a, env: ["LC_ALL": "en_US.UTF-8"])
  }
}
