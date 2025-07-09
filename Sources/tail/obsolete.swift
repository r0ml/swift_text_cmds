
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause

  Copyright (c) 1991, 1993
   The Regents of the University of California.  All rights reserved.

  This code is derived from software contributed to Berkeley by
  Edward Sze-Tyan Wang.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  3. Neither the name of the University nor the names of its contributors
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

extension tail {
  /*
   * Convert the obsolete argument form into something that getopt can handle.
   * This means that anything of the form [+-][0-9][0-9]*[lbc][Ffr] that isn't
   * the option argument for a -b, -c or -n option gets converted.
   */
  func obsolete(_ argv : ArraySlice<String>) throws(CmdErr) -> [String] {
    var tr = false
    var res = [String]()
    for ap in argv {
      if tr {
        res.append(ap)
        continue
      }

      // Return if "--" or not an option of any form.
      if ap.first != "-" {
        if ap.first != "+" {
          tr = true
          res.append(ap)
          continue
        }
      } else if ap.dropFirst().first == "-" {
        tr = true
        res.append(ap)
        continue
      }

      guard let k = ap.dropFirst().first else {
        tr = true
        res.append(ap)
        continue
      }

      switch k {
      /* Old-style option. */
        case "0"..."9":

          var tap = "-"
        /*
         * Go to the end of the option argument.  Save off any
         * trailing options (-3lf) and translate any trailing
         * output style characters.
         */
          var nap = ap
          let tt = nap.last!
        if tt == "F" || tt == "f" || tt == "r" {
          tap.append(tt)
          nap.removeLast()
        }
          let t = nap.last!
        switch t {
        case "b":
            tap.append("b")
            nap.removeLast()
        case "c":
            tap.append("c")
            nap.removeLast()
        case "l":
            nap.removeLast()
            fallthrough
          case "0"..."9":
            tap.append("n")
        default:
          throw CmdErr(1, "illegal option -- \(ap)")
        }
          res.append(tap)
          res.append(String(nap.dropFirst()))
        continue

      /*
       * Options w/ arguments, skip the argument and continue
       * with the next option.
       */
        case "b", "c", "n":
          res.append("-"+String(k))
          continue

          /* Options w/o arguments, continue with the next option. */
        case "F", "f", "r":
          res.append(ap)
        continue

      // Illegal option, return and let getopt handle it.
      default:
          res.append(ap)
          continue
      }
    }
    return res
  }
}
