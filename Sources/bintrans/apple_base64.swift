
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notices:


/*
  Copyright (c) 1996, 1998 by Internet Software Consortium.
 
  Permission to use, copy, modify, and distribute this software for any
  purpose with or without fee is hereby granted, provided that the above
  copyright notice and this permission notice appear in all copies.
 
  THE SOFTWARE IS PROVIDED "AS IS" AND INTERNET SOFTWARE CONSORTIUM DISCLAIMS
  ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES
  OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL INTERNET SOFTWARE
  CONSORTIUM BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
  DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
  PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
  ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
  SOFTWARE.
 */

/*
  Portions Copyright (c) 1995 by International Business Machines, Inc.
 
  International Business Machines, Inc. (hereinafter called IBM) grants
  permission under its copyrights to use, copy, modify, and distribute this
  Software with or without fee, provided that the above copyright notice and
  all paragraphs of this notice appear in all copies, and that the name of IBM
  not be used in connection with the marketing of any product incorporating
  the Software or modifications thereof, without specific, written prior
  permission.
 
  To the extent it has a right to do so, IBM grants an immunity from suit
  under its patents, if any, for the use, sale or manufacture of products to
  the extent that such products are used for performing Domain Name System
  dynamic updates in TCP/IP networks by means of the Software.  No immunity is
  granted for any product per se or for any other function of any product.
 
  THE SOFTWARE IS PROVIDED "AS IS", AND IBM DISCLAIMS ALL WARRANTIES,
  INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
  PARTICULAR PURPOSE.  IN NO EVENT SHALL IBM BE LIABLE FOR ANY SPECIAL,
  DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER ARISING
  OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE, EVEN
  IF IBM IS APPRISED OF THE POSSIBILITY OF SUCH DAMAGES.
 */


let Base64 =
Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

let Pad64 : Character = "="

extension bintrans {
//  #define Assert(Cond) if (!(Cond)) abort()
    
  
  /* (From RFC1521 and draft-ietf-dnssec-secext-03.txt)
   The following encoding technique is taken from RFC 1521 by Borenstein
   and Freed.  It is reproduced here in a slightly edited form for
   convenience.
   
   A 65-character subset of US-ASCII is used, enabling 6 bits to be
   represented per printable character. (The extra 65th character, "=",
   is used to signify a special processing function.)
   
   The encoding process represents 24-bit groups of input bits as output
   strings of 4 encoded characters. Proceeding from left to right, a
   24-bit input group is formed by concatenating 3 8-bit input groups.
   These 24 bits are then treated as 4 concatenated 6-bit groups, each
   of which is translated into a single digit in the base64 alphabet.
   
   Each 6-bit group is used as an index into an array of 64 printable
   characters. The character referenced by the index is placed in the
   output string.
   
   Table 1: The Base64 Alphabet
   
   Value Encoding  Value Encoding  Value Encoding  Value Encoding
   0 A            17 R            34 i            51 z
   1 B            18 S            35 j            52 0
   2 C            19 T            36 k            53 1
   3 D            20 U            37 l            54 2
   4 E            21 V            38 m            55 3
   5 F            22 W            39 n            56 4
   6 G            23 X            40 o            57 5
   7 H            24 Y            41 p            58 6
   8 I            25 Z            42 q            59 7
   9 J            26 a            43 r            60 8
   10 K            27 b            44 s            61 9
   11 L            28 c            45 t            62 +
   12 M            29 d            46 u            63 /
   13 N            30 e            47 v
   14 O            31 f            48 w         (pad) =
   15 P            32 g            49 x
   16 Q            33 h            50 y
   
   Special processing is performed if fewer than 24 bits are available
   at the end of the data being encoded.  A full encoding quantum is
   always completed at the end of a quantity.  When fewer than 24 input
   bits are available in an input group, zero bits are added (on the
   right) to form an integral number of 6-bit groups.  Padding at the
   end of the data is performed using the '=' character.
   
   Since all base64 input is an integral number of octets, only the
   -------------------------------------------------
   following cases can arise:
   
   (1) the final quantum of encoding input is an integral
   multiple of 24 bits; here, the final unit of encoded
   output will be an integral multiple of 4 characters
   with no "=" padding,
   (2) the final quantum of encoding input is exactly 8 bits;
   here, the final unit of encoded output will be two
   characters followed by two "=" padding characters, or
   (3) the final quantum of encoding input is exactly 16 bits;
   here, the final unit of encoded output will be three
   characters followed by one "=" padding character.
   */
  
