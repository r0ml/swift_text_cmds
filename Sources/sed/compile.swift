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
 */

import CMigration

// for regex
import Darwin

// Constants/defines used by compile.c
let LHSZ = 128
let LHMASK = LHSZ - 1

public struct CompileErr : Error {
  public var message : String
  
  public init(_ message : String = "") {
    self.message = message
  }
  
  public var localizedDescription: String {
    return message
  }
}

extension sed {
  struct CompileState {
    var st : ScriptReader
    var prog : [s_command] = []
    var maxnsub : Int = 0
    // labels are represented as an array of command indices
    var labels: [String : ArraySlice<Int> ] = [:]
    
    init(_ script : [s_compunit]) {
      st = ScriptReader(script)
    }
  }
  
  // Each entry: code, naddr, args
  struct s_format {
    var naddr: Int
    var args: e_args
  }
  
  // Equivalent to cmd_fmts[] in compile.c
  static let cmd_fmts: [Character : s_format] = [
    "{" : s_format(naddr: 2, args: .GROUP),
    "}" : s_format(naddr: 0, args: .ENDGROUP),
    "a" : s_format(naddr: 1, args: .TEXT),
    "b" : s_format(naddr: 2, args: .BRANCH),
    "c" : s_format(naddr: 2, args: .TEXT),
    "d" : s_format(naddr: 2, args: .EMPTY),
    "D" : s_format(naddr: 2, args: .EMPTY),
    "g" : s_format(naddr: 2, args: .EMPTY),
    "G" : s_format(naddr: 2, args: .EMPTY),
    "h" : s_format(naddr: 2, args: .EMPTY),
    "H" : s_format(naddr: 2, args: .EMPTY),
    "i" : s_format(naddr: 1, args: .TEXT),
    "l" : s_format(naddr: 2, args: .EMPTY),
    "n" : s_format(naddr: 2, args: .EMPTY),
    "N" : s_format(naddr: 2, args: .EMPTY),
    "p" : s_format(naddr: 2, args: .EMPTY),
    "P" : s_format(naddr: 2, args: .EMPTY),
    "q" : s_format(naddr: 1, args: .EMPTY),
    "r" : s_format(naddr: 1, args: .RFILE),
    "s" : s_format(naddr: 2, args: .SUBST),
    "t" : s_format(naddr: 2, args: .BRANCH),
    "w" : s_format(naddr: 2, args: .WFILE),
    "x" : s_format(naddr: 2, args: .EMPTY),
    "y" : s_format(naddr: 2, args: .TR),
    "!" : s_format(naddr: 2, args: .NONSEL),
    ":" : s_format(naddr: 0, args: .LABEL),
    "#" : s_format(naddr: 0, args: .COMMENT),
    "=" : s_format(naddr: 1, args: .EMPTY),
//    "\0" : s_format(naddr: 0, args: .COMMENT)  // sentinel
  ]
  
  // 'FIXME: all of these inout CommandOptions are because deep in the bowels, the nflag could be set 
  func compile(_ options : inout CommandOptions) async throws -> CompileState {
    var cs = CompileState(options.script)
//    cs.st.script = options.script
    
    var pp = Substring("")
    var needClosing = 0
    cs.prog = try await compile_stream(&pp, &cs, &options, &needClosing)
    
    // Now resolve all the labels
    definelabels(cs.prog, [], &cs)
    try checklabels(cs.prog, cs)
    // FIXME: I need fix appendnums
//    try fixuplabel(cmd: &cs.prog, cs)
    return cs
  }
  
  // A small macro from compile.c
  func EATSPACE(_ p: inout Substring) {
    p = p.drop(while: \.isWhitespace)
  }
  
