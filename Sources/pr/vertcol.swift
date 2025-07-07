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
  // vertcol:  print files with more than one column of output down a page
  func vertcol(_ options : CommandOptions) async throws(CmdErr) {

    let col = options.colwd + 1

    let mxlen = options.pgwd + options.offst + 1
    let fullcol = options.nmwd != 0 ? options.colwd + 1 + options.nmwd + 1 : options.colwd + 1

    var pagecnt = 1

    // loop by file
    var opts = options
    while let inf = nxtfile(&opts, dt: false) {
      defer { if inf != FileDescriptor.standardInput { try? inf.close() } }

      var ff = inf.bytes.lines.makeAsyncIterator()

      var lncnt = 0

      if options.pgnm != 0 {
        // skip to requested page
        if try await inskip(&ff, options.pgnm, options.lines) {
          continue
        }
        pagecnt = options.pgnm
      }

      var eof = false
      // loop by page
      while !eof {

        await ttypause(pagecnt, options: opts)

        // loop by column
        var vc : [[String]] = []

        for i in 0..<options.clcnt {
          var linecnt = 0
          var vcx : [String] = []

          // loop by line
          while linecnt < options.lines {
            var lbuf : String

            do {
              guard let lb = try await ff.next() else {
                eof = true ; break }
              lbuf = lb
            } catch (let e) {
              break
            }

            vcx.append(lbuf)
            linecnt += 1
          }
          // Add a column
          vc.append(vcx)
        }

        var vr : [[String]] = []

        // vc now has some either all the columns for a full page,
        // or some full columns for a page, a partial column, and is
        // missing columns, because I ran out of lines.  The page
        // will need to be rebalanced.  Obviously this only happens at eof

        if eof {
          /*
           * when -t (no header) is specified the spec requires
           * the min number of lines. The last page may not have
           * balanced length columns. To fix this we must reorder
           * the columns. This is a very slow technique so it is
           * only used under limited conditions. Without -t, the
           * balancing of text columns is unspecified.
           */
          let k = vc.flatMap { $0 }
          let cnt = k.count
          if cnt == 0 { break }
          let trc = 1 + (cnt - 1) / options.clcnt

          for i in 0..<trc {
            let ii = i * trc
            var tr : [String] = []
            for j in 0..<options.clcnt {
              let m = ii + j
              tr.append( m >= k.count ? "" : k[ii+j])
            }
            vr.append(tr)
          }
        } else {
          // Now, transpose the vc array so that each element is a row
          // instead of a column
          for i in 0..<vc[0].count {
            vr.append( vc.map { $0[i] } )
          }
        }

        let pg = vr.map { makelin(&lncnt, $0, options: opts) }
        try printPage(&pagecnt, pg, options: opts)
      }
    }

  }
}
