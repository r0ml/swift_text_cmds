// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

/*
  Copyright (c) 2012 The NetBSD Foundation, Inc.
  All rights reserved.

  This code is derived from software contributed to The NetBSD Foundation
  by Jukka Ruohonen and David A. Holland.

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

@Suite("t_sed") class tSedTest : ShellTest {
  let cmd = "sed"
  let suiteBundle = "text_cmds_sedTest"
  
  @Test("Test that sed(1) does not fail when the 2048'th character is a backslash (PR bin/25899)")
  func c2048() async throws {
    let f = try inFile("d_c2048.in")
    try await run(withStdin: "foo\n", output: "foo\n", args: "-f", f)
  }
  
  @Test("Test that sed(1) handles empty back references (PR bin/28126)")
  func emptybackref() async throws {
    try await run(withStdin: "foo1bar1\n", output: "foo1bar1\n", args: "-ne", "/foo\\(.*\\)bar\\1/p")
  }

  @Test("Test that sed(1) handles long lines correctly (PR bin/42261)")
  func longlines() async throws {
    let str = String(repeating: "x", count: 2043)
    try await run(withStdin: "x\n", output: str+"\n", args: "s,x,\(str),g")
  }
  
  
  @Test("Test that sed(1) handles range selection correctly", arguments: [
    ("1,3d", "A\nB\nC\nD\n", "D\n"),
    ("2,4d", "A\nB\nC\nD\n", "A\n"),
    ("1,2d;4,5d", "A\nB\nC\nD\nE\n", "C\n"), // nonoverlapping ranges
    ("1,3d;3,5d", "A\nB\nC\nD\nE\n", "D\nE\n"), // overlapping ranges: the first prevents the second from being entered
    ("1,3s/A/B/;1,3n;1,3s/B/C/", "A\nB\nC\nD\n", "B\nB\nC\nD\n"), // the 'n' command can also prevent reanges from being entered
    ("1,3s/A/B/;1,3n;2,3s/B/C/", "A\nB\nC\nD\n", "B\nC\nC\nD\n"),
    
    // basic cases using regexps
    ("/A/,/C/d", "A\nB\nC\nD\n", "D\n"),
    ("/B/,/D/d", "A\nB\nC\nD\n", "A\n"),
    // two nonoverlapping ranges
    ("/A/,/B/d;/D/,/E/d", "A\nB\nC\nD\nE\n", "C\n"),
    // two overlapping ranges; the first blocks the second as above
    ("/A/,/C/d;/C/,/E/d", "A\nB\nC\nD\nE\n", "D\nE\n"),
    // the 'n' command makes some lines invisible to downstream regexps
    ("/A/,/C/s/A/B/;1,3n;/B/,/C/s/B/C/", "A\nB\nC\nD\n", "B\nC\nC\nD\n"),
    
    // a range ends at the *first* matching end line
    ("/A/,/C/d", "A\nB\nC\nD\nC\n", "D\nC\n"),
    
    // another matching start line within the range has no effect
    ("/A/,/C/d", "A\nB\nA\nC\nD\nC\n", "D\nC\n"),
  ])
  
  func rangeselection(_ range : String, _ input: String, _ expected: String) async throws {
    try await run(withStdin: input, output: expected, args: range)
  }

  @Test("Test that sed(1) preserves leading whitespace in insert and append (PR bin/49872)")
  func preserve_leading_ws_ia() async throws {
    let res = "    1 2 3\n4 5 6\n    7 8 9\n\n"
    try await run(withStdin: "\n", output: res, args: "-e", "/^$/i\\\n    1 2 3\\\n4 5 6\\\n    7 8 9")
  }
  
  // FIXME: is this monstrosity of encoding really what was intended?
  @Test("Test that sed(1) handles zero length matches correctly")
  func zerolen() async throws {
    let str = "H\u{c3}\u{82}Bnc\n".data(using: .isoLatin1)!
    let res = "`H`\u{c3}\u{82}`B`n``c``\n".data(using: .isoLatin1)!
    try await run(withStdin: str, output: res, args: "-E", "s/[A-Z]*/\\`&\\`/g", env: ["LANG":"C", "LC_CTYPE":"en_US.UTF-8", "LC_ALL":""])
  }
}
