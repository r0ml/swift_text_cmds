
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
  var str : Substring
  var originalStr: String
  var lastch: UnicodeScalar = UnicodeScalar(0)
  var cnt: Int = 0
  var cclass: CharacterSet?
  var set: [Int] = []
  var equiv: [Int] = []
  var result = CharacterSet()
  
  init(_ str: String) {
    self.originalStr = str
    self.str = Substring(str)
    while let k = next() {
      result.formUnion(k)
    }
  }
  
  
  // Apple-Specific Collation Lookup Cache
  
  var collationWeightCache = [Int](repeating: -1, count: NCHARS_SB)
  var isWeightCached = false
  
  /// Retrieves the next character from a given STR object.
  func next() -> CharacterSet? {
    var isOctal = false
//    var ch: Int
    var wchar: UnicodeScalar?
    
    switch state {
      case .eos:
        return nil
      case .infinite:
        if str.isEmpty {
          state = .normal
          return true
        }
        return true
      case .normal:
        guard !str.isEmpty else {
          state = .eos
          return nil
        }
        
        let ch = str.removeFirst()
        switch ch {
          case "\\":
            lastch = backslash()
          case "[":
            if bracket() {
              return next()
            }
          default:
            lastch = ch
        }
        
        // Handle Ranges
        if str.first == "-",
           genrange() {
          return next()
        }
        return true
      case .range:
        if cnt == 0 {
          state = .normal
          return next()
        }
        cnt -= 1
        lastch = UnicodeScalar(s.lastch.value + 1)!
        return true
      case .sequence:
        if cnt == 0 {
          state = .normal
          return next()
        }
        cnt -= 1
        return true
      case .cclass, .cclassUpper, .cclassLower:
        cnt += 1
        ch = nextwctype(lastch.value, cclass!)
        if ch == -1 {
          state = .normal
          return next()
        }
        lastch = UnicodeScalar(ch)!
        return true
      case .set:
        if cnt >= set.count {
          state = .normal
          return next()
        }
        lastch = UnicodeScalar(set[cnt])!
        cnt += 1
        return true
    }
  }
  
  /// Parses bracketed expressions in a pattern.
  func bracket() -> Bool {
    guard !str.isEmpty else { return false }
    
    let nextChar = str.first
    
    switch nextChar {
      case ":":
        if let closingBracket = s.originalStr[s.str...].firstIndex(of:  "]") {
          if s.originalStr[s.originalStr.index(before: closingBracket)] == UInt8(ascii: ":") {
            s.str = s.originalStr.index(after: closingBracket)
            genclass(cn)
            return true
          }
        }
      case "=":
        if let closingBracket = s.originalStr[s.str...].firstIndex(of: UInt8(ascii: "]")) {
          if s.originalStr[s.originalStr.index(before: closingBracket)] == UInt8(ascii: "=") {
            s.str = s.originalStr.index(after: closingBracket)
            genequiv()
            return true
          }
        }
      default:
        break
    }
    
    return false
  }
  
  /// Generates a character class.
  func genclass(_ className : String) {
    cclass = CharacterSet(charactersIn: className)
    state = .cclass
    cnt = 0
  }
  
  
  /// Generates equivalent character set.
  func genequiv() {
    var char = lastch
    var equivalents: [UnicodeScalar] = [lastch]
    let LC_GLOBAL_LOCALE = locale_t(UnsafePointer(bitPattern: -1))
    // Mac-specific collation lookup
    var primaryWeight: Int = -1
    var z : UnsafePointer<Int32>?
    
    __collate_lookup_l(&char, &primaryWeight,
                       &z,
                       &z, LC_GLOBAL_LOCALE)
    
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
    
    set = equivalents
    state = .set
  }
  
  /// Generates a range of characters.
  func genrange(_ wasOctal: Bool) -> CharacterSet? {
    guard !str.isEmpty else { return nil }
    
    let stopval: UnicodeScalar
//    let originalStrIndex = s.str
//    var isOctal = false
    
    if str.first == "\\" {
      str.removeFirst()
      stopval = backslash()
    } else {
      stopval = str.removeFirst().unicodeScalars.first!
    }
    
/*    if wasOctal || isOctal {
      if stopval.value < lastch.value {
        return nil
      }
 */
      state = .range
      return CharacterSet(charactersIn: lastch...stopval)
//    }
    
    return nil
  }
  
  /// Processes escape sequences in a string.
  func backslash() -> UnicodeScalar {
    var val = 0
    var count = 0
    
    while let ch = str.first,
          let n = Array("01234567").firstIndex(of: ch) {
      val = val * 8 + n
      count += 1
      str.removeFirst()
      if count == 3 { break }
    }
    
    if count > 0 {
      return UnicodeScalar(val) ?? "?"
    }
    
    let ch = str.first
    switch ch  {
      case "n": str.removeFirst()
        return "\n"
      case "t": str.removeFirst()
        return "\t"
      case "r": str.removeFirst()
        return "\r"
      default: str.removeFirst()
        return (ch ?? "\0").unicodeScalars.first ?? "?"
    }
  }
}
