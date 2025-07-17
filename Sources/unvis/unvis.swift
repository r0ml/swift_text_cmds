
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  Copyright (c) 1989, 1993
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


import CMigration

import Darwin

// copied from vis.swift
struct visOptions : OptionSet {
  var rawValue : Int = 0
  
  static let OCTAL = visOptions(rawValue: 1 << 0) // use octal \ddd format
  static let CSTYLE = visOptions(rawValue: 1 << 1) // use \[nrft0..] where appropriate
  
  // to alter set of characters encoded (default is to encode all
  // non-graphic except space, tab, and newline).
  static let SP = visOptions(rawValue: 1 << 2) // also encode space
  static let TAB = visOptions(rawValue: 1 << 3) // also encode tab
  static let NL = visOptions(rawValue: 1 << 4) // also encode newline
  
  static let WHITE : visOptions = [.SP, .TAB, .NL]
  
  static let SAFE = visOptions(rawValue: 1 << 5) // only encode "unsafe" characters
  static let DQ = visOptions(rawValue: 1 << 15)
  
  static let NOSLASH = visOptions(rawValue: 1 << 6)
  
  static let HTTPSTYLE = visOptions(rawValue: 1 << 7) // http-style escape % hex hex
  static let GLOB = visOptions(rawValue: 1 << 8) // encode glob(3) magic characters
  static let MIMESTYLE = visOptions(rawValue: 1 << 9) // mime-style escape = HEX HEX
  static let HTTP1866 = visOptions(rawValue: 1 << 10) // http-style &#num; or &string;
  static let NOESCAPE = visOptions(rawValue: 1 << 11) // don't decode `\'
  
  static let _END = visOptions(rawValue: 1 << 12) // for unvis
  static let SHELL = visOptions(rawValue: 1 << 13) // encode shell special characters [not glob]
  
  static let META : visOptions = [.WHITE, .GLOB, .SHELL]
  
  static let NOLOCALE = visOptions(rawValue: 1 << 14) // encode using the C locale
}

@main final class unvis : ShellCommand {
  
  var usage : String = "Usage: %s [-e] [-Hh | -m] [file...]"
  
  struct CommandOptions {
    var eflags : visOptions = []
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "eHhm"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        case "e": options.eflags.insert(.NOESCAPE)
        case "H": options.eflags.insert(.HTTP1866)
        case "h": options.eflags.insert(.HTTPSTYLE)
        case "m": options.eflags.insert(.MIMESTYLE)
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    
    if options.eflags.contains(.MIMESTYLE) && (options.eflags.contains(.HTTP1866) || options.eflags.contains(.HTTP1866)) {
      throw CmdErr(1, "Can't mix -m wth -h and/or -H")
    }
    
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    if options.args.isEmpty {
      try await process(FileDescriptor.standardInput, "<stdin>", options.eflags)
    } else {
      for arg in options.args {
//        let u = URL(filePath: arg)
        do {
          let fh = try FileDescriptor(forReading: arg)
          try await process(fh, arg, options.eflags)
        } catch(let e) {
          warn( "\(arg): \(e)" )
        }
      }
    }
  }
  
  func process(_ fh : FileDescriptor, _ filename: String, _ eflags: visOptions) async throws(CmdErr) {
    var offset = 0
//    var c: Int32
//    var ret: Int32
    var state : (n: Int, state: unvis.state) = (0, state.S_GROUND)
    var outc: Character = "\0"
    
    do {
      for try await c in fh.characters {
        offset += 1
//      again:
        let cc = c.unicodeScalars.first!.value
        let uu = UnicodeScalar(cc)!
        let ret = unvis(&outc, uu, &state, eflags)
        switch ret {
          case .VALID:
            print(outc, terminator: "")
          case .VALIDPUSH:
            print(outc, terminator: "")
            offset -= 1
            continue
          case .SYNBAD:
            var se = FileDescriptor.standardError
            print("\(filename): offset: \(offset): can't decode", to: &se)
            state = (0, .S_GROUND)
          case .ZERO, .NOCHAR:
            break
          default:
            fatalError("bad return value (\(ret)), can't happen")
        }
      }
      
      if unvis(&outc, "\0", &state, eflags.union(._END)) == .VALID {
        print(outc, terminator: "")
      }
      
    } catch(let e) {
      throw CmdErr(1, "Error reading \(filename)")
    }
  }
  
  
  // ================================================
  // from unvis.c in Libc/gen/FreeBSD
  
