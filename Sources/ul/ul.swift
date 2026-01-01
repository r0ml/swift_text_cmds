
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1980, 1993
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

let IESC : Character = "\u{1b}"
let SO : Character = "\u{0e}"
let SI : Character = "\u{0f}"
let HFWD : Character = "9"
let HREV : Character = "8"
let FREV : Character = "7"
let MAXBUF = 512

struct Decoration : OptionSet {
  var rawValue : Int = 0
  
  static let NORMAL = [Decoration]()
  static let ALTSET = Decoration(rawValue: 1 )  // Reverse
  static let SUPERSC = Decoration(rawValue: 2 )  // Dim
  static let SUBSC = Decoration(rawValue: 4 )  // Dim | Ul
  static let UNDERL = Decoration(rawValue: 8 ) // Ul
  static let BOLD = Decoration(rawValue: 16)   // Bold
}

@main final class ul : ShellCommand {

  var usage : String = "usage: ul [-i] [-t terminal] [file ...]"
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "belnstuv"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand() throws(CmdErr) {
    throw CmdErr(1, usage)
  }
  
  
  /*
  func filter(_ f : FileDescriptor) async throws {
//    wint_t c;
//    int i, w;
//    int copy;
    
    var copy = false

    for try await c in f.bytes.characters {
      if (col == buflen) {
        if (obuf == sobuf) {
          obuf = nil
          copy = true
        }
        obuf = realloc(obuf, sizeof(*obuf) * 2 * buflen);
        if (obuf == NULL) {
          obuf = sobuf;
          break;
        } else if copy {
          memcpy(obuf, sobuf, sizeof(*obuf) * buflen);
          copy = false
        }
        bzero((char *)(obuf + buflen), sizeof(*obuf) * buflen);
        buflen *= 2;
      }
      switch(c) {
      case "\u{08}":
          if (col > 0) {
            col -= 1
          }
        continue;

      case "\t":
        col = (col+8) & ~07;
        if (col > maxcol)
          maxcol = col;
        continue;

      case "\r":
        col = 0;
        continue;

      case SO:
        mode |= ALTSET;
        continue;

      case SI:
        mode &= ~ALTSET;
        continue;

      case IESC:
        switch (c = getwc(f)) {

        case HREV:
          if (halfpos == 0) {
            mode |= SUPERSC;
            halfpos--;
          } else if (halfpos > 0) {
            mode &= ~SUBSC;
            halfpos--;
          } else {
            halfpos = 0;
            reverse();
          }
          continue;

        case HFWD:
          if (halfpos == 0) {
            mode |= SUBSC;
            halfpos++;
          } else if (halfpos < 0) {
            mode &= ~SUPERSC;
            halfpos++;
          } else {
            halfpos = 0;
            fwd();
          }
          continue;

        case FREV:
          reverse();
          continue;

        default:
          errx(1, "unknown escape sequence in input: %o, %o", IESC, c);
        }
        continue;

      case "_":
        if (obuf[col].c_char || obuf[col].c_width < 0) {
          while (col > 0 && obuf[col].c_width < 0)
            col--;
          w = obuf[col].c_width;
          for (i = 0; i < w; i++)
            obuf[col++].c_mode |= UNDERL | mode;
          if (col > maxcol)
            maxcol = col;
          continue;
        }
        obuf[col].c_char = '_';
        obuf[col].c_width = 1;
        /* FALLTHROUGH */
      case " ":
        col++;
        if (col > maxcol)
          maxcol = col;
        continue;

      case "\n":
        flushln();
        continue;

      case "\f":
        flushln();
        putwchar('\f');
        continue;

