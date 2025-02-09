// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file containing the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1992 Diomidis Spinellis.
  Copyright (c) 1992, 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Diomidis Spinellis of Imperial College, University of London.
 
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
 
   @(#)defs.h  8.1 (Berkeley) 6/6/93
  $FreeBSD$
 */

import Foundation

/**
 * Matches `enum e_atype` in defs.h
 * The way to siimulate a union in Swift is to use an enum with cases that
 * have associated data
 */
enum s_addr {
    case AT_RE(regex_t?)    // Line that matches RE
    case AT_LINE(UInt)     // Specific line
    case AT_RELLINE(UInt)  // Relative line
    case AT_LAST           // Last line
}

/**
 * Matches `struct s_subst` in defs.h
 */
class s_subst {
  var n: Int = 1             // Occurrence to substitute
  var p = false              // True if 'p' flag
  var icase: Bool = false    // True if 'I' flag
  var wfile: String? = nil   // wfile path, or nil
  
  var wfd: FileHandle? = nil   // Cached file for output (write)
  
  var re: regex_t? = nil     // Regular expression
                             
  // TODO: an alternative implementation that uses NSRegularExpression instead of regex_t
  //  var nsre : NSRegularExpression? = nil
  var maxbref: UInt = 0      // Largest backreference
  var linenum: Int = 0       // Line number
  var `new`: String? = nil   // Replacement text
}

/**
 * Matches `struct s_tr` in defs.h
 */
class s_tr {
  // The translation table for chars.
  // Instead of the C approach of using an array of 256 characters,
  // we use a Dictionary mapping the Characters
  // we co not need separate implementations for
  //    single and double-byte characters.
  var bytetab: [Character : Character] = [:]
}

// Emulates the union structure from the C version of s_command.u
enum command_u {
  case c([s_command])
  case s(s_subst)
  case y(s_tr)
  case fd(FileHandle?)
  case b(ArraySlice<Int>)
}

/**
 * Matches `struct s_command` in defs.h
 */
struct s_command {
  var a1: s_addr? = nil         // Start address
  var a2: s_addr? = nil         // End address
  var startline: Int = 0        // Start line number or zero

  var code: Character = "\0"    // Command code
  var nonsel = false            // True if '!'
  var u : command_u!
  var t: String = ""            // Text for : a c i r w
}

/**
 * Matches `enum e_args` in defs.h
 */
enum e_args {
    case EMPTY     // d, D, g, G, h, H, l, n, N, p, P, q, x, =, \0
    case TEXT      // a, c, i
    case NONSEL    // !
    case GROUP     // {
    case ENDGROUP  // }
    case COMMENT   // #
    case BRANCH    // b, t
    case LABEL     // :
    case RFILE     // r
    case WFILE     // w
    case SUBST     // s
    case TR        // y
}

/**
 * Matches `struct s_appends` in defs.h
 */
protocol Appendable {}
extension String : Appendable {}
extension URL : Appendable {}

/**
 * Matches `typedef struct { ... } SPACE` in defs.h
 */
struct SPACE {
  var space: String
  var deleted = false          // if deleted
  var append_newline = false    // if originally ended with newline
//    var back: UnsafeMutablePointer<CChar>? = nil   // backing memory
//    var blen: Int = 0                              // backing memory length
  
  init(_ space : String) {
    if space.last == "\n" {
      self.space = String(space.dropLast())
      self.append_newline = true
    } else {
      self.space = space
    }
  }
}
