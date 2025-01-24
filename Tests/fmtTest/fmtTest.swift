
// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import ShellTesting

@Suite(.serialized) class fmtTest  : ShellTest {

  let cmd = "fmt"
  let suiteBundle = "text_cmds_fmtTest"

  @Test func basic() async throws {
    let input = "The merit of all things\nlies\nin their difficulty\n"
    let op = """
                     The merit of all things
                               lies
                       in their difficulty

"""
    try await run(withStdin: input, output: op, args: "-c")
  }
}
