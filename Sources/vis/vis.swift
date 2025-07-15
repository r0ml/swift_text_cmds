// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
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
     without specific prior written permfission.
 
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
// import System

let MB_CUR_MAX = 4

@main final class vis : ShellCommand {
  
  var usage : String = "Usage: vis [-bcfhlMmNnoSstw] [-e extra] [-F foldwidth] [file ...]"
  
  struct CommandOptions {
    var eflags : visOptions = []
    var debug = 0
    var extra : String? = nil
    var foldwidth : Int = 80
    var fold = false
    var markeol = false
    var none = false
    var args : [String] = CommandLine.arguments
  }
  
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
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "bcde:F:fhlMmNnoSstw"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "b" : options.eflags.insert(.NOSLASH)
        case "c" : options.eflags.insert(.CSTYLE)
        case "d": options.debug += 1
        case "e" : options.extra = v
        case "F":
          if let foldwidth = Int(v),
             foldwidth >= 5 {
            options.foldwidth = foldwidth
            options.markeol = true
          } else {
            throw CmdErr(1, "can't fold lines to less than 5 cols")
          }
        case "f":
          options.fold = true
        case "h":
          options.eflags.insert(.HTTPSTYLE)
        case "l":
          options.markeol = true
        case "M":
          options.eflags.insert(.META)
        case "m":
          options.eflags.insert(.MIMESTYLE)
          if options.foldwidth == 80 {
            options.foldwidth = 76
          }
        case "N":
          options.eflags.insert(.NOLOCALE)
        case "n":
          options.none = true
        case "o":
          options.eflags.insert(.OCTAL)
        case "S":
          options.eflags.insert(.SHELL)
        case "s":
          options.eflags.insert(.SAFE)
        case "t":
          options.eflags.insert(.TAB)
        case "w":
          options.eflags.insert(.WHITE)
        case "?":
          throw CmdErr(1)
        default: throw CmdErr(1)
      }
      if options.eflags.contains(.HTTPSTYLE) && options.eflags.contains(.MIMESTYLE) {
        throw CmdErr(1, "Can't specify -m and -h at the same time")
      }
    }
    
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    
    if options.args.isEmpty {
      await process(fileHandle: FileDescriptor.standardInput, options: options)
    } else {
      for f in options.args {
        do {
          await process(fileHandle: try FileDescriptor(forReading: f), options: options)
        } catch(let e) {
          warn("\(e)")
        }
      }
    }
  }
  
  var col = 0
  
  // ================================================
  
  func process(fileHandle: FileDescriptor, options: CommandOptions) async {
    var last : Character = "\n"
    
    // Helper to convert a character to its visual representation
    func visEncode(_ char: UInt8, _ lookahead: UInt8) -> String {
      // Simplified encoding logic, expand as needed for your use case
      if Character(UnicodeScalar(char) ).isASCII && char != 10 { // Handle ASCII and not newline
        return String(UnicodeScalar(char))
      } else {
        // Example: encode non-ASCII characters
        return "\\x" + cFormat("%02x", char)
      }
    }
    
    do {
      /* Read one multibyte character, and one readahead */
      var thischar : Character
      var readahead : Character = "\0"
      var first = true
      for try await c in fileHandle.characters {
        if first {
          readahead = c
          first = false
          continue
        } else {
          thischar = readahead
          readahead = c
        }
        last = handleChar(thischar, readahead, options: options)
      }
      if !first {
        last = handleChar(readahead, nil, options: options)
      }
    } catch(let e) {
      fatalError("failed to read character:  \(e)")
    }
    if (options.fold && last != "\n") {
      print(options.eflags.contains(.MIMESTYLE) ? "=\n" : "\\\n", terminator: "")
    }
    
    
  }
  
  func handleChar(_ thischar : Character, _ readahead : Character?, options : CommandOptions) -> Character {
    var buff = ""
    if options.none {
      buff.append(thischar)
      if thischar == "\\" {
        buff.append("\\")
      }
    } else if options.markeol && thischar == "\n" {
      // handle -l flag
      if !options.eflags.contains(.NOSLASH) {
        buff.append("\\")
      }
      buff.append("$\n")
    } else {
      /*
       * Convert character using vis(3) library.
       * At this point we will process one character.
       * But we must pass the vis(3) library this
       * character plus the next one because the next
       * one is used as a look-ahead to decide how to
       * encode this one under certain circumstances.
       *
       * Since our characters may be multibyte, e.g.,
       * in the UTF-8 locale, we cannot use vis() and
       * svis() which require byte input, so we must
       * create a multibyte string and use strvisx().
       */
      /* Treat EOF as a NUL char. */
      //      var mbibuff = (String(thischar) + String(readahead ?? "\0") ).data(using: .utf8)
      var cerr : Int32 = 0
      buff = mystrsenvisx([thischar, readahead ?? "\0"], options.eflags, options.extra ?? "", &cerr)
    }
    if options.fold {
      col = foldit(buff, col, options.foldwidth, options.eflags)
    }
    print(buff, terminator: "")
    return buff.last!
  }
  
  
  
  func foldit(_ chunk : String, _ incol : Int, _ max : Int, _ flags : visOptions) -> Int {
    /*
     * Keep track of column position. Insert hidden newline
     * if this chunk puts us over the limit.
     */
    var col = incol
    again: while true {
      var cp = Substring(chunk)
      while !cp.isEmpty {
        switch cp.first! {
          case "\n", "\r":
            col = 0
          case "\t":
            col = (col + 8) & ~07;
          case "\u{08}":
            col = col > 0 ? incol - 1 : 0;
            break;
          default:
            col = col + 1
        }
        if (col > (max - 2)) {
          print(flags.contains(.MIMESTYLE) ? "=\n" : "\\\n", terminator: "")
          col = 0;
          continue again
        }
        cp.removeFirst()
      }
      return col
    }
  }
  
  
  
  
  
  /*
   * istrsenvisx()
   *   The main internal function.
   *  All user-visible functions call this one.
   */
  func mystrsenvisx(_ mbsrc : [Character], _ flags : visOptions,  _ mbextra : String,  _ cerr_ptr : inout Int32) -> String
  {
    //    var mbbuf = Data(capacity: MB_CUR_MAX)
    //    wchar_t *dst, *src, *pdst, *psrc, *start, *extra;
    //    size_t len, olen;
    //    uint64_t bmsk, wmsk;
    //    wint_t c;
    //    visfun_t f;
    //    int clen = 0, cerr, error = -1, i, shft;
    //    char *mbdst, *mbwrite, *mdst;
    //    ssize_t mbslength;
    //    size_t maxolen;
    //    mbstate_t mbstate;
    
    //    _DIAGASSERT(mbdstp != NULL);
    //    _DIAGASSERT(mbsrc != NULL || mblength == 0);
    //    _DIAGASSERT(mbextra != NULL);
    
    /*
     * When inputing a single character, must also read in the
     * next character for nextc, the look-ahead character.
     */
    //    let mbslength = mblength == 1 ? 2 : mblength
    
    /*
     * Input (mbsrc) is a char string considered to be multibyte
     * characters.  The input loop will read this string pulling
     * one character, possibly multiple bytes, from mbsrc and
     * converting each to wchar_t in src.
     *
     * The vis conversion will be done using the wide char
     * wchar_t string.
     *
     * This will then be converted back to a multibyte string to
     * return to the caller.
     */
    
    /* Allocate space for the wide char strings */
    //    psrc = pdst = extra = NULL;
    //    mdst = NULL;
    //    if ((psrc = calloc(mbslength + 1, sizeof(*psrc))) == NULL)
    //      return -1;
    //    if ((pdst = calloc((16 * mbslength) + 1, sizeof(*pdst))) == NULL)
    //      goto out;
    //    if (*mbdstp == NULL) {
    //      if ((mdst = calloc((16 * mbslength) + 1, sizeof(*mdst))) == NULL)
    //        goto out;
    //      *mbdstp = mdst;
    //    }
    
    //    mbdst = *mbdstp;
    //    dst = pdst;
    //    src = psrc;
    
    let extra = makeextralist(flags) + mbextra
    
    let cerr = if (flags.contains(.NOLOCALE)) {
      /* Do one byte at a time conversion */
      Int32(1)
    } else {
      /* Use caller's multibyte conversion error flag. */
      cerr_ptr
    }
    
    /*
     * Input loop.
     * Handle up to mblength characters (not bytes).  We do not
     * stop at NULs because we may be processing a block of data
     * that includes NULs.
     */
    /*    while (mbslength > 0) {
     /* Convert one multibyte character to wchar_t. */
     if (!cerr)
     clen = mbrtowc(src, mbsrc, MIN(mbslength, MB_LEN_MAX),
     &mbstate);
     if (cerr || clen < 0) {
     /* Conversion error, process as a byte instead. */
     *src = (wint_t)(u_char)*mbsrc;
     clen = 1;
     cerr = 1;
     }
     if (clen == 0) {
     /*
      * NUL in input gives 0 return value. process
      * as single NUL byte and keep going.
      */
     clen = 1;
     }
     /* Advance buffer character pointer. */
     src++;
     /* Advance input pointer by number of bytes read. */
     mbsrc += clen;
     /* Decrement input byte count. */
     mbslength -= clen;
     }
     len = src - psrc;
     src = psrc;
     
     /*
      * In the single character input case, we will have actually
      * processed two characters, c and nextc.  Reset len back to
      * just a single character.
      */
     if (mblength < len)
     len = mblength;
     
     /* Convert extra argument to list of characters for this mode. */
     extra = makeextralist(flags, mbextra);
     if (!extra) {
     if (dlen && *dlen == 0) {
     errno = ENOSPC;
     goto out;
     }
     *mbdst = '\0';  /* can't create extra, return "" */
     error = 0;
     goto out;
     }
     */
    /* Look up which processing function to call. */
    // f = getvisfun(flags);
    
    let fn = flags.contains(.HTTPSTYLE) ? do_hvis : flags.contains(.MIMESTYLE) ? do_mvis : do_svis
    
    /*
     * Main processing loop.
     * Call do_Xvis processing function one character at a time
     * with next character available for look-ahead.
     */
    
    let dst = fn(mbsrc[0], flags, mbsrc[1], extra);
    return dst
    
    
    /*    if (dst == nil) {
     errno = ENOSPC;
     return -1
     }
     */
    
    /*
     * Output loop.
     * Convert wchar_t string back to multibyte output string.
     * If we have hit a multi-byte conversion error on input,
     * output byte-by-byte here.  Else use wctomb().
     */
    
    /*
     len = wcslen(start);
     maxolen = dlen ? *dlen : (wcslen(start) * MB_LEN_MAX + 1);
     olen = 0;
     bzero(&mbstate, sizeof(mbstate));
     dst = start
     while len > 0 {
     len -= 1
     if (!cerr) {
     /*
      * If we have at least MB_CUR_MAX bytes in the buffer,
      * we'll just do the conversion in-place into mbdst.  We
      * need to be a little more conservative when we get to
      * the end of the buffer, as we may not have MB_CUR_MAX
      * bytes but we may not need it.
      */
     if (maxolen - olen > MB_CUR_MAX)
     mbwrite = mbdst;
     else
     mbwrite = mbbuf;
     clen = wcrtomb(mbwrite, *dst, &mbstate);
     if (clen > 0 && mbwrite != mbdst) {
     /*
      * Don't break past our output limit, noting
      * that maxolen includes the nul terminator so
      * we can't write past maxolen - 1 here.
      */
     if (olen + clen >= maxolen) {
     errno = ENOSPC;
     goto out;
     }
     
     memcpy(mbdst, mbwrite, clen);
     }
     }
     if (cerr || clen < 0) {
     /*
      * Conversion error, process as a byte(s) instead.
      * Examine each byte and higher-order bytes for
      * data.  E.g.,
      *  0x000000000000a264 -> a2 64
      *  0x000000001f00a264 -> 1f 00 a2 64
      */
     clen = 0;
     wmsk = 0;
     for (i = sizeof(wmsk) - 1; i >= 0; i--) {
     shft = i * NBBY;
     bmsk = (uint64_t)0xffLL << shft;
     wmsk |= bmsk;
     if ((*dst & wmsk) || i == 0) {
     if (olen + clen + 1 >= maxolen) {
     errno = ENOSPC;
     return error
     }
     
     mbdst[clen++] = (char)(
     (uint64_t)(*dst & bmsk) >>
     shft);
     }
     }
     cerr = 1;
     }
     
     /*
      * We'll be dereferencing mbdst[clen] after this to write the
      * nul terminator; the above paths should have checked for a
      * possible overflow already.
      */
     assert(olen + clen < maxolen);
     
     /* Advance output pointer by number of bytes written. */
     mbdst += clen;
     /* Advance buffer character pointer. */
     dst++;
     /* Incrment output character count. */
     olen += clen;
     }
     
     /* Terminate the output string. */
     *mbdst = '\0';
     
     if (flags & VIS_NOLOCALE) {
     /* Pass conversion error flag out. */
     if (cerr_ptr)
     *cerr_ptr = cerr;
     }
     return olen
     out:
     return error;
     */
  }
  
  
  
  
  /*
   * This is do_hvis, for HTTP style (RFC 1808)
   */
  func do_hvis(_ c : Character, _ flags : visOptions, _ nextc : Character, _ extra : String) -> String
  {
    let cc = c.unicodeScalars.first!.value
    if iswalnum(wint_t(cc)) != 0
        /* safe */
        || "$-_.+!*'(),".contains(c)
    {
      return do_svis(c, flags, nextc, extra);
    }
    else {
      var dst = "%"
      let hex = "0123456789abcdef"
      dst.append( hex[hex.index(hex.startIndex, offsetBy: Int((cc >> 4 ) & 0xf) ) ] )
      dst.append( hex[hex.index(hex.startIndex, offsetBy: Int(cc & 0xf) ) ] )
      return dst
    }
  }
  
  /*
   * This is do_mvis, for Quoted-Printable MIME (RFC 2045)
   * NB: No handling of long lines or CRLF.
   */
  func do_mvis(_ c : Character, _ flags : visOptions, _ nextc : Character,  _ extra : String ) -> String
  {
    let cc = c.unicodeScalars.first!.value
    var dst = ""
    if (c != "\n" &&
        /* Space at the end of the line */
        (((iswspace(wint_t(cc)) != 0) && (nextc == "\r" || nextc == "\n")) ||
         /* Out of range */
         ((iswspace(wint_t(cc)) == 0) && (cc < 33 || (cc > 60 && cc < 62) || cc > 126)) ||
         /* Specific char to be escaped */
         "#$@[\\]^`{|}~".contains(c))) {
      dst.append("=")
      let hex = "0123456789ABCDEF"
      dst.append( hex[hex.index(hex.startIndex, offsetBy: Int((cc >> 4 ) & 0xf) ) ] )
      dst.append( hex[hex.index(hex.startIndex, offsetBy: Int(cc & 0xf) ) ] )
    } else {
      dst.append( do_svis(c, flags, nextc, extra) )
    }
    return dst;
  }
  
  /*
   * This is do_vis, the central code of vis.
   * dst:        Pointer to the destination buffer
   * c:        Character to encode
   * flags:     Flags word
   * nextc:     The character following 'c'
   * extra:     Pointer to the list of extra characters to be
   *        backslash-protected.
   */
  func do_svis(_ c : Character, _ flags : visOptions, _ nextc : Character, _ extra : String) -> String {
    //    int iswextra, i, shft;
    //    uint64_t bmsk, wmsk;
    
    let iswextra = extra.contains(c)
    
    if (!iswextra && (ISGRAPH(flags, c)
                      || iswwhite(flags, c)
                      || (flags.contains(.SAFE)
                          && iswsafe(c)))) {
      return String(c)
    }
    
    /* See comment in istrsenvisx() output loop, below. */
    let cx = c.utf8
    var dst = ""
    for cj in cx {
      // FIXME: do_mbyte should maybe take the character and uff8 it
        dst.append(do_mbyte( cj, flags, nextc, iswextra))
    }
    
    return dst
  }
  
  
  /*
   * Output single byte of multibyte character.
   */
  func do_mbyte(_ c : UInt8, _ flags : visOptions, _ nextc : Character, _ iswextra : Bool)  -> String  {
    if flags.contains(.CSTYLE) {
      switch (c) {
        case UInt8(ascii: "\n"):
          return "\\n"
        case UInt8(ascii: "\r"):
          return "\\r"
        case 8:
          return "\\b"
        case 7:
          return "\\a"
        case 0x0b:
          return "\\v"
        case UInt8(ascii: "\t"):
          return "\\t"
        case 0x0c:
          return "\\f"
        case UInt8(ascii: " "):
          return "\\s"
        case 0:
          var dst = "\\0"
          if "01234567".contains(nextc) {
            dst.append("00")
          }
          return dst
          /* We cannot encode these characters in VIS_CSTYLE
           * because they special meaning */
        case UInt8(ascii: "n"), UInt8(ascii: "r"), UInt8(ascii: "b"),
          UInt8(ascii: "a"), UInt8(ascii: "v"), UInt8(ascii: "t"),
          UInt8(ascii: "f"), UInt8(ascii: "s"), UInt8(ascii: "0"),
          UInt8(ascii: "M"), UInt8(ascii: "^"), UInt8(ascii: "$"): /* vis(1) -l */
          break;
        default:
          let cc = Character(UnicodeScalar(c))
          if ISGRAPH(flags, cc) {
            return "\\\(cc)"
          }
      }
    }
    var dst = ""
    var cc = c
    if (iswextra || ((cc & 0x7f) == 0x20) || flags.contains(.OCTAL)) {
      dst.append("\\")
      dst.append( Character( UnicodeScalar( UInt8(((cc >> 6) & 0x3) + 0x30 ))))
      dst.append( Character( UnicodeScalar( UInt8(((cc >> 3) & 0x7) + 0x30 ))))
      dst.append( Character( UnicodeScalar( UInt8(( cc       & 0x7) + 0x30 ))))
    } else {
      if !flags.contains(.NOSLASH) {
        dst.append("\\")
      }
      
      if 0 != (cc & 0x80) {
        cc &= 0x7f
        dst.append("M")
      }
      
      if ((iswcntrl(wint_t(cc))) != 0) {
        dst.append("^")
        if (cc == 0x7f) {
          dst.append("?")
        }
        else {
          dst.append(
            Character(UnicodeScalar(UInt8(cc) + Character("@").asciiValue!) ) )
        }
      } else {
        dst.append("-")
        dst.append(Character(UnicodeScalar(c)))
      }
    }
    return dst
  }
  
  
  func ISGRAPH(_ flags : visOptions, _ c : Character ) -> Bool {
    return 0 !=
    (flags.contains(.NOLOCALE) && !"01234567".contains(c) ? /* isgraph_l(c, LC_C_LOCALE */ isgraph( Int32(c.unicodeScalars.first!.value) ) : iswgraph( wint_t(c.unicodeScalars.first!.value) ))
  }
  
  func iswwhite(_ flags : visOptions, _ c : Character) -> Bool {
    let cc = c.unicodeScalars.first!.value
    return c == " " || c == "\t" || c == "\n" ||
    (!flags.contains(.NOLOCALE) && cc > 0x7f && (iswspace(wint_t(cc)) != 0))
  }
  
  func iswsafe(_ c : Character) -> Bool {
    return c == "\u{8}" || c == "\u{7}" || c == "\r"
  }
  
  /*
   * Expand list of extra characters to not visually encode.
   */
  func makeextralist(_ flags : visOptions) -> String {
/*    wchar_t *dst, *d;
    size_t len;
    const wchar_t *s;
    mbstate_t mbstate;
*/
    /*
    bzero(&mbstate, sizeof(mbstate));
    len = strlen(src);
    if ((dst = calloc(len + MAXEXTRAS, sizeof(*dst))) == NULL)
      return NULL;
*/
    // FIXME: put this back in -- it does something
    /*
    if ((flags & VIS_NOLOCALE) || mbsrtowcs(dst, &src, len, &mbstate) == (size_t)-1) {
      size_t i;
      for (i = 0; i < len; i++)
        dst[i] = (wchar_t)(u_char)src[i];
      d = dst + len;
    } else
      d = dst + wcslen(dst);
*/
    var dst = ""

    if flags.contains(.GLOB) {
      let char_glob = "*?[#";
      dst.append(contentsOf: char_glob)
    }

    if flags.contains(.SHELL) {
      let char_shell = "'`\";&<>()|{}]\\$!^~"
      dst.append(contentsOf: char_shell)
    }

    if flags.contains(.SP) { dst.append(" ") }
    if flags.contains(.TAB) { dst.append("\t") }
    if flags.contains(.NL)  { dst.append("\n") }
    if flags.contains(.DQ) { dst.append("\"") }
    if !flags.contains(.NOSLASH) { dst.append("\\") }
    return dst;
  }
  
  
  
}
