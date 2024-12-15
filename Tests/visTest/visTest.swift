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

import Testing
import TestSupport
import Foundation

@Suite(.serialized) class visTest {

  let ex = "vis"
  
    @Test func basic1() async throws {
      let p = ShellProcess(ex, "-w", "-t")
      let (_, o, _) = try await p.run("\u{10}\n\t\n")
      #expect(o == "\\^P\\012\\011\\012")
    }

  @Test func basic2() async throws {
    let p = ShellProcess(ex, "-w", "-t", "-l")
    let (_, o, _) = try await p.run("\u{10}\n\t\n")
    #expect(o == "\\^P\\$\n\\011\\$\n")
  }
  
  
  
// ===========================================


  @Test func testBasicEncoding() async throws {
    let input = "Hello, World!"
    let expected = "Hello, World!"
    let p = ShellProcess(ex)
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testNonPrintableCharacters() async throws {
        let input = "Hello,\nWorld!"
        let expected = "Hello,\\nWorld!"
    let p = ShellProcess(ex, "-w", "-c")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
    }

  @Test func testEscapeCharacters() async throws {
    let input = "Hello\\World!"
    let expected = "Hello\\\\World!"
    let p = ShellProcess(ex, "-c")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testMultibyteCharacters() async throws {
    let input = "你好"
//    let expected = "\\xE4\\xBD\\xA0\\xE5\\xA5\\xBD"
    let expected = "\\344\\275\\240\\345\\245\\275"
    let p = ShellProcess(ex, "-o")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testMarkEndOfLine() async throws {
    let input = "Hello,\nWorld!"
    let expected = "Hello,\\$\nWorld!"
    let p = ShellProcess(ex, "-l")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  // FIXME: need to pass byte streams to run
  /*
  @Test func testInvalidMultibyteSequence() throws {
    let input = Data([0xC3, 0x28]) // Invalid UTF-8
    let expected = "\\xC3\\x28"
    let (_, o, _) = try run(c, x, [], input)
    #expect(o == expected)
  }
*/
  
  
  @Test func testFoldLines() async throws {
    let input = "This is a very long line that exceeds the fold width."
    let expected = "This is a very lon\\\ng line that exceed\\\ns the fold width.\\\n"
    let p = ShellProcess(ex, "-f", "-F", "20")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testCombineOptions() async throws {
    let input = "Line 1\nLine 2"
    let expected = "Line\\s1\\nLine\\s2"
    let p = ShellProcess(ex, "-M", "-c")
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }

  @Test func testEmptyInput() async throws {
    let input = ""
    let expected = ""
    let p = ShellProcess(ex)
    let (_, o, _) = try await p.run(input)
    #expect(o == expected)
  }
}