  /**
   * compile_stream: parse the script lines into the array of s_command.
   */
  // FIXME: can throw CompileError or CmdErr
  func compile_stream(_ p : inout Substring, _ cs : inout CompileState, _ options : inout CommandOptions, _ needClosing : inout Int ) async throws -> [s_command] {
    
    var prog: [s_command] = []

    while true {
      if p.isEmpty {
        if let pp = try await cs.st.cu_fgets(&options) {
          p = Substring(pp)
        } else {
          if needClosing > 0 {
            throw CompileErr("unexpected EOF (pending }'s)")
          }
          return prog
        }
      }
      let c = try await compile_line(&p, &options, &cs, &needClosing)
//      if c.last?.code == "}" {
//          break
//      } else {
        prog.append(contentsOf: c)
//      }
      if c.last?.code == "}" {
        break
      }
    }
    
    // FIXME: keep track of nesting level
/*      if !stack.isEmpty {
        throw CompileErr("unexpected EOF (pending }'s)")
      }
 */
      return prog
  }
  
  func compile_line(_ p : inout Substring, _ options : inout CommandOptions, _ cs : inout CompileState, _ needClosing : inout Int) async throws -> [s_command] {
    
    var pro = [s_command]()
    
    // Creating a sed command
    semicolon: while !p.isEmpty {
      EATSPACE(&p)
      var cmd = s_command()
      
      if p.hasPrefix("#") || p.isEmpty  {
        p = ""
        continue
      } else if p.hasPrefix(";") {
        p.removeFirst()
        pro.append(cmd)
        continue semicolon
      }
      
      
      // ===================
      // Parsing addresses
      // ===================
      if addrchar(p.first) {
        cmd.a1  = try compile_addr(&p, &cs, options)
        EATSPACE(&p)
        if p.first == "," {
          p.removeFirst()
          EATSPACE(&p)
          cmd.a2 = try compile_addr(&p, &cs, options)
          EATSPACE(&p)
        }
      }
      
      if p.isEmpty {
        throw CompileErr("command expected")
      }
      try await compile_postaddr(&p, &options, &cmd, &cs, &needClosing)
      pro.append(cmd)
      if cmd.code == "}" { break }
    }
    return pro
  }
  
