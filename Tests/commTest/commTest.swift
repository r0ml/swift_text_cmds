// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

// $FreeBSD$

import ShellTesting

@Suite(.serialized) class commTest : ShellTest {
  let cmd = "comm"
  let suiteBundle = "text_cmds_commTest"
  
  @Test(arguments: [0, 1, 2]) func test0(_ n : Int) async throws {
    let a = try inFile("regress.0\(n)a.in")
        let b = try inFile("regress.0\(n)b.in")
    let c = try fileContents("regress.0\(n).out")
    if n == 2 {
        try await run(output: c, args: a, b)
    } else {
      try await run(output: c, args: "-12", a, b)
    }
  }
}
