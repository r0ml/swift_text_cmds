// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import ShellTesting

@Suite() class unvisTest : ShellTest {

  let cmd = "unvis"
  let suiteBundle = "text_cmds_unvisTest"
  
    @Test(.disabled("No tests have been implemented")) func basic1() async throws {
      Issue.record("I have no tests")
    }
}