  func compile_postaddr(_ p : inout Substring, _ options : inout CommandOptions, _ cmd : inout s_command, _ cs : inout  CompileState, _ needClosing : inout Int) async throws {
    // ======================================
    // Parsing the command(s) for the address
    // ======================================
    while !p.isEmpty {
      let cval = p.removeFirst()
      cmd.code = cval
      
      guard let fp = Self.cmd_fmts[cval] else {
        throw CompileErr("invalid command code \(cval)")
      }
      let curNaddr = (cmd.a1 != nil ? 1 : 0)
      + (cmd.a2 != nil ? 1 : 0)
      if curNaddr > fp.naddr {
        throw CompileErr(" command \(cval) expects up to \(fp.naddr) address(es), found \(curNaddr)")
      }
      
      switch fp.args {
        case .NONSEL:
          // '!'
          EATSPACE(&p)
          cmd.nonsel = true
          continue
   
          // ================================
          // stack only gets used for group / endgroup
        case .GROUP:
          // '{'
          EATSPACE(&p)
          needClosing += 1
          let c = try await compile_stream(&p, &cs, &options, &needClosing)
          cmd.u = .c(c)
          
          if !p.isEmpty {
            return
          }
          
        case .ENDGROUP:
          // '}'
          if ( needClosing == 0 ) {
            throw CompileErr("unexpected }")
          }
          needClosing -= 1
          cmd.nonsel = true
          return
          
          // ================================
          
        case .EMPTY:
          // commands like d, D, g, G, etc.
          EATSPACE(&p)
          if p.first == ";" {
            p.removeFirst()
            return
          }
          if !p.isEmpty {
            throw CompileErr("extra characters at the end of \(cmd.code) command")
          }
          
        case .TEXT:
          // 'a', 'c', 'i'
          EATSPACE(&p)
          if p.first != "\\" {
            throw CompileErr("command \(cmd.code) expects \\ followed by text")
          }
          p.removeFirst()
          EATSPACE(&p)
          if !p.isEmpty {
            throw CompileErr("extra characters after \\ at the end of \(cmd.code) command")
          }
          cmd.t = try await compile_text(&cs, &options)
          
        case .COMMENT:
          // '\0' or '#' => do nothing
          break
          
        case .WFILE:
          // 'w'
          EATSPACE(&p)
          if p.isEmpty {
            throw CompileErr("filename expected")
          }
          cmd.t = try duptoeol(&p, "w command")
          
          if options.aflag {
            cmd.u = .fd(nil)
          } else {
            // open(...) => file descriptor
            let fd = try openFileForWCommand(cmd.t)
            cmd.u = .fd(fd)
          }
          
        case .RFILE:
          // 'r'
          EATSPACE(&p)
          if p.isEmpty {
            throw CompileErr("filename expected")
          } else {
            cmd.t = try duptoeol(&p, "read command")
          }
          
        case .BRANCH:
          // 'b', 't'
          EATSPACE(&p)
          if p.isEmpty {
            cmd.t = ""
          } else {
            cmd.t = try duptoeol(&p, "branch")
          }
          
        case .LABEL:
          // ':'
          EATSPACE(&p)
          cmd.t = try duptoeol(&p, "label")
          if cmd.t.isEmpty {
            throw CompileErr("empty label")
          }
          // try enterlabel(cmd, &cs)
          
        case .SUBST:
          // 's'
          if p.isEmpty || p.first == "\\" {
            throw CompileErr("substitute pattern cannot be delimited by newline or backslash")
          }
          var mysubst = s_subst()
          let os = try compile_delimited(&p, false)
          if os == nil {
            throw CompileErr("unterminated substitute pattern")
          }

          mysubst.src = os

          // FIXME: the original does the compile twice
//          let re = try compile_re(os!, false, &cs, options)
//          mysubst.re = re

          /*
 mysubst.re = os!
          // We do a pre-check: if *re == '\0', then re is empty => cmd->u.s->re = NULL
          let reString = cStringFromBuffer(rebuf)
          if reString.isEmpty {
            cmd?.u.s?.re = nil
          } else {
            cmd?.u.s?.re = compile_re(reString, 0)
          }
          // p-- in C => we adjust pointer back by 1
          p = p!.advanced(by: -1)
          // compile_subst => produce the s->new
 */
          //FIXME: this should be used
          let ns = try await compile_subst(&p, &mysubst, &cs.st, &options )
          // compile_flags => sets s->n, s->p, s->wfile, etc.
          try compile_flags(&p, &mysubst, options.aflag)
          
          mysubst.tgt = ns
          
          // Now recompile if “I” was set:
/*          if reString.isEmpty {
            cmd?.u.s?.re = nil
          } else {
            cmd?.u.s?.re = compile_re(reString, cmd!.u.s!.icase)
          }
*/
          
          if !os!.isEmpty {
            let re2 = try compile_re(os!, mysubst.icase, &cs, options)
            mysubst.re = re2
          }
          cmd.u = .s(mysubst)

          EATSPACE(&p)
          if p.hasPrefix(";") {
            p.removeFirst()
            return
          }
          
        case .TR:
          // 'y'
          let ctr = try compile_tr(&p)
          cmd.u = .y(ctr)
          EATSPACE(&p)
          if p.hasPrefix(";") {
            p.removeFirst()
            return
          }
          if !p.isEmpty {
            throw CompileErr("extra text at the end of a transform command")
          }
      }
    }
    if cmd.code == "!" {
      throw CompileErr("command expected")
    }
    return
  }
  
