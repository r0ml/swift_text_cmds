
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025 using ChatGPT
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1988, 1993
   The Regents of the University of California.  All rights reserved.
 
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

import Foundation

// Define Character Set Size
let NCHARS_SB = 256
let OOBCH = -1  // Out-Of-Bounds Character Placeholder

// Define Structure for Pattern Matching
class STR {
    enum State {
        case eos, infinite, normal, range, sequence, cclass, cclassUpper, cclassLower, set
    }
    
    var state: State = .normal
    var str: String.UTF8View.Index
    var originalStr: String.UTF8View
    var lastch: UnicodeScalar = UnicodeScalar(0)
    var cnt: Int = 0
    var cclass: CharacterSet?
    var set: [Int] = []
    var equiv: [Int] = []
    
    init(str: String) {
        self.originalStr = str.utf8
        self.str = self.originalStr.startIndex
    }
}

// Apple-Specific Collation Lookup Cache

var collationWeightCache = [Int](repeating: -1, count: NCHARS_SB)
var isWeightCached = false

/// Retrieves the next character from a given STR object.
func next(_ s: STR) -> Int {
    var isOctal = false
    var ch: Int
    var wchar: UnicodeScalar?
    
    switch s.state {
    case .eos:
        return 0
    case .infinite:
        if s.str >= s.originalStr.endIndex {
            s.state = .normal
            return 1
        }
        return 1
    case .normal:
        guard s.str < s.originalStr.endIndex else {
            s.state = .eos
            return 0
        }
        
        let currentChar = s.originalStr[s.str]
        s.str = s.originalStr.index(after: s.str)
        
        switch currentChar {
        case UInt8(ascii: "\\"):
            s.lastch = UnicodeScalar(backslash(s, &isOctal))!
        case UInt8(ascii: "["):
            if bracket(s) {
                return next(s)
            }
        default:
            s.lastch = UnicodeScalar(currentChar)
        }
        
        // Handle Ranges
        if s.str < s.originalStr.endIndex, s.originalStr[s.str] == UInt8(ascii: "-"),
           genrange(s, isOctal) {
            return next(s)
        }
        return 1
    case .range:
        if s.cnt == 0 {
            s.state = .normal
            return next(s)
        }
        s.cnt -= 1
        s.lastch = UnicodeScalar(s.lastch.value + 1)!
        return 1
    case .sequence:
        if s.cnt == 0 {
            s.state = .normal
            return next(s)
        }
        s.cnt -= 1
        return 1
    case .cclass, .cclassUpper, .cclassLower:
        s.cnt += 1
        ch = nextwctype(s.lastch.value, s.cclass!)
        if ch == -1 {
            s.state = .normal
            return next(s)
        }
        s.lastch = UnicodeScalar(ch)!
        return 1
    case .set:
        if s.cnt >= s.set.count {
            s.state = .normal
            return next(s)
        }
        s.lastch = UnicodeScalar(s.set[s.cnt])!
        s.cnt += 1
        return 1
    }
}

/// Parses bracketed expressions in a pattern.
func bracket(_ s: STR) -> Bool {
    guard s.str < s.originalStr.endIndex else { return false }
    
    let nextChar = s.originalStr[s.str]
    
    switch nextChar {
    case UInt8(ascii: ":"):
        if let closingBracket = s.originalStr[s.str...].firstIndex(of: UInt8(ascii: "]")) {
            if s.originalStr[s.originalStr.index(before: closingBracket)] == UInt8(ascii: ":") {
                s.str = s.originalStr.index(after: closingBracket)
                genclass(s)
                return true
            }
        }
    case UInt8(ascii: "="):
        if let closingBracket = s.originalStr[s.str...].firstIndex(of: UInt8(ascii: "]")) {
            if s.originalStr[s.originalStr.index(before: closingBracket)] == UInt8(ascii: "=") {
                s.str = s.originalStr.index(after: closingBracket)
                genequiv(s)
                return true
            }
        }
    default:
        break
    }
    
    return false
}

/// Generates a character class.
func genclass(_ s: STR) {
    let className = String(utf8String: s.originalStr[s.str...]) ?? ""
    s.cclass = CharacterSet(charactersIn: className)
    s.state = .cclass
    s.cnt = 0
}

/// Generates equivalent character set.
func genequiv(_ s: STR) {
    let char = s.lastch
    var equivalents: [Int] = [Int(char.value)]
    
    #if os(macOS)
    // Mac-specific collation lookup
    var primaryWeight: Int = -1
    __collate_lookup_l(&char, &primaryWeight, nil, nil, LC_GLOBAL_LOCALE)
    
    if primaryWeight != -1 {
        for i in 1..<NCHARS_SB {
            var candidatePrimaryWeight: Int
            if isWeightCached {
                candidatePrimaryWeight = collationWeightCache[i]
            } else {
                __collate_lookup_l(UnicodeScalar(i), &candidatePrimaryWeight, nil, nil, LC_GLOBAL_LOCALE)
                collationWeightCache[i] = candidatePrimaryWeight
            }
            
            if candidatePrimaryWeight == primaryWeight {
                equivalents.append(i)
            }
        }
        
        isWeightCached = true
    }
    #endif
    
    s.set = equivalents
    s.state = .set
}

/// Generates a range of characters.
func genrange(_ s: STR, _ wasOctal: Bool) -> Bool {
    guard s.str < s.originalStr.endIndex else { return false }
    
    let stopval: UnicodeScalar
    let originalStrIndex = s.str
    var isOctal = false
    
    if s.originalStr[s.str] == UInt8(ascii: "\\") {
        s.str = s.originalStr.index(after: s.str)
        stopval = UnicodeScalar(backslash(s, &isOctal))!
    } else {
        stopval = UnicodeScalar(s.originalStr[s.str])
        s.str = s.originalStr.index(after: s.str)
    }
    
    if wasOctal || isOctal {
        if stopval.value < s.lastch.value {
            s.str = originalStrIndex
            return false
        }
        s.cnt = Int(stopval.value - s.lastch.value) + 1
        s.state = .range
        return true
    }
    
    return false
}

/// Processes escape sequences in a string.
func backslash(_ s: STR, _ isOctal: inout Bool) -> Int {
    var val = 0
    var count = 0
    isOctal = false
    
    while let ch = s.originalStr[s.str...].first, ch.isNumber && ch <= UInt8(ascii: "7") {
        val = val * 8 + Int(ch - UInt8(ascii: "0"))
        count += 1
        s.str = s.originalStr.index(after: s.str)
        if count == 3 { break }
    }
    
    if count > 0 {
        isOctal = true
        return val
    }
    
    switch s.originalStr[s.str] {
    case UInt8(ascii: "n"): s.str = s.originalStr.index(after: s.str); return 10
    case UInt8(ascii: "t"): s.str = s.originalStr.index(after: s.str); return 9
    case UInt8(ascii: "r"): s.str = s.originalStr.index(after: s.str); return 13
    default: return Int(s.originalStr[s.str])
    }
}