  /*
   * decode driven by state machine
   */
  enum state : Int {
    case S_GROUND =  0  /* haven't seen escape char */
    case S_START =    1  /* start decoding special sequence */
    case S_META =    2  /* metachar started (M) */
    case S_META1 =    3  /* metachar more, regular char (-) */
    case S_CTRL =    4  /* control char started (^) */
    case S_OCTAL2 =  5  /* octal digit 2 */
    case S_OCTAL3 =  6  /* octal digit 3 */
    case S_HEX =    7  /* mandatory hex digit */
    case S_HEX1 =    8  /* http hex digit */
    case S_HEX2 =    9  /* http hex digit 2 */
    case S_MIME1 =    10  /* mime hex digit 1 */
    case S_MIME2 =    11  /* mime hex digit 2 */
    case S_EATCRNL =  12  /* mime eating CRNL */
    case S_AMP =    13  /* seen & */
    case S_NUMBER =  14  /* collecting number */
    case S_STRING =  15  /* collecting string */
  }
  
  //  #define  XTOD(c)    (isdigit(c) ? (c - '0') : ((c - 'A') + 10))
  
  /*
   * RFC 1866
   */
  var nv : [ (String , UnicodeScalar ) ] =
  [ ( "AElig" ,  UnicodeScalar( 198 )), // capital AE diphthong (ligature)
    ( "Aacute" , UnicodeScalar( 193 )), // capital A, acute accent
    ( "Acirc" , UnicodeScalar( 194 )),  // capital A, circumflex accent
    ( "Agrave" , UnicodeScalar( 192 )), // capital A, grave accent
    ( "Aring" , UnicodeScalar( 197 )),  // capital A, ring
    ( "Atilde" , UnicodeScalar( 195 )), // capital A, tilde
    ( "Auml" , UnicodeScalar( 196 )),   // capital A, dieresis or umlaut mark
    ( "Ccedil" , UnicodeScalar( 199 )), // capital C, cedilla
    ( "ETH" , UnicodeScalar( 208 )),    // capital Eth, Icelandic
    ( "Eacute" , UnicodeScalar( 201 )), // capital E, acute accent
    ( "Ecirc" , UnicodeScalar( 202 )),  // capital E, circumflex accent
    ( "Egrave" , UnicodeScalar( 200 )), // capital E, grave accent
    ( "Euml" , UnicodeScalar( 203 )),   // capital E, dieresis or umlaut mark
    ( "Iacute" , UnicodeScalar( 205 )), // capital I, acute accent
    ( "Icirc" , UnicodeScalar( 206 )),  // capital I, circumflex accent
    ( "Igrave" , UnicodeScalar( 204 )), // capital I, grave accent
    ( "Iuml" , UnicodeScalar( 207 )),   // capital I, dieresis or umlaut mark
    ( "Ntilde" , UnicodeScalar( 209 )), // capital N, tilde
    ( "Oacute" , UnicodeScalar( 211 )), // capital O, acute accent
    ( "Ocirc" , UnicodeScalar( 212 )),  // capital O, circumflex accent
    ( "Ograve" , UnicodeScalar( 210 )), // capital O, grave accent
    ( "Oslash" , UnicodeScalar( 216 )), // capital O, slash
    ( "Otilde" , UnicodeScalar( 213 )), // capital O, tilde
    ( "Ouml" , UnicodeScalar( 214 )),   // capital O, dieresis or umlaut mark
    ( "THORN" , UnicodeScalar( 222 )),  // capital THORN, Icelandic
    ( "Uacute" , UnicodeScalar( 218 )), // capital U, acute accent
    ( "Ucirc" , UnicodeScalar( 219 )),  // capital U, circumflex accent
    ( "Ugrave" , UnicodeScalar( 217 )), // capital U, grave accent
    ( "Uuml" , UnicodeScalar( 220 )),   // capital U, dieresis or umlaut mark
    ( "Yacute" , UnicodeScalar( 221 )), // capital Y, acute accent
    ( "aacute" , UnicodeScalar( 225 )), // small a, acute accent
    ( "acirc" , UnicodeScalar( 226 )),  // small a, circumflex accent
    ( "acute" , UnicodeScalar( 180 )),  // acute accent
    ( "aelig" , UnicodeScalar( 230 )),  // small ae diphthong (ligature)
    ( "agrave" , UnicodeScalar( 224 )), // small a, grave accent
    ( "amp" , UnicodeScalar(  38 )),    // ampersand
    ( "aring" , UnicodeScalar( 229 )),  // small a, ring
    ( "atilde" , UnicodeScalar( 227 )), // small a, tilde
    ( "auml" , UnicodeScalar( 228 )),   // small a, dieresis or umlaut mark
    ( "brvbar" , UnicodeScalar( 166 )), // broken (vertical) bar
    ( "ccedil" , UnicodeScalar( 231 )), // small c, cedilla
    ( "cedil" , UnicodeScalar( 184 )),  // cedilla
    ( "cent" , UnicodeScalar( 162 )),   // cent sign
    ( "copy" , UnicodeScalar( 169 )),   // copyright sign
    ( "curren" , UnicodeScalar( 164 )), // general currency sign
    ( "deg" , UnicodeScalar( 176 )),    // degree sign
    ( "divide" , UnicodeScalar( 247 )), // divide sign
    ( "eacute" , UnicodeScalar( 233 )), // small e, acute accent
    ( "ecirc" , UnicodeScalar( 234 )),  // small e, circumflex accent
    ( "egrave" , UnicodeScalar( 232 )), // small e, grave accent
    ( "eth" , UnicodeScalar( 240 )),    // small eth, Icelandic
    ( "euml" , UnicodeScalar( 235 )),   // small e, dieresis or umlaut mark
    ( "frac12" , UnicodeScalar( 189 )), // fraction one-half
    ( "frac14" , UnicodeScalar( 188 )), // fraction one-quarter
    ( "frac34" , UnicodeScalar( 190 )), // fraction three-quarters
    ( "gt" , UnicodeScalar(    62 )),   // greater than
    ( "iacute" , UnicodeScalar( 237 )), // small i, acute accent
    ( "icirc" , UnicodeScalar( 238 )),  // small i, circumflex accent
    ( "iexcl" , UnicodeScalar( 161 )),  // inverted exclamation mark
    ( "igrave" , UnicodeScalar( 236 )), // small i, grave accent
    ( "iquest" , UnicodeScalar( 191 )), // inverted question mark
    ( "iuml" , UnicodeScalar( 239 )),   // small i, dieresis or umlaut mark
    ( "laquo" , UnicodeScalar( 171 )),  // angle quotation mark, left
    ( "lt" , UnicodeScalar(    60 )),   // less than
    ( "macr" , UnicodeScalar( 175 )),   // macron
    ( "micro" , UnicodeScalar( 181 )),  // micro sign
    ( "middot" , UnicodeScalar( 183 )), // middle dot
    ( "nbsp" , UnicodeScalar( 160 )),   // no-break space
    ( "not" , UnicodeScalar( 172 )),    // not sign
    ( "ntilde" , UnicodeScalar( 241 )), // small n, tilde
    ( "oacute" , UnicodeScalar( 243 )), // small o, acute accent
    ( "ocirc" , UnicodeScalar( 244 )),  // small o, circumflex accent
    ( "ograve" , UnicodeScalar( 242 )), // small o, grave accent
    ( "ordf" , UnicodeScalar( 170 )),   // ordinal indicator, feminine
    ( "ordm" , UnicodeScalar( 186 )),   // ordinal indicator, masculine
    ( "oslash" , UnicodeScalar( 248 )), // small o, slash
    ( "otilde" , UnicodeScalar( 245 )), // small o, tilde
    ( "ouml" , UnicodeScalar( 246 )),   // small o, dieresis or umlaut mark
    ( "para" , UnicodeScalar( 182 )),   // pilcrow (paragraph sign)
    ( "plusmn" , UnicodeScalar( 177 )), // plus-or-minus sign
    ( "pound" , UnicodeScalar( 163 )),  // pound sterling sign
    ( "quot" , UnicodeScalar(  34 )),   // double quote
    ( "raquo" , UnicodeScalar( 187 )),  // angle quotation mark, right
    ( "reg" , UnicodeScalar( 174 )),    // registered sign
    ( "sect" , UnicodeScalar( 167 )),   // section sign
    ( "shy" , UnicodeScalar( 173 )),    // soft hyphen
    ( "sup1" , UnicodeScalar( 185 )),   // superscript one
    ( "sup2" , UnicodeScalar( 178 )),   // superscript two
    ( "sup3" , UnicodeScalar( 179 )),   // superscript three
    ( "szlig" , UnicodeScalar( 223 )),  // small sharp s, German (sz ligature)
    ( "thorn" , UnicodeScalar( 254 )),  // small thorn, Icelandic
    ( "times" , UnicodeScalar( 215 )),  // multiply sign
    ( "uacute" , UnicodeScalar( 250 )), // small u, acute accent
    ( "ucirc" , UnicodeScalar( 251 )),  // small u, circumflex accent
    ( "ugrave" , UnicodeScalar( 249 )), // small u, grave accent
    ( "uml" , UnicodeScalar( 168 )),    // umlaut (dieresis)
    ( "uuml" , UnicodeScalar( 252 )),   // small u, dieresis or umlaut mark
    ( "yacute" , UnicodeScalar( 253 )), // small y, acute accent
    ( "yen" , UnicodeScalar( 165 )),    // yen sign
    ( "yuml" , UnicodeScalar( 255 )),   // small y, dieresis or umlaut mark
  ]
  
