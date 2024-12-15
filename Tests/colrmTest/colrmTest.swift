// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import Testing
import TestSupport
import Foundation

@Suite(.serialized) class colrmTest {

  let ex = "colrm"

  @Test func basic() async throws {
    let input = "abcdefgh\n12345678"
    let p = ShellProcess(ex, "3", "5")
    let (_, o, _) = try await p.run(input)
    #expect(o == "abfgh\n12678")
  }

  @Test func large() async throws {
    let input = "abcdefgh\n12345678"
    let p = ShellProcess(ex, "108")
    let (_, o, _) = try await p.run(input)
    #expect(o == input)
  }

  @Test func one() async throws {
    let input = "abcdefgh\n12345678"
    let p = ShellProcess(ex, "1")
    let (_, o, _) = try await p.run(input)
    #expect(o == "\n")
  }

}