  /**
   * Helper: skip leading whitespace in a CChar buffer and return pointer to first non-whitespace.
   */
  /*
  func skipSpaces(_ buffer: [CChar]) -> UnsafeMutablePointer<CChar>? {
    // Return pointer to first non-whitespace or nil if we hit null terminator
    // We'll create a pointer from buffer and advance
    guard let basePtr = buffer.withUnsafeBufferPointer({ $0.baseAddress }) else {
      return nil
    }
    var ptr = basePtr
    while ptr.pointee != 0 && isspace(Int32(ptr.pointee)) != 0 {
      ptr = ptr.advanced(by: 1)
    }
    if ptr.pointee == 0 {
      // ended on '\0'
      return ptr
    }
    return ptr
  }
  */
  
  // The code in compile.c uses “addrchar(c)” => check if c in [0-9, /, \, $]
  func addrchar(_ c : Character?) -> Bool {
    if let c {
      return "0123456789/\\$".contains(c)
    } else {
      return false
    }
  }
    
  /**
   * compile_delimited(p, d, is_tr): read a delimited string, store result in `d`.
   * Return (newp, success) => pointer after final delimiter, or nil if error.
   */
  func compile_delimited(_ p: inout Substring,
                       _ is_tr: Bool
                         
  ) throws(CompileErr) -> String?
  {
    if p.isEmpty {
      return nil
    }
    let delimiter = p.removeFirst()
    if delimiter == "\\" {
      throw CompileErr("\\\\ cannot be used as a string delimiter")
    } else if delimiter == "\n" {
      throw CompileErr("newline cannot be used as a string delimiter")
    }

    var dst = ""
    
    while !p.isEmpty {
      // If bracket [..], etc.
      if p.first == "[" && p.first != delimiter {
        // if !is_tr => handle compile_ccl
        if !is_tr {
          if let ds = compile_ccl(&p) {
            dst.append(ds)
            continue
          } else {
            throw CompileErr("unbalanced brackets ([])")
          }
        }
      } else if p.hasPrefix("\\[") {
        // if is_tr => skip?
        if is_tr {
          p.removeFirst()
        } else {
          dst.append(p.removeFirst())
        }
      } else if p.hasPrefix("\\"+[delimiter]) {
        // skip the slash
        p.removeFirst()
      } else if p.hasPrefix("\\") {
        let next = p.dropFirst().first
        if next == "n" {
          dst.append("\n")
          p.removeFirst(2)
        } else if next == "r" {
          dst.append("\r")
          p.removeFirst(2)
        } else if next == "t" {
          dst.append("\t")
          p.removeFirst(2)
        } else if next == "x" {
          // dohex
          p.removeFirst(2)
          let outChar = dohex(&p)
          dst.append(outChar)
        } else if next == "\\" {
          if is_tr {
            // skip
            p.removeFirst()
          } else {
            dst.append(p.removeFirst())
            dst.append(p.removeFirst())
          }
        } else if let next {
          dst.append("\\")
          dst.append(next)
          p.removeFirst(2)
        }
        continue
      } else if p.first == delimiter {
        return dst
      }
      dst.append(p.removeFirst())
    }
    return nil
  }
  
  /**
   * compile_ccl: expand a POSIX character class.
   * In the original code, we modify the pointer s in place. We'll do so similarly here.
   */
  func compile_ccl(_ sp: inout Substring) -> String? {
  
    guard !sp.isEmpty else { return nil }
    var s = sp
    var dst = ""
    
    dst.append(s.removeFirst())
    
    if s.hasPrefix("^") {
      dst.append(s.removeFirst())
    }
    if s.hasPrefix("]") {
      dst.append(s.removeFirst())
    }

    while !s.isEmpty, !s.hasPrefix("]") {
      if s.hasPrefix("[.") || s.hasPrefix("[:") || s.hasPrefix("[=") {
        dst.append(contentsOf: s.prefix(2))
        s.removeFirst()
        let d = s.removeFirst()

        while let c = s.first,
              c != "]" || c != d {
          dst.append(s.removeFirst())
        }
        // FIXME: not sure if this is an else
      } else {
        dst.append(s.removeFirst())
      }
      
      if s.first == nil { return nil }
      // (Non-Apple code handles backslashes, etc.)
      if s.first == "]" { break }
    }
    if s.hasPrefix("]") {
      sp = s.dropFirst()
      dst.append("]")
      return dst
    }
    return nil
  }
  
