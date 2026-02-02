// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite(.serialized) class expandTest  : ShellTest {

  let cmd = "expand"
  let suiteBundle = "text_cmds_expandTest"

  @Test func basic() async throws {
    Issue.record("No tests have been implemented yet")
  }
}
