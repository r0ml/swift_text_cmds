
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
import CMigration

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
  var lastch: UnicodeScalar? = nil // UnicodeScalar(0)
  var cnt: Int = 0
  var cclass: CharacterSet?
  var wctypex : wctype_t = 0
  var set: [UnicodeScalar] = []
  var equiv: [UnicodeScalar] = []
  var is_octal = false
  
  init(_ str: String) {
    self.originalStr = str
    self.str = Substring(str)
  }
  
  
  // Apple-Specific Collation Lookup Cache
  
  var collationWeightCache = [Int](repeating: -1, count: NCHARS_SB)
  var isWeightCached = false
  
  /// Retrieves the next character from a given STR object.
  func next() throws(CmdErr) -> Bool {
    is_octal = false
    
    switch state {
      case .eos:
        return false
      case .infinite:
        if str.isEmpty {
          state = .normal
          return true
        }
        return true
      case .normal:
        guard !str.isEmpty else {
          state = .eos
          return false
        }
        
        let ch = str.removeFirst()
        switch ch {
          case "\\":
            lastch = backslash()
          case "[":
            if try bracket() {
              return try next()
            }
            fallthrough
          default:
            // FIXME: what if there is a second unicode scalar for this character?
            lastch = ch.unicodeScalars.first!
        }
        
        // Handle Ranges
        if str.first == "-" {
          str.removeFirst()
          if genrange() {
            return try next()
          }
        }
        return true
      case .range:
        if cnt == 0 {
          state = .normal
          return try next()
        }
        cnt -= 1
        if lastch == nil {
          lastch = UnicodeScalar(0)
        } else {
          lastch = UnicodeScalar(lastch!.value + 1)!
        }
        return true
      case .sequence:
        if cnt == 0 {
          state = .normal
          return try next()
        }
        cnt -= 1
        return true
      case .cclass, .cclassUpper, .cclassLower:
        let nw = nextwctype( cnt == 0 ? -1 : Int32(lastch!.value), wctypex)
        cnt += 1
        if nw == -1 {
          lastch = nil
          cnt = 0
          state = .normal
          return try next()
        } else {
          lastch = UnicodeScalar(UInt32(nw))!
          return true
        }
        
        //        fatalError("next on cclass")
        /*
         let ch = nextwctype(wint_t(lastch.value), cclass!)
         if ch == -1 {
         state = .normal
         return next()
         }
         lastch = UnicodeScalar(ch)!
         return true
         */
      case .set:
        if cnt >= set.count {
          state = .normal
          return try next()
        }
        lastch = UnicodeScalar(set[cnt])
        cnt += 1
        return true
    }
  }
  
  /// Parses bracketed expressions in a pattern.
  func bracket() throws(CmdErr) -> Bool {
    guard !str.isEmpty else { return false }
    
    let nextChar = str.first
    
    switch nextChar {
      case ":": // [:class:]
        guard let p = str.firstIndex(of: "]") else { return false }
        guard str[str.index(before: p)] == ":" else {
          return gotoRepeat()
        }
        let nstr = str.suffix(from: p).dropFirst()
        
        let k = str.prefix(upTo: p).dropFirst().dropLast()
        genclass( String(k) )
        str = nstr
        return true
        
      case "=": // [=equiv=]
        
        guard let p = str.dropFirst(3).firstIndex(of: "]")  else {
          return false
        }
        if str[str.index(before: p)] != "=" {
          return gotoRepeat()
        }
        let nstr = str[...p].dropFirst(2).dropLast(2)
        if nstr.isEmpty {
          return gotoRepeat()
        }
        str = str.dropFirst(2)
        try genequiv()
        return true
      default:
        return gotoRepeat()
    }
    
    func gotoRepeat() -> Bool {
      guard let p = str.dropFirst(2).firstIndex(where: { "*]".contains($0) } ) else { return false }
      if str[p] != "*" || !str[p...].contains("]") {
        return false
      }
      str.removeFirst()
      genseq()
      return true
    }
    
    //    return false
  }
  
  /// Generates a character class.
  func genclass(_ className : String) {
    //    fatalError("\(#function) not implemented yet")
    cclass = classes[className]
    wctypex = wctype(className)
    //    cclass = CharacterSet(charactersIn: className)
    state = .cclass
    cnt = 0
  }
  
  
  /// Generates equivalent character set.
  func genequiv() throws(CmdErr) {
    throw CmdErr(1, "equivalent classes not implemented")
    // the original relies on __collate_lookup_l which is an internal function in libc and not available to me.
    // does the following expression work to simulate the desired outcome:
    // "e".compare("é", options: [.diacriticInsensitive, .widthInsensitive]).rawValue

    // if so, there is no way to do this in the current flow because there is no way to find the set of characters for which the "insensitive" compare yields true.
    // Either I have to run through all possible characters and generate such a list (which seems intensive)
    // or the flow which does the compare (and currently relies on a CharacterSet,
    // needs to change to use a "CharacterSetDescription" which implements different compare strategies for different members of the set.
    
    /*
    
    if str.first == "\\" {
      equiv[0] = backslash()
      if (str.first != "=") {
        throw CmdErr(1, "misplaced equivalence equals sign")
      }
      str = str.dropFirst(2)
    } else {
      equiv[0] = str.first!.unicodeScalars.first!
      if (str.dropFirst().first != "=") {
        throw CmdErr(1, "misplaced equivalence equals sign")
      }
      str = str.dropFirst(2)
    }
    
    /*
     * Partially supporting multi-byte locales; only finds equivalent
     * characters within the first NCHARS_SB entries of the
     * collation table
     */
    var tprim : Int32
    var tsec : Int32
    var len : Int32
    __collate_lookup_l(equiv, &len, &tprim, &tsec, LC_GLOBAL_LOCALE);
    
    if (tprim != -1) {
      for (p = 1, i = 1; i < NCHARS_SB; i++) {
        int cprim;
        if (is_weight_cached) {
          /*
           * retrieve primary weight from cache
           */
          cprim = collation_weight_cache[i];
        } else {
          /*
           * perform lookup of primary weight and fill cache
           */
          int csec;
          __collate_lookup_l((__darwin_wchar_t *)&i, &len, &cprim, &csec, LC_GLOBAL_LOCALE);
          collation_weight_cache[i] = cprim;
        }
        
        /*
         * If a character does not exist in the collation
         * table, just skip it
         */
        if (cprim == -1) {
          continue;
        }
        
        /*
         * Only compare primary weights to determine multi-byte
         * character equivalence
         */
        if (cprim == tprim) {
          s->equiv[p++] = i;
        }
      }
      s->equiv[p] = OOBCH;
      
      if (!is_weight_cached) {
        is_weight_cached = 1;
      }
    }
    cnt = 0;
    state = .set
    set = equiv
     
     */
  }
  
  /// Generates a range of characters.
  func genrange() -> Bool {
    let was_octal = is_octal
    is_octal = false
    let savestart = str
    guard !str.isEmpty else { return false }
    
    let stopval: UnicodeScalar
    
    if str.first == "\\" {
      str.removeFirst()
      stopval = backslash()
    } else {
      // FIXME: what if multiple unicode scalars?
      stopval = str.removeFirst().unicodeScalars.first!
    }
    
    if is_octal || was_octal || ___mb_cur_max() > 1 {
      if let lastch, stopval.value < lastch.value {
        // FIXME: what about savestart?
        str = savestart
        return false
      }
      state = .range
      let z = lastch == nil ? 0 : lastch!.value
      cnt = Int(stopval.value - z + 1)
      lastch = lastch!.value == 0 ? nil : UnicodeScalar(lastch!.value - 1)
      return true
    }
    if let lastch, stopval < lastch {
      str = savestart
      return false
    }
    cnt = 0
    state = .set
    set = (lastch!.value...stopval.value).map { UnicodeScalar($0)! }
    return true
  }
  
  func genseq() {
      var ep: String.Index?

      if str.first == "\\" {
          lastch = backslash()
      } else {
          let firstIndex = str.startIndex
          let clen = str[firstIndex].utf16.count

          if let scalar = str.unicodeScalars.first {
              lastch = scalar
              str.removeFirst(clen)
          } else {
              fatalError("Invalid character sequence")
          }
      }

      guard str.first == "*" else {
          fatalError("misplaced sequence asterisk")
      }

      str.removeFirst()

      switch str.first {
      case "\\":
          lastch = backslash()
          str.removeFirst()
      case "]":
          cnt = 0
          str.removeFirst()
      default:
          if let firstChar = str.first, firstChar.isNumber {
              if let numEndIndex = str.firstIndex(where: { !$0.isNumber }) {
                  let numStr = String(str[..<numEndIndex])
                  cnt = Int(numStr) ?? 0
                  ep = numEndIndex
                  
                  if ep != nil && str[ep!] == "]" {
                      str = str[str.index(after: ep!)...]
                  } else {
                      fatalError("illegal sequence count")
                  }
              }
          } else {
              fatalError("illegal sequence count")
          }
      }

      state = cnt > 0 ? .sequence : .infinite
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
      is_octal = true
      return UnicodeScalar(val) ?? "?"
    } else {
      is_octal = false
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

let classes = [
  "alnum" : CharacterSet.alphanumerics,
  "alpha" : CharacterSet.letters,
  "blank" : CharacterSet.whitespaces,
  "cntrl" : CharacterSet.controlCharacters,
  "digit" : CharacterSet.decimalDigits,
  "graph" : CharacterSet.symbols,
  "lower" : CharacterSet.lowercaseLetters,
  "print" : CharacterSet.symbols,
  "punct" : CharacterSet.punctuationCharacters,
  "space" : CharacterSet.whitespacesAndNewlines,
  "upper" : CharacterSet.uppercaseLetters,
  "xdigit" : CharacterSet.init(charactersIn: "0123456789ABCDEFabcdef")
  
]