  /**
   * Check if c is hex digit.
   */
  func hexdigit(_ c: CChar) -> Bool {
    let lc = tolower(Int32(c))
    if isdigit(lc) != 0 { return true }
    if lc >= 97 && lc <= 102 { return true } // a..f
    return false
  }
  
  /**
   * dohex: parse up to 2 hex digits from in, store result in out, set length in len.
   */
  func dohex(_ s : inout Substring) -> Character {
    if let k = s.first?.hexDigitValue {
      s.removeFirst()
      if let j = s.first?.hexDigitValue {
        s.removeFirst()
        return Character(UnicodeScalar(Int(k) * 16 + Int(j))!)
      }
      return Character(UnicodeScalar(Int(k))!)
    }
    return "\0"
  }
  
  
  /*
   * Compiles the regular expression in RE and returns a pointer to the compiled
   * regular expression.
   * Cflags are passed to regcomp.
   */
  func compile_re(_ re : String, _ case_insensitive : Bool, _ st : inout CompileState, _ options : CommandOptions) throws(CompileErr) -> regex_t?
  {
    var rep = regex_t()

    var flags = UInt32(options.rflags)
    if case_insensitive {
      flags |= UInt32(REG_ICASE)
    }
    
    let eval =
    withUnsafeMutablePointer(to: &rep) { rr in
      re.withCString {
        regcomp(rr, $0, Int32(flags) )
      }
    }
    
    if eval != 0 {
      let s = regerror(eval, rep)
      throw CompileErr("RE /\(re)/ error: \(s)")
    }

//    print("RE: \(re)")

    
    if (st.maxnsub < rep.re_nsub) {
      st.maxnsub = rep.re_nsub
    }
    return rep
  }

  /**
   * compile_re: compile the given RE using Swift's NSRegularExpression in our model,
   * respecting case_insensitive if set.
   */
  /*
   * Compiles the regular expression in RE and returns a pointer to the compiled
   * regular expression.
   * Cflags are passed to regcomp.
   */
  // FIXME: support NSRegularExpression ?
  /*
  func compile_nsre(_ re: String, _ case_insensitive: Bool, _ options: CommandOptions) throws(CompileErr) -> regex_t? {
    // rflags is a global controlling some RE flags.
    // We'll do the best we can with NSRegularExpression.
    // If an error occurs, we call errx.
    let options: NSRegularExpression.Options = {
      var opts: NSRegularExpression.Options = []
      if (options.rflags & UInt32(REG_EXTENDED) ) != 0 {
        // Swift's NSRegularExpression is always "extended" in the sense that
        // it doesn't treat normal characters specially. We might set something
        // but there's no direct match to POSIX ERE vs BRE here.
      }
      if case_insensitive {
        opts.insert(.caseInsensitive)
      }
      // For multiline, anchored, etc. we'd set additional flags if needed.
      return opts
    }()
    do {
      let regex = try NSRegularExpression(pattern: re, options: options)
      // Update maxnsub if needed
      let subCount = regex.numberOfCaptureGroups
      if maxnsub < subCount { maxnsub = subCount }
      return regex
    } catch {
      throw CompileErr("RE error: \(error)")
    }
    return nil
  }
  */
  
