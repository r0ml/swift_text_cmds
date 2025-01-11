// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import ShellTesting

@Suite(.serialized) class colrmTest  : ShellTest {

  let cmd = "colrm"
  let suite = "text_cmds_colrmTest"

  @Test func basic() async throws {
    let input = "abcdefgh\n12345678"
    try await run(withStdin: input, output: "abfgh\n12678", args: "3", "5")
  }

  @Test func large() async throws {
    let input = "abcdefgh\n12345678"
    try await run(withStdin: input, output: input, args: "108")
  }

  @Test func one() async throws {
    let input = "abcdefgh\n12345678"
    try await run(withStdin: input, output: "\n", args: "1")
  }

  @Test func one5() async throws {
    let input = "abcdefghij\n1234567890\nABCDEFGHIJ"
    let output = "abcd\n1234\nABCD"
    try await run(withStdin: input, output: output, args: "5")
  }

}
