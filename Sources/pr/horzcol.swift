// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-4-Clause

  Copyright (c) 1991 Keith Muller.
  Copyright (c) 1993
   The Regents of the University of California.  All rights reserved.

  This code is derived from software contributed to Berkeley by
  Keith Muller of the University of California, San Diego.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  3. All advertising materials mentioning features or use of this software
     must display the following acknowledgement:
   This product includes software developed by the University of
   California, Berkeley and its contributors.
  4. Neither the name of the University nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */

import CMigration

extension pr {
  // Print files with more than one column of output across a page
  func horzcol(_ options: CommandOptions) async throws(CmdErr) {
    var opts = options
    while let inf = nxtfile(&opts, dt: false) {
      defer { if inf != FileDescriptor.standardInput { try? inf.close() } }

      var ff = inf.bytes.lines.makeAsyncIterator()

      var eof = false
      var pagecnt = 1

      if opts.pgnm != 0 {
        // skip to specified page
        if try await inskip(&ff, opts.pgnm, opts.lines) {
          continue
        }
        pagecnt = options.pgnm
      }
      var lncnt = 0

      // loop by page
      while !eof {
        await ttypause(pagecnt, options: opts)

        var pag = [String]()
        for _ in 0..<options.lines {
          var lbuf : String
          // loop by line


          var linbuf : [String] = []
          for i in 0..<options.clcnt {
            // loop by col
            do {
              guard let lb = try await ff.next() else { eof = true; break }
              lbuf = lb
            } catch(let e) {
              break
            }
            linbuf.append(lbuf)
          }
          // now linbuf has a row worth of values
          if eof && linbuf.isEmpty  { break }
          if eof && linbuf.count < options.clcnt {
            linbuf.append(contentsOf: Array(repeating: "", count: options.clcnt-linbuf.count))
          }

          let lin = makelin(&lncnt, linbuf, options: opts)
          pag.append(lin)
        }

        try printPage(&pagecnt, pag, options:opts)
      }
    }
  }
}
