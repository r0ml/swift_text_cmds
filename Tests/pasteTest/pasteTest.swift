// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite(.serialized) class pasteTest  : ShellTest {

  let cmd = "paste"
  let suiteBundle = "text_cmds_pasteTest"

  @Test func basic() async throws {
    Issue.record("No tests have been implemented")
  }
}
