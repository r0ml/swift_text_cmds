// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

// $FreeBSD$

import Foundation
import Testing
import TestSupport

@Suite("sedRegress", .serialized) struct sedRegressTest {
  let ex = "sed"
  
  let i = getFile("sed", "regress", withExtension: "in")!
  
  @Test(arguments: ["G", "P"]) func GP(_ s : String) async throws {
    let p = ShellProcess(ex, s)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.\(s)", withExtension: "out"))
  }
  
  @Test func psl() async throws {
    let p = ShellProcess(ex, "$!g;P;D")
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.psl", withExtension: "out"))
  }
  
  @Test func bcb() async throws {
    let k = String(repeating: "x", count: 2043)
    let p = ShellProcess(ex, "s/X/\(k)\\\\zz/")
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.bcb", withExtension: "out"))
  }
  
  @Test func y() async throws {
    let p = ShellProcess(ex, "y/o/O/")
    let (r,j, _) = try await p.captureStdoutLaunch("foo")
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.y", withExtension: "out"))
  }
  
  @Test(arguments: ["g", "3", "4", "5"]) func sg(_ s : String) async throws {
    let p = ShellProcess(ex, "s/,*/,/\(s)")
    let (r,j, _) = try await p.captureStdoutLaunch("foo\n")
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.s\(s)", withExtension: "out"))
  }
  
  @Test func c0() async throws {
    let k = """
c\\
foo

"""
    let p = ShellProcess(ex, k)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.c0", withExtension: "out"))
  }
  
  @Test func c1() async throws {
    let k = """
4,$c\\
foo

"""
    let p = ShellProcess(ex, k)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.c1", withExtension: "out"))
  }
  
  @Test func c2() async throws {
    let k = """
3,9c\\
foo

"""
    let p = ShellProcess(ex, k)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.c2", withExtension: "out"))
  }
  
  @Test func c3() async throws {
    let k = """
3,/no such string/c\\
foo

"""
    let p = ShellProcess(ex, k)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.c3", withExtension: "out"))
  }
  
  @Test func b2a() async throws {
    let k = "2,3b\n1,2d"
    let p = ShellProcess(ex, k)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.b2a", withExtension: "out"))
  }
  
  // must be serialized -- file names get reused
  @Test(.serialized, arguments: [("1", "3,6d"),
                    ("2", "8,30d"),
                    ("3", "20,99d"),
                    ("4", "{;{;8,30d;};}"),
                    ("5", "3x;6G"),
                   ]) func inplace(_ n : String, _ expr : String) async throws {
    var linesin = [String]()
    var linesout = [String]()
    var inns = [URL]()
    var _inns = [URL]()
    for n in 1...5 {
      let k = "1\(n)_9\n"
      let p = ShellProcess(ex, expr)
      let (_, j, _) = try await p.captureStdoutLaunch(k)
      linesin.append(k)
      let u = try tmpfile("lines.in.\(n)", k)
      inns.append(u)
      let _u = try tmpfile("lines._in.\(n)", k)
      _inns.append(_u)
      linesout.append(j!)
    }
    
    let p = ShellProcess(ex, [expr]+inns.map { $0.relativePath} )
    let (r, lo, _) = try await p.captureStdoutLaunch()
    #expect(r == 0)
    
    let p2 = ShellProcess(ex, ["-i", "", expr] + inns.map { $0.relativePath})
    let (_, _, _) = try await p2.captureStdoutLaunch()
    
    let p3 = ShellProcess(ex, ["-I", "", expr] + _inns.map { $0.relativePath})
    let (_, _, _) = try await p3.captureStdoutLaunch()

    var li = [String]()
    for n in inns.indices {
      let res = try String(contentsOf: inns[n], encoding: .utf8)
      #expect(linesout[n] == res )
      li.append(try String(contentsOf: _inns[n], encoding: .utf8))
    }

    
    #expect(lo! == li.joined() )
    
    inns.forEach { rm($0) }
    _inns.forEach { rm($0) }
  }
  
  @Test(arguments: [("1", "/SED/Id"),
                    ("2", "s/SED/Foo/I"),
                    ("3", "s/SED/Foo/"),
                    ("4", "s/SED/Foo/i"),
                   ]) func icase(_ n : String, s : String) async throws {
    let p = ShellProcess(ex, s)
    let (r,j, _) = try await p.captureStdoutLaunch(i)
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.icase\(n)", withExtension: "out"))
    
  }
  
  @Test func hanoi() async throws {
    let inf = inFile("sed", "hanoi", withExtension: "sed")!
    let p = ShellProcess(ex, "-f", inf)
    let (r,j, _) = try await p.captureStdoutLaunch(":abcd: : :\n")
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.hanoi", withExtension: "out"))
  }
  
  @Test func math() async throws {
    let inf = inFile("sed", "math", withExtension: "sed")!
    let p = ShellProcess(ex, "-f", inf)
    let (r,j, _) = try await p.captureStdoutLaunch("4+7*3+2^7/3\n")
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.math", withExtension: "out"))
  }
  
  @Test func not() async throws {
    let p = ShellProcess(ex, "1!!s/foo/bar/")
    let (r,j, _) = try await p.captureStdoutLaunch("foo\n")
    #expect(r == 0)
    #expect(j == getFile("sed", "regress.not", withExtension: "out"))
  }
}
