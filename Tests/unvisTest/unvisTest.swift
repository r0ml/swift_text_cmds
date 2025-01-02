// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024

import Testing
import TestSupport
import Foundation

@Suite(.serialized) class unvisTest : ShellTest {

  let cmd = "unvis"
  let suite = "unvisTest"
  
    @Test func basic1() async throws {
      try await run(withStdin: "\u{10}\n\t\n", output: "\\^P\\012\\011\\012", args: ["-w", "-t"])
    }

  @Test func basic2() async throws {
    try await run(withStdin: "\u{10}\n\t\n", output: "\\^P\\$\n\\011\\$\n", args: ["-w", "-t", "-l"])
  }
  
// ===========================================

  @Test func testBasicEncoding() async throws {
    let input = "Hello, World!"
    let expected = "Hello, World!"
    try await run(withStdin: input, output: expected)
  }

  @Test func testNonPrintableCharacters() async throws {
        let input = "Hello,\nWorld!"
        let expected = "Hello,\\nWorld!"
    try await run(withStdin: input, output: expected, args: "-w", "-c")
    }

  @Test func testEscapeCharacters() async throws {
    let input = "Hello\\World!"
    let expected = "Hello\\\\World!"
    try await run(withStdin: input, output: expected, args: "-c")
  }

  @Test func testMultibyteCharacters() async throws {
    let input = "你好"
//    let expected = "\\xE4\\xBD\\xA0\\xE5\\xA5\\xBD"
    let expected = "\\344\\275\\240\\345\\245\\275"
    let p = ShellProcess(cmd, "-o")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testMarkEndOfLine() async throws {
    let input = "Hello,\nWorld!"
    let expected = "Hello,\\$\nWorld!"
    try await run(withStdin: input, output: expected, args: "-l")
  }

  // FIXME: encoding issues here
  @Test func testInvalidMultibyteSequence() async throws {
    let input = Data([0xC3, 0x28]) // Invalid UTF-8
//    let expected = "\\xC3\\x28"
    let expected = "\\M-C("
    try await run(withStdin: input, output: expected)
  }
  
  
  @Test func testFoldLines() async throws {
    let input = "This is a very long line that exceeds the fold width."
    let expected = "This is a very lon\\\ng line that exceed\\\ns the fold width.\\\n"
    try await run(withStdin: input, output: expected, args: "-f", "-F", "20")
  }

  @Test func testCombineOptions() async throws {
    let input = "Line 1\nLine 2"
    let expected = "Line\\s1\\nLine\\s2"
    try await run(withStdin: input, output: expected, args: "-M", "-c")
  }

  @Test func testEmptyInput() async throws {
    try await run(withStdin: "", output: "" )
  }
}