  /**
   * compile_subst: compile the 's///' substitution string, store result in s->new
   */
  /*
   * Compile the substitution string of a regular expression and set res to
   * point to a saved copy of it.  Nsub is the number of parenthesized regular
   * expressions.
   */
  func compile_subst(_ p : inout Substring, _ s : inout s_subst, _ st : inout ScriptReader, _ options : inout CommandOptions) async throws -> String? {
    guard !p.isEmpty else { return nil }

    s.maxbref = 0
    s.linenum = st.linenum
    // We'll store text in a dynamic buffer

    let delimiter = p.removeFirst()
    var sawesc = false
    
    // for the repeat/while
    var pp : String?
    var sp = ""

    repeat {
      while !p.isEmpty {
        if p.hasPrefix("\\") || sawesc {
          if sawesc {
            sawesc = false
          } else {
            p.removeFirst()
          }
          if p.isEmpty {
            sawesc = true
            sp.append("\n")
            continue
          } else if let n = Array("123456789").firstIndex(of: p.first!) {
            sp.append("\\")
            let ref = UInt(n+1)
            if let re = s.re, ref > re.re_nsub {
              throw CompileErr("\\\(p.first!) not defined in the RE")
            }
            if s.maxbref < ref {
              s.maxbref = ref
            }
            sp.append(p.removeFirst())
          } else {
            switch p.first {
              case "&", "\\":
                // just store a backslash
                sp.append("\\")
                sp.append(p.removeFirst())
              case "n":
                sp.append("\n")
                p.removeFirst()
              case "r":
                sp.append("\r")
                p.removeFirst()
              case "t":
                sp.append("\t")
                p.removeFirst()
              case "x":
                // dohex
                p.removeFirst()
                let outChar = dohex(&p)
                sp.append(outChar)
              default:
                sp.append(p.removeFirst())
                break
            }
          }
        } else if p.first == delimiter {
          // end of pattern
          p.removeFirst()
          if p.isEmpty {
            // if more => read next line? The code does something with that.
            // We'll skip that detail for brevity.
          }
          s.new = sp
          return sp
        } else if p.hasPrefix("\n") || p.hasPrefix("\r\n") {
          throw CompileErr("unescaped newline inside substitute pattern")
        } else {
          sp.append(p.removeFirst())
        }
      }

      pp = try await st.cu_fgets(&options)
      if let pp {
        p = Substring(pp)
      }
      // The code calls cu_fgets into lbuf with &more, then resets p?
      // We will skip the multi-line parsing details for brevity.
      // If we fail, we error out.
    } while (pp != nil)
      throw CompileErr("unterminated substitute in regular expression")
    // unreachable
    // return nil
  }
  
  /**
   * SHIFT function to remove n characters from src after the slash-x escape, etc.
   */
/*  func shiftLeft(src: UnsafeMutablePointer<CChar>, n: Int) -> UnsafeMutablePointer<CChar> {
    var pointer = src
    let ccount = countNullTerminated(src)
    // shift everything left by n
    for _ in 0..<(ccount - n) {
      pointer.pointee = pointer.advanced(by: n).pointee
      pointer = pointer.advanced(by: 1)
    }
    pointer.pointee = 0
    return src
  }
  */
  
  /**
   * Count the length of a null-terminated CChar buffer
   */
  /*
  func countNullTerminated(_ ptr: UnsafeMutablePointer<CChar>) -> Int {
    var count = 0
    var tmp = ptr
    while tmp.pointee != 0 {
      count += 1
      tmp = tmp.advanced(by: 1)
    }
    return count
  }
  */
  
