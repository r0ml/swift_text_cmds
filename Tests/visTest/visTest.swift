/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz <code@liberally.net>

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */

import ShellTesting

@Suite() class visTest : ShellTest {

  let cmd = "vis"
  let suiteBundle = "text_cmds_visTest"
  
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
    try await run(withStdin: input, output: expected, args: "-o")
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