      default:
        if ((w = wcwidth(c)) <= 0)  /* non printing */
          continue;
        if (obuf[col].c_char == '\0') {
          obuf[col].c_char = c;
          for (i = 0; i < w; i++)
            obuf[col + i].c_mode = mode;
          obuf[col].c_width = w;
          for (i = 1; i < w; i++)
            obuf[col + i].c_width = -1;
        } else if (obuf[col].c_char == '_') {
          obuf[col].c_char = c;
          for (i = 0; i < w; i++)
            obuf[col + i].c_mode |= UNDERL|mode;
          obuf[col].c_width = w;
          for (i = 1; i < w; i++)
            obuf[col + i].c_width = -1;
        } else if ((wint_t)obuf[col].c_char == c) {
          for (i = 0; i < w; i++)
            obuf[col + i].c_mode |= BOLD|mode;
        } else {
          w = obuf[col].c_width;
          for (i = 0; i < w; i++)
            obuf[col + i].c_mode = mode;
        }
        col += w;
        if (col > maxcol)
          maxcol = col;
        continue;
      }
    }
    if (maxcol) {
      flushln();
    }
  }

  func flushln() {
    int i;
    int hadmodes = 0;

    var lastmode : Decoration = .NORMAL;
    for i in 0..<maxcol {
      if (obuf[i].c_mode != lastmode) {
        hadmodes++;
        setnewmode(obuf[i].c_mode);
        lastmode = obuf[i].c_mode;
      }
      if (obuf[i].c_char == '\0') {
        if (upln)
          PRINT(CURS_RIGHT);
        else
          outc(' ', 1);
      } else
        outc(obuf[i].c_char, obuf[i].c_width);
      if (obuf[i].c_width > 1)
        i += obuf[i].c_width - 1;
    }
    if (lastmode != NORMAL) {
      setnewmode(0);
    }
    if (must_overstrike && hadmodes)
      overstrike();
    putwchar('\n');
    if (iflag && hadmodes)
      iattr();
    (void)fflush(stdout);
    if (upln)
      upln--;
    initbuf();
  }

  /*
   * For terminals that can overstrike, overstrike underlines and bolds.
   * We don't do anything with halfline ups and downs, or Greek.
   */
  func overstrike() {
    int i;
    wchar_t lbuf[256];
    wchar_t *cp = lbuf;
    int hadbold=0;

    /* Set up overstrike buffer */
    for (i=0; i<maxcol; i++)
      switch (obuf[i].c_mode) {
      case NORMAL:
      default:
        *cp++ = ' ';
        break;
      case UNDERL:
        *cp++ = '_';
        break;
      case BOLD:
        *cp++ = obuf[i].c_char;
        if (obuf[i].c_width > 1)
          i += obuf[i].c_width - 1;
        hadbold=1;
        break;
      }
    putwchar('\r');
    for (*cp=' '; *cp==' '; cp--)
      *cp = 0;
    for (cp=lbuf; *cp; cp++)
      putwchar(*cp);
    if (hadbold) {
      putwchar('\r');
      for (cp=lbuf; *cp; cp++)
        putwchar(*cp=='_' ? ' ' : *cp);
      putwchar('\r');
      for (cp=lbuf; *cp; cp++)
        putwchar(*cp=='_' ? ' ' : *cp);
    }
  }

  func iattr() {
    int i;
    wchar_t lbuf[256];
    wchar_t *cp = lbuf;

    for (i=0; i<maxcol; i++)
      switch (obuf[i].c_mode) {
      case NORMAL:  *cp++ = ' '; break;
      case ALTSET:  *cp++ = 'g'; break;
      case SUPERSC:  *cp++ = '^'; break;
      case SUBSC:  *cp++ = 'v'; break;
      case UNDERL:  *cp++ = '_'; break;
      case BOLD:  *cp++ = '!'; break;
      default:  *cp++ = 'X'; break;
      }
    for (*cp=' '; *cp==' '; cp--)
      *cp = 0;
    for (cp=lbuf; *cp; cp++)
      putwchar(*cp);
    putwchar('\n');
  }

  func initbuf() {

    bzero((char *)obuf, buflen * sizeof(*obuf)); /* depends on NORMAL == 0 */
    col = 0;
    maxcol = 0;
    mode &= ALTSET;
  }

  func fwd() {
    int oldcol, oldmax;

    oldcol = col;
    oldmax = maxcol;
    flushln();
    col = oldcol;
    maxcol = oldmax;
  }

  func reverse() {
    upln++;
    fwd();
    PRINT(CURS_UP);
    PRINT(CURS_UP);
    upln++;
  }

  var CURS_UP = ""
  
  func initcap() {
//    static char tcapbuf[512];
//    char *bp = tcapbuf;

    let bp = gettable()
    
    /* This nonsense attempts to work with both old and new termcap */
    var p = UnsafeMutablePointer<CChar>(bitPattern: 0)
    
    CURS_UP = cgetstr(&bp, "up", &p);
    CURS_RIGHT =    tgetstr("ri", &bp);
    if (CURS_RIGHT == NULL)
      CURS_RIGHT =  tgetstr("nd", &bp);
    CURS_LEFT =    tgetstr("le", &bp);
    if (CURS_LEFT == NULL)
      CURS_LEFT =  tgetstr("bc", &bp);
    if (CURS_LEFT == NULL && tgetflag("bs"))
      CURS_LEFT =  "\b";

    ENTER_STANDOUT =  tgetstr("so", &bp);
    EXIT_STANDOUT =    tgetstr("se", &bp);
    ENTER_UNDERLINE =  tgetstr("us", &bp);
    EXIT_UNDERLINE =  tgetstr("ue", &bp);
    ENTER_DIM =    tgetstr("mh", &bp);
    ENTER_BOLD =    tgetstr("md", &bp);
    ENTER_REVERSE =    tgetstr("mr", &bp);
    EXIT_ATTRIBUTES =  tgetstr("me", &bp);

    if (!ENTER_BOLD && ENTER_REVERSE)
      ENTER_BOLD = ENTER_REVERSE;
    if (!ENTER_BOLD && ENTER_STANDOUT)
      ENTER_BOLD = ENTER_STANDOUT;
    if (!ENTER_UNDERLINE && ENTER_STANDOUT) {
      ENTER_UNDERLINE = ENTER_STANDOUT;
      EXIT_UNDERLINE = EXIT_STANDOUT;
    }
    if (!ENTER_DIM && ENTER_STANDOUT)
      ENTER_DIM = ENTER_STANDOUT;
    if (!ENTER_REVERSE && ENTER_STANDOUT)
      ENTER_REVERSE = ENTER_STANDOUT;
    if (!EXIT_ATTRIBUTES && EXIT_STANDOUT)
      EXIT_ATTRIBUTES = EXIT_STANDOUT;

    /*
     * Note that we use REVERSE for the alternate character set,
     * not the as/ae capabilities.  This is because we are modelling
     * the model 37 teletype (since that's what nroff outputs) and
     * the typical as/ae is more of a graphics set, not the greek
     * letters the 37 has.
     */

    UNDER_CHAR =    tgetstr("uc", &bp);
    must_use_uc = (UNDER_CHAR && !ENTER_UNDERLINE);
  }

  func outc(wint_t c, int width) {
    int i;

    putwchar(c);
    if (must_use_uc && (curmode&UNDERL)) {
      for (i = 0; i < width; i++)
        PRINT(CURS_LEFT);
      for (i = 0; i < width; i++)
        PRINT(UNDER_CHAR);
    }
  }

  var curmode : Decoration = NORMAL
  
  func setnewmode(_ newmode : Decoration) {
    if (!iflag) {
      if (curmode != .NORMAL && newmode != .NORMAL)
        setnewmode(NORMAL)
      switch (newmode) {
      case .NORMAL:
        switch(curmode) {
          case .NORMAL:
          break;
          case .UNDERL:
          PRINT(EXIT_UNDERLINE);
          break;
        default:
          /* This includes standout */
          PRINT(EXIT_ATTRIBUTES);
          break;
        }
        break;
      case .ALTSET:
        PRINT(ENTER_REVERSE);
        break;
      case .SUPERSC:
        /*
         * This only works on a few terminals.
         * It should be fixed.
         */
        PRINT(ENTER_UNDERLINE);
        PRINT(ENTER_DIM);
        break;
      case .SUBSC:
        PRINT(ENTER_DIM);
        break;
      case .UNDERL:
        PRINT(ENTER_UNDERLINE);
        break;
      case .BOLD:
        PRINT(ENTER_BOLD);
        break;
      default:
        /*
         * We should have some provision here for multiple modes
         * on at once.  This will have to come later.
         */
        PRINT(ENTER_STANDOUT);
        break;
      }
    }
    curmode = newmode
  }
  
  
  /*
   * Get a string valued option.
   * These are given as
   *  cl=^Z
   * Much decoding is done on the strings, and the strings are
   * placed in area, which is a ref parameter which is updated.
   * No checking on area overflow.
   */

  func tgetstr(_ id : String, _ area : inout String ) -> String? {
    char ids[3];
    char *s;
    int i;
    
    /*
     * XXX
     * This is for all the boneheaded programs that relied on tgetstr
     * to look only at the first 2 characters of the string passed...
     */
    *ids = *id;
    ids[1] = id[1];
    ids[2] = '\0';
    
    if ((i = cgetstr(tbuf, ids, &s)) < 0)
        return NULL;
    
    strcpy(*area, s);
    *area += i + 1;
    return (s);
  }
  
  func gettable() -> UnsafeMutablePointer<CChar>? {
    let a = strdup("/etc/gettytab")
    var kk = [a, nil]
    var bp = UnsafeMutablePointer<CChar>(bitPattern: 0)
    let jj = kk.withUnsafeMutableBufferPointer {kkp in
        cgetent(&bp, kkp.baseAddress, "default")
    }
    return bp
//    return String(cString: bp!)
  }
   */
}