  /**
   * Reallocate the text pointer to size, returning it as a Swift string in s_subst?
   * Actually we store in s->new as a Swift String. The code might want a C-string.
   */
/*
 func reallocString(_ ptr: UnsafeMutablePointer<CChar>, _ newSize: Int) throws(CompileErr) -> String {
    // We can convert to Swift string.
    ptr[newSize-1] = 0 // ensure null
    return String(cString: ptr)
  }
 */
  /*
   * compile_flags: parse trailing flags of s/// command, setting s->n, s->p, etc.
   */
  func compile_flags(_ p: inout Substring, _ s : inout s_subst, _ aflag : Bool) throws (CompileErr) {
    var gn = false // true if we have seen g or a number
    
    while true {
      EATSPACE(&p)
      if p.isEmpty {
        return
      }
      let c = p.first!
      if !(c == "\n" || c == "\r\n" || c == ";") { p.removeFirst()
      }
      switch c {
        case "\n", "\r\n", ";":
          return
        case "g":
          if gn {
            throw CompileErr("more than one number or 'g' in substitute flags")
          }
          gn = true
          s.n = 0
          
        case "p":
          s.p = true
          
        case "i", "I":
          s.icase = true
          
        case "1","2","3","4","5","6","7","8","9":
          if gn {
            throw CompileErr("more than one number or 'g' in substitute flags")
          }
          gn = true
          // parse number

          let val = p.prefix(while: \.isNumber)
          if let v = Int([c]+val) {
            s.n = v
            p = p.dropFirst(val.count)
          } else {
            throw CompileErr("overflow in the 'N' substitute flag")
          }

        case "w":
          EATSPACE(&p)
          let wbuf = p.prefix(while: {$0 != "\n" && $0 != "\r\n" })
          if wbuf.isEmpty {
            throw CompileErr("no wfile specified")
          }
          s.wfile = String(wbuf)
          if !aflag {
            do {
              s.wfd = try FileDescriptor.open(s.wfile!, .writeOnly, options: [.create], permissions: [.ownerReadWrite])
            } catch {
              err(1, "writing to \(s.wfile!): \(error)")
            }
          }
          p.removeFirst(wbuf.count)
            return
        default:
          throw CompileErr("bad flag in substitute command: '\(c)'")
      }
    }
  }
  
  /**
   * compile_tr: compile the y/// transform sets
   */
  func compile_tr(_ p: inout Substring) throws(CompileErr) -> s_tr {
    // We'll gather two sets (old, new), then fill py->bytetab, py->multis
    
    // 1) get old
    let oldStr = try compile_delimited(&p, true)
    if oldStr == nil {
      throw CompileErr("unterminated transform source string")
    }
    // 2) get new
    let newStr = try compile_delimited(&p, true)
    if newStr == nil {
      throw CompileErr("unterminated transform target string")
    }
    if !p.isEmpty { p.removeFirst() }
    // EATSPACE
    EATSPACE(&p)
    
    if oldStr!.count != newStr!.count {
      throw CompileErr("transform strings are not the same length")
    }
    
    let py = s_tr()
    for (a,b) in zip(oldStr!, newStr!) {
      py.bytetab[a] = b
    }
    return py
  }
  
  /**
   * compile_text: gather lines until an unescaped newline.
   */
  func compile_text(_ cs : inout CompileState, _ options: inout CommandOptions) async throws -> String {
    
    var text = ""
    
    while true {
        if let nl = try await cs.st.cu_fgets(&options) {
          var nextline = nl.last == "\n" || nl.last == "\r\n" ? nl.dropLast() : Substring(nl) // ditch the \n
          if nextline.last == "\\" {
            text.append(contentsOf: nextline.dropLast())
            text.append("\n")
          } else {
            text.append(contentsOf: nextline)
            text.append("\n")
            break
          }
        } else {
          break
        }
    }
    return text
  }

