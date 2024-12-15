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

import Foundation
import Testing
import TestSupport

@Suite("sed2_test", .serialized) class sed2Test {

  let ex = "sed"
  
  @Test("Verify -i works with a hard linked source file")
  func inplace_hardlink_src() async throws {
    let a = try tmpfile("a", "foo\n")
    let b = FileManager.default.temporaryDirectory.appending(path: "b")
    rm(b)
    try FileManager.default.linkItem(at: a, to: b)
    let p = ShellProcess(ex, "-i", "", "-e", "s,foo,bar,g", b.relativePath)
    let (r, _, _) = try await p.run()
    #expect(r == 0)
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
    let p = ShellProcess(ex, "-i", "", "-e", "s,foo,bar,g", b.relativePath)
    let (r, _, e2) = try await p.run()
    #expect(r != 0, Comment(rawValue: e2 ?? "") )
    if r != 0 { print(e2 ?? "") }

    let d = FileManager.default.temporaryDirectory
    let e = try FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil, options: [])
    #expect( (e.filter { $0.lastPathComponent.hasPrefix(".!") }).count == 0  )
    rm(a)
    rm(b)
  }
  
  @Test("Verify -i works correctly with the 'q' command")
  func inplace_command_q() async throws {
    let a = try tmpfile("a", "1\n2\n3\n")
    let p = ShellProcess(ex, "2q", a.relativePath)
    let (r, j, _) = try await p.run()
    #expect(r == 0)
    #expect(j! == "1\n2\n")
    
    let p2 = ShellProcess(ex, "-i.bak", "2q", a.relativePath)
    let (r2, _, _) = try await p2.run()
    #expect(r2 == 0)

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
      let p = ShellProcess(ex, expr)
    let inp = "a\nt\\t\n\tb\n\t\tc\r\n"
    let (r, j, e) = try await p.run(inp)
    #expect(r == 0)
    #expect(j! == res)
  }
  
  @Test("Non-conformont POSIX test for escaping of \\n, \\r, and \\t"
        , .disabled("expected failure")
  )
  func nonconformant_ecape_subst () async throws {
    let p = ShellProcess(ex, "s/[ \\r\\t]//g")
    let (r, j, _) = try await p.run("a\tb c\rx\n")
    #expect(r == 0)
    #expect(j! == "abcx\n")
  }
  
  @Test("Verify poper conversion of hex escapes")
  func hex_subst() async throws {
    let a = try tmpfile("a", "test='foo'")
    let b = try tmpfile("b", "test='27foo'")
    let c = try tmpfile("c", "\rn")
    
    let p = ShellProcess(ex, "s/\\x27/\"/g", a.relativePath)
    let (r, j, _) = try await p.run()
    #expect(r == 0)
    #expect(j! == "test=\"foo\"")
    
    let p2 = ShellProcess(ex, "s/test/\\x27test\\x27/g", a.relativePath)
    let (r2, j2, _) = try await p2.run()
    #expect(r2 == 0)
    #expect(j2! == "'test'='foo'")
    
    // make sure we take trailing digits literally.
    let p3 = ShellProcess(ex, "s/\\x2727/\"/g", b.relativePath)
    let (r3, j3, _) = try await p3.run()
    #expect(r3 == 0)
    #expect(j3! == "test=\"foo'")
    
    // single digit \x should work as well
    let p4 = ShellProcess(ex, "s/\\xd/x/", c.relativePath)
    let (r4, j4, _) = try await p4.run()
    #expect(r4 == 0)
    #expect(j4! == "xn")
    rm(a)
    rm(b)
    rm(c)
  }

  @Test("Test for non POSIX conformant hex handling",
        .disabled("expected failure"))
  func nonconformant_hex_subst() async throws {
    let d = try tmpfile("d", "xx")

    let p5 = ShellProcess(ex, "s/\\xx//", d.relativePath)
    let (r5, j5, e5) = try await p5.run()
    #expect(r5 != 0, Comment(rawValue: e5 ?? ""))
    rm(d)
  }
  
  @Test("Verify -f -")
  func commands_on_stdin() async throws {
    let a = try tmpfile("a", "a\n")
    let a_to_b = try tmpfile("a_to_b", "s/a/b/\n")
    let b_to_c = // try tmpfile("b_to_c", "s/b/c/\n")
    "s/b/c/\n"
    let dash = try tmpfile("-", "s/c/d/\n")
    let p = ShellProcess(ex, "-f", a_to_b.relativePath, "-f", "-", "-f" , dash.relativePath, a.relativePath )
    let (r, j, e) = try await p.run( b_to_c )
    #expect(r == 0, Comment(rawValue: e ?? ""))
    #expect(j! == "d\n")
    
    // Verify that nothing is printed if there are no input files provided
    let p2 = ShellProcess(ex, "-f", "-")
    let (r2, j2, _) = try await p2.run("i\\\nx")
    #expect(r2 == 0)
    #expect(j2!.isEmpty)
    
    rm(a, a_to_b, dash)
  }
  
  @Test("Verify '[' is ordinary character for 'y' command")
  func bracket_y() async throws {
    let p = ShellProcess(ex, "y/[/x/")
    let (r, _, _) = try await p.run("\n")
    #expect(r == 0)

    let p2 = ShellProcess(ex, "y/[]/xy/")
    let (r2, _, _) = try await p2.run("\n")
    #expect(r2 == 0)

    let p3 = ShellProcess(ex, "y/[a]/xyz/")
    let (r3, _, _) = try await p3.run("\n")
    #expect(r3 == 0)
    
    let p4 = ShellProcess(ex, "y/[a]/xyz/")
    let (r4, j4, _) = try await p4.run("][a\n")
    #expect(r4 == 0)
    #expect(j4! == "zxy\n")
    
    let p5 = ShellProcess(ex, "y/[]/ct/")
    let (r5, j5, _) = try await p5.run("bra[ke]\n")
    #expect(r4 == 0)
    #expect(j5! == "bracket\n")
    
    let p6 = ShellProcess(ex, "y[\\[][ct[")
    let (r6, j6, _) = try await p6.run("bra[ke]\n")
    #expect(r6 == 0)
    #expect(j6! == "bracket\n")
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
    let p = ShellProcess(ex, opts + [k] )
    let (r, j, _) = try await p.run("0_0\n")
    #expect(r == 0)
    #expect(j! == res )
    
    
    
  }

}