  func
  apple_b64_ntop(_ src : inout Data) -> String {
    var target = ""
//    size_t datalength = 0;
//    u_char input[3];
//    u_char output[4];
//    size_t i;
    
    while (2 < src.count) {
      let input = Data(src.prefix(3))
      src.removeFirst(3)
      target.append( Base64[ Int(input[0] >> 2) ] )
      target.append( Base64[ Int(((input[0] & 0x03) << 4) + (input[1] >> 4))])
      target.append( Base64[ Int(((input[1] & 0x0f) << 2) + (input[2] >> 6)) ])
      target.append( Base64[ Int(input[2] & 0x3f) ])
    }
    
    /* Now we worry about padding. */
    if (0 != src.count) {
      /* Get what's left. */
      var input = Data(src)
      while input.count < 3 { input.append(0) }
      target.append( Base64[ Int(input[0] >> 2 ) ])
      target.append( Base64[ Int(((input[0] & 0x03) << 4) + (input[1] >> 4) ) ] )
                             
      if src.count == 1 {
        target.append( Pad64 )
      } else {
        target.append( Base64[ Int(((input[1] & 0x0f) << 2) + (input[2] >> 6)) ] )
      }
      target.append( Pad64)
    }
    return target
  }
  
  /* skips all whitespace anywhere.
   converts characters, four at a time, starting at (or after)
   src from base - 64 numbers into three 8 bit bytes in the target area.
   it returns the number of data bytes stored at the target, or -1 on error.
   */
  
  /* returns the converted data, and a boolean to indicate more
   date to come (i.e. false for "all done" */
  func apple_b64_pton( _ srcx : String) -> (Data?, Bool) {
//    int tarindex, state, ch;
//    u_char nextbyte;
//    char *pos;
    
//    state = 0;
//    tarindex = 0;
    
    var ch : Character
    var state = 0
    var src = Substring(srcx)
    var target = Data()
    
  //  while ((ch = *src++) != '\0') {
    while true {
      ch = "\0"
      if src.isEmpty { break }
      ch = src.removeFirst()

      if ch.isWhitespace {
        // isspace((unsigned char)ch))        /* Skip whitespace anywhere.
        continue
      }
      
      if ch == Pad64 {
        break
      }
      
      if ch == "-" {
        ch = "+"
      }
      else if ch == "_" {
        ch = "/"
      }
      guard let pos = Base64.firstIndex(of: ch) else { return (nil, true) }

      switch state {
        case 0:
          target.append(UInt8(pos) << 2)
          state = 1
        case 1:
          target[target.count - 1]   |=  UInt8(pos) >> 4
          target.append( (UInt8(pos) & 0x0f) << 4 )
          state = 2
        case 2:
          target[target.count - 1]   |=  UInt8(pos) >> 2
          target.append( (UInt8(pos) & 0x03) << 6)
          state = 3
        case 3:
          target[target.count - 1] |= UInt8(pos)
          state = 0
        default:
          abort()
      }
    }
    
    /*
     * We are done decoding Base-64 chars.  Let's see if we ended
     * on a byte boundary, and/or with erroneous trailing characters.
     */
    
    if ch == Pad64 {    /* We got a pad char. */
//      ch = *src++;    /* Skip it, get next. */
      switch state {
        case 0, 1:    // Invalid = in first or second position
          return (nil, false)
          
        case 2:    /* Valid, means one byte of info */
          /* Skip any number of spaces. */
          
          while !src.isEmpty {
            ch = src.removeFirst()
            if !ch.isWhitespace { break }
          }
            /* Make sure there is another trailing = sign. */
            if ch != Pad64 { return (nil, false) }
//          ch = *src++;    /* Skip the = */
          /* Fall through to "single trailing =" case. */
          fallthrough
          
        case 3:    /* Valid, means two bytes of info */
          /*
           * We know this char is an =.  Is there anything but
           * whitespace after it?
           */
          while !src.isEmpty {
            ch = src.removeFirst()
            if !ch.isWhitespace { return (nil, false) }
          }
          
          /*
           * Now make sure for cases 2 and 3 that the "extra"
           * bits that slopped past the last full byte were
           * zeros.  If we don't check them, they become a
           * subliminal channel.
           */
          if target[target.count - 1] != 0 {
            return (nil, false)
          }
          target.removeLast()
        default:
          abort()
      }
      return (target, false)
    } else {
      /*
       * We ended by seeing the end of the string.  Make sure we
       * have no partial bytes lying around.
       */
      if (state != 0) {
        return (nil, true)
      }
    }
    return (target, true)
  }
}
