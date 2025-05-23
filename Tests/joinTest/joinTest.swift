
// Generated by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

// $FreeBSD$

import ShellTesting

struct joinTest : ShellTest {
  let cmd = "join"
  let suiteBundle = "text_cmds_joinTest"
  
  @Test func only() async throws {
    let inp1 = try inFile("regress.1.in")
    let inp2 = try inFile("regress.2.in")
    let expected = try fileContents("regress.out")
    try await run( output: expected, args: "-t", ",", "-a1", "-a2", "-e", "(unknown)", "-o", "0,1.2,2.2", inp1, inp2)
  }

}
