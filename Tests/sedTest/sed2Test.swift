// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

/*
  Copyright 2017 Dell EMC.
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import ShellTesting

@Suite("sed2_test", .serialized) class sed2Test : ShellTest {

  let cmd = "sed"
  let suite = "sedTest"
  
  @Test("Verify -i works with a hard linked source file")
  func inplace_hardlink_src() async throws {
    let a = try tmpfile("a", "foo\n")
    let b = FileManager.default.temporaryDirectory.appending(path: "b")
    rm(b)
    try FileManager.default.linkItem(at: a, to: b)
    try await run(args: "-i", "", "-e", "s,foo,bar,g", b)
    let m = try String(contentsOf: b, encoding: .utf8)
    #expect(m == "bar\n")
    let n = try String(contentsOf: b, encoding: .utf8)
    #expect(n == "bar\n")

    let d = FileManager.default.temporaryDirectory
    let e = try FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: [])
    #expect( (e.filter { $0.lastPathComponent.hasPrefix(".!") }).count == 0  )
    rm(a)
    rm(b)
  }
             
  @Test("Verify -i does not work with a symlinked source file")
  func inplace_symlink_src() async throws {
    let a = try tmpfile("a", "foo\n")
    let b = FileManager.default.temporaryDirectory.appending(path: "b")
    rm(b)
    try FileManager.default.createSymbolicLink(at: b, withDestinationURL: a)
    try await run(status: 1, error: /in-place editing only works for regular files/, args: "-i", "", "-e", "s,foo,bar,g", b)

    let d = FileManager.default.temporaryDirectory
    let e = try FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: [])
    #expect( (e.filter { $0.lastPathComponent.hasPrefix(".!") }).count == 0  )
    rm(a)
    rm(b)
  }
  
  @Test("Verify -i works correctly with the 'q' command")
  func inplace_command_q() async throws {
    let a = try tmpfile("a", "1\n2\n3\n")
    try await run(output: "1\n2\n", args: "2q", a)
    try await run(args: "-i.bak", "2q", a)

    let j2 = try String(contentsOf: a, encoding: .utf8)
    #expect(j2 == "1\n2\n")
    
    let j3 = try String(contentsOf: a.appendingPathExtension("bak"), encoding: .utf8)
    #expect(j3 == "1\n2\n3\n")
    
    let d = FileManager.default.temporaryDirectory
    let e = try FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: [])
    #expect( (e.filter { $0.lastPathComponent.hasPrefix(".!") }).count == 0  )

    rm(a)
    rm(a.appendingPathExtension("bak"))
  }
  
  @Test("Verify functional escaping of \\n, \\r, and \\t",
        .serialized,
        arguments: [
    ("/\\t/d", "a\nt\\t\n"),
    ("s/\\t/    /g", "a\nt\\t\n    b\n        c\r\n"),
    ("s/\\t/\\t\\t/g", "a\nt\\t\n\t\tb\n\t\t\t\tc\r\n"),
    ("s/\\\\t//g", "a\nt\n\tb\n\t\tc\r\n"),
    ("s/\\r//", "a\nt\\t\n\tb\n\t\tc\n"),
  ])
  func escape_subst(_ expr : String, _ res : String) async throws {
    let inp = "a\nt\\t\n\tb\n\t\tc\r\n"
    try await run(withStdin: inp, output: res, args: expr)
  }
  
  @Test("Non-conformont POSIX test for escaping of \\n, \\r, and \\t"
        , .disabled("expected failure")
  )
  func nonconformant_ecape_subst () async throws {
    try await run(withStdin: "a\tb c\rx\n", output: "abcx\n", args: "s/[ \\r\\t]//g")
  }
  
  @Test("Verify poper conversion of hex escapes")
  func hex_subst() async throws {
    let a = try tmpfile("a", "test='foo'")
    let b = try tmpfile("b", "test='27foo'")
    let c = try tmpfile("c", "\rn")
    
    try await run(output: "test=\"foo\"", args: "s/\\x27/\"/g", a)
    
    try await run(output: "'test'='foo'", args: "s/test/\\x27test\\x27/g", a)
    
    // make sure we take trailing digits literally.
    try await run(output: "test=\"foo'", args: "s/\\x2727/\"/g", b)
    
    // single digit \x should work as well
    try await run(output:"xn", args: "s/\\xd/x/", c)
    rm(a, b, c)
  }

  @Test("Test for non POSIX conformant hex handling",
        .disabled("expected failure"))
  func nonconformant_hex_subst() async throws {
    let d = try tmpfile("d", "xx")
    try await run(status: 1, error: /clem/, args: "s/\\xx//", d)
    rm(d)
  }
  
  @Test("Verify -f -")
  func commands_on_stdin() async throws {
    let a = try tmpfile("a", "a\n")
    let a_to_b = try tmpfile("a_to_b", "s/a/b/\n")
    let b_to_c = // try tmpfile("b_to_c", "s/b/c/\n")
    "s/b/c/\n"
    let dash = try tmpfile("-", "s/c/d/\n")
    // the `./-` would ordinarily be `dash` -- but the dash means something special in this instance
    try await run(withStdin: b_to_c, output: "d\n", args: "-f", a_to_b, "-f", "-", "-f" , "./-", a )
    
    // Verify that nothing is printed if there are no input files provided
    
    try await run(withStdin: "i\\\nx", output: "", args: "-f", "-")
    rm(a, a_to_b, dash)
  }
  
  @Test("Verify '[' is ordinary character for 'y' command", arguments:[
    "y/[/x/", "y/[]/xy/", "y/[a]/xyz/",
  ])
  func bracket_y(_ p : String) async throws {
    try await run(args: p)
  }
    
  @Test("Verify '[' is ordinary character for 'y' command", arguments: [
    ("y/[a]/xyz/", "][a\n", "zxy\n"),
    ("y/[]/ct/", "bra[ke]\n", "bracket\n"),
    ("y[\\[][ct[", "bra[ke]\n", "bracket\n"),
  ])
  func bracket_y2(_ p  : String, _ inp : String, _ res : String) async throws {
    try await run(withStdin: inp, output: res, args: p)
  }
  
  @Test("Verify -H", arguments: [
    (["-e"], "0_0\n", false), // enhanced features such as \< and \d are disabled by default
    (["-E", "-e"], "0_0\n", false),
    (["-H", "-e"], "o_0\n", false),
    (["-H", "-e"], "0_0\n", true), // -H alone does not enable extended syntax
    (["-EH", "-e"], "o_0\n", true), // -EH enables extended syntax with enhanced features
    (["-HE", "-e"], "o_0\n", true), // order of -E and -H does not matter
    ])
  func enhanced(_ opts : [String], _ res : String, _ f: Bool) async throws {
    let k = f ?"s/\\<(\\d)/o/" :  "s/\\<\\d/o/"
    try await run(withStdin: "0_0\n", output: res, args: opts + [k] )
  }
}
