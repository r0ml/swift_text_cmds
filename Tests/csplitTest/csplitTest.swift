// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

/*
  Copyright (c) 2017 Conrad Meyer <cem@FreeBSD.org>
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */

import ShellTesting

@Suite(.serialized) class csplitTest : ShellTest {
  let cmd = "csplit"
  let suiteBundle = "text_cmds_csplitTest"
  
  @Test("Test an edge case where input has fewer lines than count") func lines_lt_count() async throws {
    let xf = try [
      tmpfile("expectfile00", """
one
two

"""),
      tmpfile("expectfile01", """
xxx 1
three
four

""")
      ,
      tmpfile("expectfile02", """
xxx 2
five
six

""")
    ]

    let inp = "one\ntwo\nxxx 1\nthree\nfour\nxxx 2\nfive\nsix\n"
    try await run(withStdin: inp, args: "-k", "-", "/xxx/", "{10}") { po in

      let cd = try self.tmpdir("")
      let ffx = [0,1,2].map { cd.appending("xx0\($0)") }

      #expect(po.code == 1, Comment(rawValue: po.error))
      for i in [0,1,2] {
        let aa = try xf[i].readAsString()
        let bb = try ffx[i].readAsString()
        #expect(aa == bb)
      }
      self.rm(xf + ffx)
    }
  }
  
  @Test("Basic regular expression split") func bre() async throws {
    let a = try tmpfile("sample.txt", "apple\nbanana\ncherry\ndate\n")
    try await run(status: 0, args: a, "/cherry/") { po in
      let cd = try self.tmpdir("")
      let aa = try cd.appending("xx00").readAsString()
      let bb = try cd.appending("xx01").readAsString()
      #expect(aa == "apple\nbanana\n")
      #expect(bb == "cherry\ndate\n")
    }
  }
}