  /*
   * unvis return codes
   */
  enum unvisReturns : Int {
    case ZERO = 0
    case VALID = 1 // character valid
    case VALIDPUSH = 2 // character valid, push back passed char
    case NOCHAR = 3 // valid sequence, no character produced
    case SYNBAD = -1 // unrecognized escape sequence
    case ERROR = -2  // decode in unknown state (unrecoverable)
  }
  
  /*
   * unvis - decode characters previously encoded by vis
   */
  func
  unvis(_ cp : inout Character, _ cc : UnicodeScalar, _ astate : inout (n: Int, state: state), _ flag : visOptions) -> unvisReturns
  {
    //    unsigned char st, ia, is, lc;
    
    let c = Character(cc)
    let uc = c
    /*
     * Bottom 8 bits of astate hold the state machine state.
     * Top 8 bits hold the current character in the http 1866 nv string decoding
     */
    
    let st = astate.1
    if flag.contains(._END) {
      switch st {
        case .S_OCTAL2, .S_OCTAL3, .S_HEX2:
          astate = (0, .S_GROUND)
          return .VALID
        case .S_GROUND:
          return .NOCHAR
        default:
          return .SYNBAD
      }
    }
    
    switch (st) {
        
      case .S_GROUND:
        cp = "\0"
        if ((!flag.contains(.NOESCAPE)) && c == "\\") {
          astate = (0, .S_START)
          return .NOCHAR
        }
        if (flag.contains(.HTTPSTYLE) && c == "%") {
          astate = (0, .S_HEX1)
          return .NOCHAR
        }
        if (flag.contains(.HTTP1866) && c == "&") {
          astate = (0, .S_AMP)
          return .NOCHAR
        }
        if (flag.contains(.MIMESTYLE) && c == "=") {
          astate = (0, .S_MIME1)
          return .NOCHAR
        }
        cp = c
        return .VALID
        
      case .S_START:
        switch(c) {
          case "\\":
            cp = c
            astate = (0, .S_GROUND)
            return .VALID
          case "0", "1", "2", "3", "4", "5", "6", "7":
            cp = Character(UnicodeScalar(cc.value - 0x30)!)
            astate = (0, .S_OCTAL2)
            return .NOCHAR
          case "M":
            cp = Character(UnicodeScalar(0x80))
            astate = (0, .S_META)
            return .NOCHAR
          case "^":
            astate = (0, .S_CTRL)
            return .NOCHAR
          case "n":
            cp = "\n"
            astate = (0, .S_GROUND)
            return .VALID
          case "r":
            cp = "\r"
            astate = (0, .S_GROUND)
            return .VALID
          case "b":
            cp = "\u{08}"
            astate = (0, .S_GROUND)
            return .VALID
          case "a":
            cp = "\u{07}"
            astate = (0, .S_GROUND)
            return .VALID
          case "v":
            cp = "\u{0b}"
            astate = (0, .S_GROUND)
            return .VALID
          case "t":
            cp = "\t"
            astate = (0, .S_GROUND)
            return .VALID
          case "f":
            cp = "\u{0c}"
            astate = (0, .S_GROUND)
            return .VALID
          case "s":
            cp = " "
            astate = (0, .S_GROUND)
            return .VALID
          case "E":
            cp = "\u{1b}"
            astate = (0, .S_GROUND)
            return .VALID;
          case "x":
            astate = (0, .S_HEX)
            return .NOCHAR
          case "\n":
            // hidden newline
            astate = (0, .S_GROUND)
            return .NOCHAR
          case "$":
            // hidden marker
            astate = (0, .S_GROUND)
            return .NOCHAR
          default:
            if 0 != Darwin.isgraph(Int32(cc.value) ) {
              cp = c
              astate = (0, .S_GROUND)
              return .VALID
            }
        }
        break
        
      case .S_META:
        if (c == "-") {
          astate = (0, .S_META1)
        }
        else if (c == "^") {
          astate = (0, .S_CTRL)
        } else {
          break
        }
        return .NOCHAR
        
      case .S_META1:
        astate = (0, .S_GROUND)
        cp = Character(UnicodeScalar(cp.unicodeScalars.first!.value | cc.value)!)
        // maybe it is just:  cp = c
        return .VALID
        
      case .S_CTRL:
        if (c == "?") {
          let x = cp.unicodeScalars.first!.value
          cp = Character(UnicodeScalar(x | 0x7f)!)
        } else {
          let x = cp.unicodeScalars.first!.value
          cp = Character(UnicodeScalar( x | ( cc.value & 0x1f ) )!)
        }
        astate = (0, .S_GROUND)
        return .VALID
        
      case .S_OCTAL2:  /* second possible octal digit */
        if "01234567".contains(uc) {
          
          // yes - and maybe a third
          cp = Character(UnicodeScalar((cp.unicodeScalars.first!.value << 3) + (cc.value - 0x30))!)
          astate = (0, .S_OCTAL3)
          return .NOCHAR;
        }
        
        // no - done with current sequence, push back passed char
        astate = (0, .S_GROUND)
        return .VALIDPUSH
        
      case .S_OCTAL3:  /* third possible octal digit */
        astate = (0, .S_GROUND)
        if "01234567".contains(uc) {
          cp = Character(UnicodeScalar((cp.unicodeScalars.first!.value << 3) + (cc.value - 0x30))!)
          return .VALID
        }
        // we were done, push back passed char
        return .VALIDPUSH
        
      case .S_HEX:
        if (!"0123456789ABCDEFabcdef".contains(uc)) {
          break
        }
        fallthrough
      case .S_HEX1:
        if "0123456789ABCDEFabcdef".contains(uc) {
          let x = xtod(uc)!
          cp = Character(UnicodeScalar(UInt32(x))!)
          astate = (0, .S_HEX2)
          return .NOCHAR
        }
        
        // no - done with current sequence, push back passed char
        astate = (0, .S_GROUND)
        return .VALIDPUSH
        
      case .S_HEX2:
        astate = (0, .S_GROUND)
        if "0123456789ABCDEFabcdef".contains(uc) {
          let x = xtod(uc)!
          let y = cp.unicodeScalars.first!.value
          cp = Character(UnicodeScalar( UInt32(x) | (y << 4))!)
          return .VALID
        }
        return .VALIDPUSH
        
      case .S_MIME1:
        if (uc == "\n" || uc == "\r") {
          astate = (0, .S_EATCRNL)
          return .NOCHAR
        }
        if "0123456789ABCDEF".contains(uc) {
          cp = Character(UnicodeScalar(xtod(uc)!)!)
          astate = (0, .S_MIME2)
          return .NOCHAR
        }
        break
        
      case .S_MIME2:
        if "0123456789ABCDEF".contains(uc) {
          astate = (0, .S_GROUND)
          let x = xtod(uc)!
          cp = Character(UnicodeScalar( UInt32(x) | (cp.unicodeScalars.first!.value << 4))!)
          return .VALID
        }
        break
        
      case .S_EATCRNL:
        switch (uc) {
          case "\r", "\n":
            return .NOCHAR
          case "=":
            astate = (0, .S_MIME1)
            return .NOCHAR
          default:
            cp = uc;
            astate = (0, .S_GROUND)
            return .VALID
        }
        
      case .S_AMP:
        cp = "\0"
        if (uc == "#") {
          astate = (0, .S_NUMBER)
          return .NOCHAR
        }
        astate = (0, .S_STRING)
        fallthrough
        
      case .S_STRING:
        let ia = Int(cp.unicodeScalars.first!.value)   // index in the array
        let _is = astate.n  // index in the string
        var lc : Character = "\0"
        if _is > 0 {
          let x = nv[ia].0.index(nv[ia].0.startIndex, offsetBy: _is-1)
          lc = nv[ia].0[x]  // last character
        }
        
        let uuc = uc == ";" ? "\0" : uc
        
        for i in ia..<nv.count {
          let jj = nv[i]
          let x = jj.0.index(jj.0.startIndex, offsetBy: _is-1)
          if _is != 0 && jj.0[x] != lc {
            break
          }
          let kk = nv[ia]
          let y = kk.0.index(kk.0.startIndex, offsetBy: _is)
          if (kk.0[y] == uuc) {
            break
          }
        }
        
        if ia == nv.count {
          break
        }
        
        if (uuc != "\0") {
          cp = Character(UnicodeScalar(UInt32(ia))!)
          astate = (_is + 1, .S_STRING)
          return .NOCHAR
        }
        
        cp = Character(nv[ia].1)
        astate = (0, .S_GROUND)
        return .VALID
        
      case .S_NUMBER:
        if (uc == ";") {
          return .VALID
        }
        if !"0123456789".contains(uc) {
          break
        }
        let cpn = cp.unicodeScalars.first!.value
        cp = Character(UnicodeScalar(cpn + (cpn * 10) + (uc.unicodeScalars.first!.value - 0x30))!)
        return .NOCHAR
        
      default:
        break
    }
//      bad:
        /*
         * decoder in unknown state - (probably uninitialized)
         */
        astate = (0, .S_GROUND)
        return .SYNBAD
  }
  
