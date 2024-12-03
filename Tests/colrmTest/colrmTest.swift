// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import Testing
import TestSupport
import Foundation

let orig = ProcessInfo.processInfo.environment["TEST_ORIGINAL"] != nil

@Suite(.serialized) class colrmTest {

  let cl : AnyClass? =  orig ? nil : colrmTest.self
  let ex = orig ? "/usr/bin/colrm" : "colrm"

  @Test func basic() async throws {
    let input = "abcdefgh\n12345678"
    let (_, o, _) = try captureStdoutLaunch(cl, ex, ["3", "5"], input)
    #expect(o == "abfgh\n12678")
  }

  @Test func large() async throws {
    let input = "abcdefgh\n12345678"
    let (_, o, _) = try captureStdoutLaunch(cl, ex, ["100"], input)
    #expect(o == input)
  }

  @Test func one() async throws {
    let input = "abcdefgh\n12345678"
    let (_, o, _) = try captureStdoutLaunch(cl, ex, ["1"], input)
    #expect(o == "\n")
  }

}
