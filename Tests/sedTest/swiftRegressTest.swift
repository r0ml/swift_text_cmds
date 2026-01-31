// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

// $FreeBSD$

import ShellTesting

@Suite("sedRegress", .serialized) class sedRegressTest : ShellTest {

  let cmd = "sed"
  let suiteBundle = "text_cmds_sedTest"
  
  var i : String!
  
  init() {
    i = try! self.fileContents("regress.in")
  }
  
  @Test(arguments: ["G", "P"]) func GP(_ s : String) async throws {
    let expected = try fileContents("regress.\(s).out")
    try await run(withStdin: i, output: expected, args: s)
  }
  
  @Test func psl() async throws {
    let expected = try fileContents("regress.psl.out")
    try await run(withStdin: i, output: expected, args: "$!g;P;D")
  }
  
  @Test func bcb() async throws {
    let k = String(repeating: "x", count: 2043)
    let expected = try fileContents("regress.bcb.out")
    try await run(withStdin: i, output: expected, args: "s/X/\(k)\\\\zz/")
  }
  
  @Test func y() async throws {
    let expected = try fileContents("regress.y.out")
    try await run(withStdin: "foo", output: expected, args: "y/o/O/")
  }
  
  @Test(arguments: ["g", "3", "4", "5"]) func sg(_ s : String) async throws {
    let expected = try fileContents("regress.s\(s).out")
    try await run(withStdin: "foo\n", output: expected, args: "s/,*/,/\(s)")
  }
  
  @Test func c0() async throws {
    let k = """
c\\
foo

"""
    
    let expected = try fileContents("regress.c0.out")
    try await run(withStdin: i, output: expected, args: k)
  }
  
  @Test func c1() async throws {
    let k = """
4,$c\\
foo

"""
    let expected = try fileContents("regress.c1.out")
    try await run( withStdin: i, output: expected, args: k)
  }
  
  @Test func c2() async throws {
    let k = """
3,9c\\
foo

"""
    let expected = try fileContents("regress.c2.out")
    try await run(withStdin: i, output: expected, args: k)
  }
  
  @Test func c3() async throws {
    let k = """
3,/no such string/c\\
foo

"""
    let expected = try fileContents("regress.c3.out")
    try await run(withStdin: i, output: expected, args: k)
  }
  
  @Test func b2a() async throws {
    let k = "2,3b\n1,2d"
    let expected = try fileContents("regress.b2a.out")
    try await run(withStdin: i, output: expected, args: k)
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
    var inns = [FilePath]()
    var _inns = [FilePath]()
    for n in 1...5 {
      let k = "1\(n)_9\n"
      try await run(withStdin: k, args: expr) {po in
        linesin.append(k)
        let u = try self.tmpfile("lines.in.\(n)", k)
        inns.append(u)
        let _u = try self.tmpfile("lines._in.\(n)", k)
        _inns.append(_u)
        linesout.append(po.string)
      }
    }
    
    try await run(status: 0, args: [expr]+inns.map { $0 } ) { po in
      try await self.run(args: ["-i", "", expr] + inns) { _ in

        try await self.run(args: ["-I", "", expr] + _inns) { _ in

          var li = [String]()
          for n in inns.indices {
            let res = try inns[n].readAsString()
            #expect(linesout[n] == res )
            li.append(try _inns[n].readAsString())
          }


          #expect(po.string == li.joined() )
        }
      }
    }
    inns.forEach { rm($0) }
    _inns.forEach { rm($0) }

  }
  
  @Test(arguments: [("1", "/SED/Id"),
                    ("2", "s/SED/Foo/I"),
                    ("3", "s/SED/Foo/"),
                    ("4", "s/SED/Foo/i"),
                   ]) func icase(_ n : String, s : String) async throws {
    let expected = try fileContents("regress.icase\(n).out")
    try await run(withStdin: i, output: expected, args: s)
  }
  
  @Test func hanoi() async throws {
    let inf = try inFile("hanoi.sed")
    let expected = try fileContents("regress.hanoi.out")
    try await run(withStdin: ":abcd: : :\n", output: expected, args: "-f", inf)
  }
  
  @Test func math() async throws {
    let inf = try inFile("math.sed")
    let expected = try fileContents("regress.math.out")
    try await run(withStdin: "4+7*3+2^7/3\n", output: expected, args: "-f", inf)
  }
  
  @Test func not() async throws {
    let expected = try fileContents("regress.not.out")
    try await run(withStdin: "foo\n", output: expected, args: "1!!s/foo/bar/")
  }
}
