// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import ShellTesting

@Suite(.serialized) class revTest  : ShellTest {

  let cmd = "rev"
  let suiteBundle = "text_cmds_revTest"

  @Test func basic() async throws {
    let input = """
    The merit of all things
    lies
    in their difficulty
    
    """
    
    let op = """
sgniht lla fo tirem ehT
seil
ytluciffid rieht ni

"""
    try await run(withStdin: input, output: op)
  }
}