  /**
   * compile_addr: parse an address (line number, /re/, $)
   */
  func compile_addr(_ p: inout Substring,
                    _ cs : inout CompileState,
                    _ options : CommandOptions) throws(CompileErr) -> s_addr {
    guard !p.isEmpty else {
      fatalError("expected context address")
    }
    switch p.first! {
      case "\\":
        p.removeFirst()
        fallthrough
      case "/":
        // regex
        guard let reString = try compile_delimited(&p, false) else {
          throw CompileErr("unterminated regular expression")
        }

        // Because I changed compile_delimited to leave the trailing delimiter in (for s///)
        p.removeFirst()
        
        // check for 'I' case
        var icase = false
        if p.first == "I" {
          icase = true
          p.removeFirst()
        }

        if reString.isEmpty {
          return s_addr.AT_RE(nil, nil)
        } else {
          return try s_addr.AT_RE( compile_re(reString, icase, &cs, options), reString )
        }
      case "$":
        p.removeFirst()
        return s_addr.AT_LAST
      case "+":
        // relative line
        p.removeFirst()
        let k = p.prefix(while: { $0.isNumber } )
        p.removeFirst(k.count)
        return .AT_RELLINE(UInt(k)!)
      case "0"..."9":
        let k = p.prefix(while: { $0.isNumber } )
        p.removeFirst(k.count)
        return .AT_LINE(UInt(k)!)
      default:
        throw CompileErr("expected context address")
    }
  }
  
  /**
   * duptoeol(s, ctype): copy up to \n or \0 into a new Swift String.
   */
  func duptoeol(_ s: inout Substring, _ ctype: String) throws(CompileErr) -> String {
    // find length until \n or \0
    let ptr = s.prefix(while: { $0 != "\n" && $0 != "\r\n" } )
    if ptr.allSatisfy( { $0.isWhitespace } ) {
      throw CompileErr("whitespace after \(ctype)")
    }
    s = s.dropFirst(ptr.count+1)
    return String(ptr)
  }
  
  func definelabels(_ p : [s_command], _ stk : [Int], _ cs : inout CompileState) {
    for i in 0..<p.count {
      if p[i].code == ":" {
        cs.labels[p[i].t] = stk + [i]
      }
      if p[i].code == "{" {
        if case let .c(cc) = p[i].u {
          definelabels(cc, stk + [i], &cs)
        }
      }
    }
  }

  func checklabels(_ p : [s_command], _ cs : CompileState) throws {
    for i in 0..<p.count {
      if p[i].code == "b" || p[i].code == "t" {
        if !p[i].t.isEmpty {
          guard let _ = cs.labels[p[i].t] else {
            throw CompileErr("undefined label '\(p[i].t)'")
          }
        }
      }
      if p[i].code == "{" {
        if case let .c(cc) = p[i].u {
          try checklabels(cc, cs)
        }
      }
    }
  }

  
  
  /**
   * fixuplabel: convert branch label names to addresses, count a/r commands, etc.
   */
    
    // FIXME: do the appendnum thing
/*  func fixuplabel(cmd: inout [s_command], _ cs : CompileState) throws(CompileErr) {
    var appendnum = 0

    for i in 0..<cmd.count {
      // FIXME: do I have to use cmd[i] instead of c everywhere
      // for the 'inout' to work?
      var c = cmd[i]
      switch c.code {
        case "a", "r":
          appendnum += 1
        case "b", "t":
          if c.t.isEmpty {
            // this means branch to end
            c.u = .b([])
          } else {
            if let dest = cs.labels[c.t] {
              c.u = .b(dest)
            } else {
              throw CompileErr("undefined label '\(c.t)'")
            }
            c.t = ""
          }
          cmd[i]=c
        case "{":
          if case var .c(cc) = c.u {
            try fixuplabel(cmd: &cc, cs)
            cmd[i].u = .c(cc)
          }
        default:
          break
      }
    }
    return
  }
  */
    
  /**
   * enterlabel: store the given command in labels[] for later lookup
   */
/*  func enterlabel(_ cp: s_command, _ cs : inout CompileState) throws(CompileErr) {
    if cs.labels[cp.t] != nil {
      throw CompileErr("duplicate label '\(cp.t)'")
    }
    cs.labels[cp.t] = cp
  }
  */
  
  /*
  /**
   * findlabel: look for a label in labels[] that matches name
   */
  func findlabel(_ name: String, _ cs : CompileState) -> s_command? {
    return cs.labels[name]
  }
   */
}
