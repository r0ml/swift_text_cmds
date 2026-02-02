// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite(.serialized) class ulTest  : ShellTest {

  let cmd = "ul"
  let suiteBundle = "text_cmds_ulTest"

  @Test func basic() async throws {
    Issue.record("No tests have been implemented yet")
  }
}