  /*
   * strnunvisx - decode src into dst
   *
   *  Number of chars decoded into dst is returned, -1 on error.
   *  Dst is null terminated.
   */
  /*
   int
   strnunvisx(char *dst, size_t dlen, const char *src, int flag)
   {
   char c;
   char t = '\0', *start = dst;
   int state = 0;
   
   _DIAGASSERT(src != NULL);
   _DIAGASSERT(dst != NULL);
   #define CHECKSPACE() \
   do { \
   if (dlen-- == 0) { \
   errno = ENOSPC; \
   return -1; \
   } \
   } while (/*CONSTCOND*/0)
   
   while ((c = *src++) != '\0') {
   again:
   switch (unvis(&t, c, &state, flag)) {
   case .VALID:
   CHECKSPACE();
   *dst++ = t;
   break;
   case .VALIDPUSH:
   CHECKSPACE();
   *dst++ = t;
   goto again;
   case 0:
   case .NOCHAR:
   break;
   case .SYNBAD:
   errno = EINVAL;
   return -1;
   default:
   _DIAGASSERT(/*CONSTCOND*/0);
   errno = EINVAL;
   return -1;
   }
   }
   if (unvis(&t, c, &state, UNVIS_END) == UNVIS_VALID) {
   CHECKSPACE();
   *dst++ = t;
   }
   CHECKSPACE();
   *dst = '\0';
   return (int)(dst - start);
   }
   */
  /*
   int
   strunvisx(char *dst, const char *src, int flag)
   {
   return strnunvisx(dst, (size_t)~0, src, flag);
   }
   
   int
   strunvis(char *dst, const char *src)
   {
   return strnunvisx(dst, (size_t)~0, src, 0);
   }
   
   int
   strnunvis(char *dst, size_t dlen, const char *src)
   {
   return strnunvisx(dst, dlen, src, 0);
   }
   */
  
  
  
  
  func xtod(_ c : Character) -> Int? {
    let x = "0123456789abcdef"
    let j = x.firstIndex(of: String(c).lowercased().first! )
    return x.distance(from: x.startIndex, to: j!)
  }
  
  
  
}
