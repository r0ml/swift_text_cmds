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
  // Print files with more than one column of output and more than one file concurrently
  func mulfile(_ options: CommandOptions) async throws(CmdErr) {

    /*
     * do not know how many columns yet. The number of operands provide an
     * upper bound on the number of columns. We use the number of files
     * we can open successfully to set the number of columns. The operation
     * of the merge operation (-m) in relation to unsuccessful file opens
     * is unspecified by posix.
     */
    var opts = options
    var fbuf : [AsyncLineReader.AsyncIterator?] = []
    while let j = nxtfile(&opts, dt: true) {
      var k = j.bytes.lines.makeAsyncIterator()
      if opts.pgnm != 0 {
        if try await inskip(&k, opts.pgnm, opts.lines) {
          fbuf.append(nil)
        } else {
          fbuf.append(k)
        }
      } else {
        fbuf.append(k)
      }
    }

    // if no files, exit
    if fbuf.isEmpty {
      return
    }

    // calculate page boundaries based on open file count
    let clcnt = fbuf.count
    var prev_pgwd : Int

    if options.nmwd != 0 {

      // Overall page real estate is reduced by nmwd + 1 characters from the !nmwd case.
      opts.colwd = (opts.pgwd - clcnt - opts.nmwd)/clcnt

      /*
       * The page breaks down as follows:
       * - nmwd characters for line number
       * - 1 character for line number separator
       * - colwd columns per page (clcnt)
       * - 1 space per page (clcnt)
       */
      prev_pgwd = opts.pgwd
      opts.pgwd = ((opts.colwd + 1) * clcnt) + opts.nmwd

      assert(opts.pgwd <= prev_pgwd)
    } else {
      opts.colwd = (opts.pgwd + 1 - clcnt)/clcnt
      opts.pgwd = ((opts.colwd + 1) * clcnt) - 1
    }
    if (opts.colwd < 1) {
      throw CmdErr(1, "pr: page width too small for \(clcnt) columns")
    }

    // line buffer
    if opts.offst != 0 {
      // FIXME: what do I do here?
      //      (void)memset(buf, (int)' ', offst);
      //      (void)memset(hbuf, (int)' ', offst);
    }
    var pagecnt : Int = 1

    if opts.pgnm != 0 {
      pagecnt = opts.pgnm
    }

    var lncnt = 0
    var actf = fbuf.count(where: { $0 != nil })

    // continue to loop while any file still has data
    while actf > 0 {
      await ttypause(pagecnt, options: opts)

      var pg = [String]()

      // loop by line
      for _ in 0..<opts.lines {
        // loop by column
        var cols = [String]()
        for j in 0..<clcnt {
          var tl = ""
          if var h = fbuf[j] {
            do {
              if let tlx = try await h.next() {
                tl = tlx
                fbuf[j] = h
              } else {
                fbuf[j] = nil
                actf -= 1
              }
            } catch {
              fbuf[j] = nil
              actf -= 1
            }
          }
          cols.append(tl)
        }
        if actf == 0 { break }
        let lin = makelin(&lncnt, cols, options: opts)
        
        pg.append(lin)
      }
        // FIXME: set up some deferreds to close files back there

      try printPage(&pagecnt, pg, options:options)

      while !fbuf.isEmpty && fbuf.last == nil { fbuf.removeLast() }
    }
  }
}
