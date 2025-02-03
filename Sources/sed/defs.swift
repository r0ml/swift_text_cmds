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
 */
enum s_addr {
    case AT_RE(regex_t?)    // Line that matches RE
    case AT_LINE(UInt)     // Specific line
    case AT_RELLINE(UInt)  // Relative line
    case AT_LAST           // Last line
}

/**
 * Equivalent to the union inside struct s_addr
 * Swift does not have C-style unions; we replicate with stored properties.
 */
/*
 class addrUnion {
    var l: UInt = 0          // For line number
    var r: NSRegularExpression? = nil // For the regex
}
*/
/*
enum addrUnion {
  case l(UInt)
  case r(regex_t)
}
*/

/**
 * Matches `struct s_addr` in defs.h
 */
/*
class s_addr {
    var type: e_atype = .AT_RE
  var u : addrUnion // = addrUnion()
  
  init(type: e_atype, u: addrUnion) {
    self.type = type
    self.u = u
  }
}
*/

/**
 * Matches `struct s_subst` in defs.h
 */
class s_subst {
    var n: Int = 0                  // Occurrence to substitute
    var p = false              // True if 'p' flag
    var icase: Bool = false         // True if 'I' flag
    var wfile: String? = nil        // wfile path, or nil

  var wfd: FileHandle? = nil           // Cached file for output (write)
  
    var re: regex_t? = nil // Regular expression
//  var nsre : NSRegularExpression? = nil
    var maxbref: UInt = 0           // Largest backreference
    var linenum: Int = 0           // Line number
    var `new`: String? = nil        // Replacement text
}

/**
 * Matches `struct s_tr` in defs.h
 *
 * In C, this has a `bytetab[256]` array plus a pointer to an array of `trmulti`.
 */
class s_tr {
    // The translation table for single-byte chars.
  var bytetab: [Character : Character] = [:] // Array(repeating: 0, count: 256)
    
    // The multi-character translation structure.
    class trmulti {
        var fromlen: Int = 0
        var from: [CChar] = Array(repeating: 0, count: Int(MB_LEN_MAX))
        var tolen: Int = 0
        var to: [CChar] = Array(repeating: 0, count: Int(MB_LEN_MAX))
    }
    
    var multis: [trmulti] = []
    var nmultis: Int = 0
}

enum command_u {
  case c([s_command])
  case s(s_subst)
  case y(s_tr)
  case fd(FileHandle?)
}

/**
 * Matches `struct s_command` in defs.h
 * In C, there is a union { ... } in `u`. We mirror that as multiple optionals.
 */
class s_command {
  //    var next: s_command? = nil       // Next command
  var a1: s_addr? = nil           // Start address
  var a2: s_addr? = nil           // End address
  var startline: Int = 0         // Start line number or zero

  var code: Character = "\0"      // Command code
  var nonsel = false         // True if '!'

  // The union from C: s_command.u
  // We replicate all possibilities as separate properties.
  var u : command_u!
  var t: String = ""           // Text for : a c i r w
  
  /*
   var c: s_command? = nil         // For b, t, { commands
   var s: s_subst? = nil           // For substitute (s) command
   var y: s_tr? = nil              // For transform (y) command
   var fd: Int32 = -1              // For 'w' command
   */
  
  // The C code uses `u_int nonsel:1;` as a bit field. We'll just store it as an Int.
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
enum AP_TYPE {
    case AP_STRING
    case AP_FILE
}

class s_appends {
    var type: AP_TYPE
    var s: String
    var len: Int
    
    init(type: AP_TYPE, s: String) {
        self.type = type
        self.s = s
        self.len = s.utf8.count
    }
}

/**
 * Matches `enum e_spflag` in defs.h
 */
enum e_spflag {
    case APPEND   // Append to the contents
    case REPLACE  // Replace the contents
}

/**
 * Matches `typedef struct { ... } SPACE` in defs.h
 */
struct SPACE {
  var space: String

  var deleted = false                           // if deleted
  var append_newline = false         // if originally ended with newline
//    var back: UnsafeMutablePointer<CChar>? = nil   // backing memory
//    var blen: Int = 0                              // backing memory length
  
  init(_ space : String) {
    self.space = space
  }
}
