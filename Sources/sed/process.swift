// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file containing the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1992 Diomidis Spinellis.
  Copyright (c) 1992, 1993, 1994
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

import Foundation
import CMigration

extension sed {
  /* The s_addr structure references the type of address. */
  enum at_type {
    case AT_RE
    case AT_LINE
    case AT_RELLINE
  }
  
  /* Global variables used throughout process.c */
  
//  var HS = SPACE("")
 // var PS = SPACE("")
//  var SS = SPACE("")
//  var YS = SPACE("")

//  var pd : Bool {
//    get { PS.deleted }
//    set { PS.deleted = newValue }
//  }
  
//  var ps : String {
//    get { PS.space }
//    set { PS.space = newValue }
//  }
  
//  var psl : Int {
//    get { PS.space.count }
//  }
  
  //  #define psanl PS.append_newline

//  var hs : String {
//    get { HS.space }
//    set { HS.space = newValue }
//   }

  //  #define hsl HS.len
  
  /*
   * Additional global variables from the original code.
   */
  
  /* We’ll store a global reference to default regex, plus the array of regmatch_t.
   * In the original code, maxnsub is size_t; match is an array of regmatch_t.
   * We replicate the spirit using Swift’s NSRegularExpression matches.
   */
//  var defpreg: NSRegularExpression? = nil
  
  // We'll store matches in a global array or just keep them ephemeral in regexec_e
  // but to keep the translation near-literal, we define a placeholder structure:
/*  struct regmatch_t {
    var rm_so: Int = -1
    var rm_eo: Int = -1
  }
  */
  
  struct SedState {
    var defpreg : regex_t? = nil
    var sdone : Bool = false
    
    var appends: [s_appends] = []

    var lastaddr = false
    var match: [regmatch_t] = []

    var maxnsub : Int = 0

    var inpst = inp_state()
    
    // The C code references a few other global variables or functions not shown here:
    var outfile: FileHandle = FileHandle.standardOutput
    var outfname: String = "(standard output)"   // used in error messages
  }
    

  /**
   * Helper function roughly equivalent to the #define OUT() macro.
   * Writes the current pattern space to `outfile` plus a newline if needed.
   */
  func OUT(_ OS : SPACE, _ sedState : SedState) throws {
    try writeStringToOutfile(OS.space, sedState)
    if OS.append_newline {
      try writeStringToOutfile("\n", sedState)
    }
  }
  
  /**
   * The main function from process.c
   */
  func process(_ prog : [s_command], _ cs : CompileState, _ options : CommandOptions) async throws {
    
    // FIXME: create sedstate from compilestate?
    var sedState = SedState()
    sedState.maxnsub = cs.maxnsub
    sedState.match = Array(repeating: regmatch_t(), count: cs.maxnsub+1)
    
    // The loop: for each line from the input, store it in PS
    var st = sedState.inpst
    st.nflag = options.nflag
    st.script = options.files.map { s_compunit.CU_FILE($0) }
    
    while let ppp = try await mf_fgets(&st, options) {
      var PS = SPACE(ppp)
      // FIXME: could be false if last line doesn't end in \n
      PS.append_newline = true
      
      try await process_line(&PS, prog, options, &sedState)
    newLineLabel:
      if !st.nflag && !PS.deleted {
        try OUT(PS, sedState)
      }
      try flush_appends(&sedState)

    } // while cp != nil
    
    // label 'new': After finishing the commands for this line
    // if !nflag && !pd => OUT()
    
  } // while lines in input

  func process_line(_ PS : inout SPACE, _ prog : [s_command], _ options : CommandOptions, _ sedState : inout SedState) async throws {
    
    var HS = SPACE("")
    
    for cp in prog {
      guard try applies(PS, cp, &sedState) else { continue }
      
      switch cp.code {
        case "{":
          if case .c(let cc) = cp.u {
            try await process_line(&PS, cc, options, &sedState)
            return
          }
          fatalError("not possible")
        case "a":
          sedState.appends.append(s_appends(type: .AP_STRING, s: cp.t))
          
        case "b":
          if case .c(let cc) = cp.u {
            try await process_line(&PS, cc, options, &sedState)
            return
          }
          fatalError("not possible")
        case "c":
          PS.deleted = true
          PS.space = ""
          if cp.a2 == nil || sedState.lastaddr
              // FIXME: I don't know how to do this test!!
//              || lastline()
          {
            // c command prints cp->t
            try writeStringToOutfile(cp.t, sedState)
          }
          
        case "d":
          PS.deleted = true
          // goto new: basically we go to the bottom of the loop
          // That means we skip the rest and do OUT() if needed, then next line
          //            gotoNew()
          return  // in C, it jumps; we replicate by returning from this function
                  // or do a 'break top-level while'. Here we simplify with a function.
          
        case "D":
          if PS.deleted {
            return
          }
          // p = memchr(ps, '\n', psl)
          let pp = PS.space.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
          if pp.count == 2 {
            PS.space = String(pp[1])
            // goto top
            try await process_line(&PS, prog, options, &sedState)
            return
          } else {
            PS.deleted = true
            return
          }
          
        case "g":
          PS.space = HS.space
          
        case "G":
          PS.space.append("\n")
          PS.space.append(HS.space)
          
        case "h":
          HS.space = PS.space
          
        case "H":
          HS.space.append("\n")
          HS.space.append(PS.space)
          
        case "i":
          try writeStringToOutfile(cp.t, sedState)
          
        case "l":
          try lputs(PS.space, sedState)
          
        case "n":
          if !sedState.inpst.nflag && !PS.deleted {
            try OUT(PS, sedState)
          }
          try flush_appends(&sedState)
          if let nl = try await mf_fgets(&sedState.inpst, options) {
            PS.space = nl
            PS.deleted = false
            // FIXME: could be false if last line does not end in newline
            PS.append_newline = true
          } else {
            exit(0)
            // We'll treat this as done. Return from process().
            return
          }
          
        case "N":
          try flush_appends(&sedState)
          PS.space.append("\n")
          if let nl = try await mf_fgets(&sedState.inpst, options) {
            PS.space.append(nl)
            // FIXME: could be false if last line does not end in newline
            PS.append_newline = true
          } else {
            exit(0)
            return
          }
          
        case "p":
          if PS.deleted {
            break
          }
          try OUT(PS, sedState)
          
        case "P":
          if PS.deleted {
            break
          }
          // p = memchr(ps, '\n', psl)
          let ppp = PS.space.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
          if ppp.count == 2 {
            try writeStringToOutfile(ppp[0]+"\n", sedState)
          } else {
            try OUT(PS, sedState)
          }
          

        case "q":
          if options.inplace == nil {
            if !sedState.inpst.nflag && !PS.deleted {
              try OUT(PS, sedState)
            }
            try flush_appends(&sedState)
            return
          }
          quit = true
          
        case "r":
          sedState.appends.append(s_appends(type: .AP_FILE, s: cp.t))
          
        case "s":
          let j = try substitute(&PS, cp, &sedState)
          sedState.sdone = sedState.sdone || j
          
          
        case "t":
          fatalError("not yet implemented")
          // FIXME: put this back
          /*
          if sedState.sdone {
            sedState.sdone = false
            cp = cp.c
            continue redirect
          }
          */
          
        case "w":
          if PS.deleted {
            break
          }
          if case var .fd(fh) = cp.u {
            if fh == nil {
              // open file for writing
              fh = try openFileForWCommand(cp.t)
              cp.u = .fd(fh)
              //            cp.fd = fh
            }
            try fh!.write(contentsOf: PS.space.data(using: .utf8)!)
            try fh!.write(contentsOf: "\n".data(using: .utf8)!)
          }
        case "x":
          // swap PS and HS
          let tspace = PS
          PS = HS
          PS.append_newline = tspace.append_newline
          HS = tspace
          
        case "y":
          if !PS.deleted && !PS.space.isEmpty {
            if case let .y(tr) = cp.u {
              PS.space = do_tr(PS.space, tr)
            }
          }
          
        case ":":
          // label
          break
        case "}":
          // end of block
          break
        case "=":
          // print line number
          try writeStringToOutfile("\(sedState.inpst.linenum)\n", sedState)
          
        default:
          break
      }
    }
  }

  /**
   * The function that determines if a command applies to the current line.
   * Matches addresses, etc. Return 1 if it applies, 0 if not.
   */
  func applies(_ PS : SPACE, _ cp: s_command, _ sedState : inout SedState) throws -> Bool {
    sedState.lastaddr = false
    if cp.a1 == nil && cp.a2 == nil {
      return !cp.nonsel // if ! flag then invert
    } else if let a2 = cp.a2 {
      if cp.startline > 0 {
        switch a2 {
          case .AT_RELLINE(let u_int):
            // if (linenum - cp->startline <= cp->a2->u.l)
            if sedState.inpst.linenum - cp.startline <= u_int {
              return !cp.nonsel
            } else {
              cp.startline = 0
              return cp.nonsel
            }
          default:
            if try MATCH(PS, a2, &sedState) {
              cp.startline = 0
              sedState.lastaddr = true
              return !cp.nonsel
            } else if case let .AT_LINE(u_int) = a2, sedState.inpst.linenum > u_int {
              cp.startline = 0
              return cp.nonsel
            } else {
              return !cp.nonsel
            }
        }
      } else if let a1 = cp.a1, try MATCH(PS, a1, &sedState) {
        // If the second address is a number <= the line number first selected
        // or if relative line is zero => single line selected
        if let a2 = cp.a2, case let .AT_LINE(u_int) = a2, sedState.inpst.linenum >= u_int {
          sedState.lastaddr = true
        } else if case let .AT_RELLINE(u_int) = a2, u_int == 0 {
          sedState.lastaddr = true
        } else {
          cp.startline = sedState.inpst.linenum
        }
        return !cp.nonsel
      } else {
        return cp.nonsel
      }
    } else if let a1 = cp.a1 {
      if try MATCH(PS, a1, &sedState) {
        return !cp.nonsel
      } else {
        return cp.nonsel
      }
    }
    return false
  }

  /*
   * Helper function that checks if an address matches the current line.
   * In the original code: #define MATCH(a) ...
   */
  func MATCH(_ PS : SPACE, _ a: s_addr, _ sedState : inout SedState) throws -> Bool {
    switch a {
      case .AT_RE(let regexp):
        return try regexec_e(regexp, PS.space, 0, true, 0, Int64(PS.space.count), &sedState)
      case .AT_LINE(let u_int):
        return sedState.inpst.linenum == u_int
      case .AT_RELLINE:
        // Not used in MATCH directly in the original macro,
        // but the code does check for relative line within applies().
        return false
      case .AT_LAST:
      fatalError("unimplemented")
    }
  }
  
  /*
   * Reset the sed processor to initial state.
   */
  // FIXME: need to put this back when I reinstate
  // mf_fgets
  /*
  func resetstate() {
    var cp = prog
    while let c = cp {
      if c.a2 != nil {
        c.startline = 0
      }
      if c.code == "{" {
        var sub = c.c
        while let s = sub {
          if s.a2 != nil {
            s.startline = 0
          }
          sub = s.next
        }
      }
      cp = c.next
    }
    // Clear out the hold space
    hs = ""
  }
  */
  
  /**
   * The 'substitute()' function. This does 's///' substitutions in the pattern space.
   */
  func substitute(_ PS : inout SPACE, _ cp: s_command, _ sedState : inout SedState) throws -> Bool {
    guard case let .s(ssub) = cp.u else { return false }

    var s = PS.space
    let re = ssub.re
    if re == nil {
      // error if defpreg is also nil
      if sedState.defpreg != nil &&
          ssub.maxbref > sedState.defpreg!.re_nsub {
        sedState.inpst.linenum = ssub.linenum
        throw CompileErr("\(ssub.maxbref) not defined in the RE")
      }
    }

    // Try to match.
    if try !regexec_e(re, PS.space, 0, false, 0, Int64(PS.space.count), &sedState) {
      return false
    }
    
    // Probably this just needs to be a String
    var SS = SPACE("") // substitute space
    
    var slen = PS.space.count
    var n = ssub.n  // 'n' is the numeric suffix of s/// (e.g. s/xxx/yyy/2)
    var lastempty = true
    
    var le: Int = 0
    var sPtr = 0
    
    repeat {
      // Copy the leading retained string
      if n <= 1 && sedState.match[0].rm_so > le {
        SS.space.append(contentsOf: s.prefix(Int(sedState.match[0].rm_so) - le) )
      }
      
      // Skip zerolength matches right after other matches.

      if lastempty || Int(sedState.match[0].rm_so) - le != 0 || sedState.match[0].rm_eo != sedState.match[0].rm_so {
        if n <= 1 {
          // Want this match: append replacement
          regsub(sedState.match, &SS, s, ssub.new! )
          if n == 1 { n = -1 }
        } else {
          // Want a later match: append original.
          if Int(sedState.match[0].rm_eo) - le != 0 {
            SS.space.append(contentsOf: s.prefix( Int(sedState.match[0].rm_eo) - le))
          }
          n -= 1
        }
      }
      
      // move past this match
      s = String(PS.space.dropFirst(Int(sedState.match[0].rm_eo)))
      le = Int(sedState.match[0].rm_eo)
      
      // After a zero-length match, advance one byte, and at the end of the line, terminate.b
      if sedState.match[0].rm_so == sedState.match[0].rm_eo {
        // zero-length match
        if s.isEmpty || s.first == "\n" {
          slen = -1
        }
        
        if !s.isEmpty {
          // advance one character
          SS.space.append(s.first!) // (&SS, ps! + sPtr, 1, .APPEND)
          s.removeFirst()
          le += 1
        }
        lastempty = true
      } else {
        lastempty = false
      }
    } while try n >= 0 && s.count >= 0 && regexec_e(re, PS.space,
                                                    Int(REG_NOTBOL),
//                                             NSRegularExpression.Options(rawValue: 0),
                                             false, Int64(le), Int64(PS.space.count),
    &sedState)
    
    // if n > 0 => not enough matches found
    if n > 0 {
      return false
    }
    
    // copy trailing part
    SS.space.append(contentsOf: s)
    
    // swap the substitute space and pattern space
    let tspace = PS
    PS = SS
    PS.append_newline = tspace.append_newline
    SS = tspace
    
    // FIXME: does this do anything?
//    SS.space = SS.back
    
    // If the 'p' flag is set, output
    if ssub.p {
      try OUT(PS, sedState)
    }
    // If 'w' is set
    if let wfile = ssub.wfile, !PS.deleted {
      if ssub.wfd == nil {
        ssub.wfd = try openFileForWCommand(wfile)
      }
      // write pattern space to ssub.wfd
      try ssub.wfd?.write(contentsOf: PS.space.data(using: .utf8)!)
      try ssub.wfd?.write(contentsOf: "\n".data(using: .utf8)!)
    }
    return true
  }
  
  /**
   * do_tr -- Perform translation in the pattern space for the 'y' command.
   */
  func do_tr(_ ps : String, _ y: s_tr) -> String {
    // If single-byte locale, we can do in-place
    // For simplicity, we skip the multi-byte logic detail.
    // We just do in-place translation via the bytetab table.
    guard !ps.isEmpty else { return ps }
    let r = ps.map {i in
      // FIXME: what if not an ascii character?
//      let idx = i.asciiValue!
      let mapped = y.bytetab[i]
      // if mapped != 0, that is the mapped char.  If mapped == 0, no mapping?
      // Original code deals with multi expansions, etc.
      // We'll just do single-byte for demonstration.
      if let mapped {
        return mapped
      } else {
        return i
      }
    }
    return String(r)
  }
  
  /**
   * flush_appends -- flush out the 'a' and 'r' commands collected in appends[].
   */
  func flush_appends(_ sedState : inout SedState) throws {
    for ap in sedState.appends {
      switch ap.type {
        case .AP_STRING:
          try writeStringToOutfile(ap.s, sedState)
        case .AP_FILE:
          // read the file and write it to outfile
          do {
            let f = try FileHandle(forReadingFrom: URL(filePath: ap.s))
              // read in chunks
            while let data = try f.read(upToCount: 8*1024) {
              try sedState.outfile.write(contentsOf: data)
            }
            try f.close()
          } catch {
            // In the original code, it's not necessarily an error if the file doesn't exist
          }
      }
    }
    sedState.appends.removeAll()
    sedState.sdone = false
    // check if output is in error
    // In Swift, you'd check with `outfile.streamError`, etc. If there's an error, you can fail.
  }
  
  /**
   * lputs -- implement the 'l' command output (show non-printable characters etc.).
   * In the original code, it does advanced handling, column wrapping, etc.
   * We'll replicate in simplified form.
   */
  func lputs(_ s : String, _ sedState : SedState) throws {
    if s.isEmpty {
      try writeStringToOutfile("$\n", sedState)
      return
    }
    // For brevity, we simply show each byte's ASCII or escaped form
    var out = ""
    for c in s {
      if c == "\n" {         // newline
        out.append("$\n")
      } else if let x = c.asciiValue, x < 32 {
        // escape
        out.append("\\")
        out.append(String(format: "%03o", x))
      } else {
        out.append(c)
      }
    }
    out.append("$\n")
    try writeStringToOutfile(out, sedState)
  }
  
  
  func regexec_e(_ preg : regex_t?, _ string : String,
                 _ eflags : Int, _ nomatch : Bool,
                 _ start : Int64, _ stop: Int64,
                 _ sedState: inout SedState)
  throws(CmdErr)-> Bool
  {
    
    if (preg == nil) {
      if (sedState.defpreg == nil) {
        errx(1, "first RE may not be empty")
      }
    } else {
      sedState.defpreg = preg;
    }
    
    /* Set anchors */
    sedState.match[0].rm_so = start;
    sedState.match[0].rm_eo = stop;
    
    let eval =
    
    withUnsafeMutablePointer(to: &sedState.match[0]) { mp in
      withUnsafeMutablePointer(to: &sedState.defpreg!) { dp in
        regexec(dp, string,
                nomatch ? 0 : sedState.maxnsub + 1, mp, Int32(eflags) | REG_STARTEND);
      }
    }
    
    switch eval {
    case 0:
      return true
    case REG_NOMATCH:
      return false
    default:
      let se = withUnsafeMutablePointer(to: &sedState.defpreg!) { dp in
        regerror(eval, dp, nil, 0)
      }
      throw CmdErr(1, "RE error: \(se)")
    }
    /* NOTREACHED */
  }

  /*
  /**
   * regexec_e -- a specialized re-run of regexec that sets up the match[] array.
   * Returns true if it matched, false otherwise.
   * The original code used a custom regexec with an offset. We mimic that logic with Swift’s NSRegularExpression.
   */
  func nsregexec_e(_ preg: NSRegularExpression?,
                 _ stringPtr: UnsafeMutablePointer<CChar>?,
                 _ eflags: Int,
                 _ nomatch: Int,
                 _ start: Int,
                 _ stop: Int) -> [regmatch_t]
  {
    let re = (preg != nil ? preg : defpreg)
    guard let stringPtr = stringPtr, let re = re else {
      return []
    }
    // Convert the portion from start..stop into a Swift String
    let fullLen = stop - start
    if fullLen < 0 { return [] }
    let buffer = UnsafeBufferPointer(start: stringPtr + start, count: fullLen)
    let subString = String(decoding: Array(buffer), as: UTF8.self)
    
    var match = [regmatch_t]()
    
    do {
      // Try to match at the beginning
      // The original code logic might require searching from the start only,
      // or globally. We'll do a single match from the start here:
      let nsString = subString as NSString
      let results = re.firstMatch(in: subString, options: [], range: NSRange(location: 0, length: nsString.length))
      if let res = results {
        // populate match[0..] with the captures
        // We have up to maxnsub + 1 subexpressions in original code
        // but here we do a simpler approach:
        for i in 0...maxnsub {
          if i <= res.numberOfRanges {
            let rng = res.range(at: i)
            if rng.location == NSNotFound {
              match[i].rm_so = -1
              match[i].rm_eo = -1
            } else {
              match[i].rm_so = start + rng.location
              match[i].rm_eo = start + rng.location + rng.length
            }
          } else {
            match[i].rm_so = -1
            match[i].rm_eo = -1
          }
        }
        return true
      } else {
        return false
      }
    } catch {
      errx(1, "RE error: \(error)")
    }
    return false
  }
  */
  
  /**
   * strregerror() from the original code would produce a string error
   * from the regex engine. We just do a simple version here.
   */
/*  func strregerror(_ code: Int, _ preg: NSRegularExpression?) -> String {
    return "Regex error code \(code)"
  }
  */
  
  /**
   * regsub -- perform substitutions after a regexp match
   * Based on the old Henry Spencer logic. We do a simplified version for Swift.
   */
  func regsub(_ match : [regmatch_t],_ sp: inout SPACE, _ stringPtr: String, _ src: String) {
    
    // We interpret the replacement pattern in `src`.
    var i = 0
    while i < src.count {
      let c = src[src.index(src.startIndex, offsetBy: i)]
      if c == "&" {
        // substitute entire match => match[0]
        let so = Int(match[0].rm_so)
        let eo = Int(match[0].rm_eo)
        if so != -1 && eo != -1 {
          let length = eo - so
          sp.space.append(contentsOf: stringPtr.dropFirst(so).prefix(length)) // appendToSPACE(&sp, stringPtr + so, length)
        }
        i += 1
      } else if c == "\\" && (i + 1) < src.count {
        let nextC = src[src.index(src.startIndex, offsetBy: i + 1)]
        if nextC.isNumber {
          let no = Int(String(nextC)) ?? 0
          i += 2
          let so = Int(match[no].rm_so)
          let eo = Int(match[no].rm_eo)
          if so != -1 && eo != -1 {
            let length = eo - so
            sp.space.append(contentsOf: stringPtr.dropFirst(so).prefix(length)) // appendToSPACE(&sp, stringPtr + so, length)
          }
          continue
        } else if nextC == "\\" || nextC == "&" {
          // just literal
          sp.space.append(nextC)
//          appendCharToSPACE(&sp, nextC)
          i += 2
          continue
        } else {
          // unknown, treat the backslash as literal
          sp.space.append(c)
//          appendCharToSPACE(&sp, c)
          i += 1
          continue
        }
      } else {
        // ordinary char
        sp.space.append(c)
//        appendCharToSPACE(&sp, c)
        i += 1
      }
    }
  }
  
  /**
   * cspace -- concat space. Append or replace data in SPACE sp.
   */
  /*
  func cspace(_ sp: inout SPACE, _ p: String, _ spflag: e_spflag) {
    if spflag == .REPLACE {
      sp.space = ""
    }
    sp.space.append(p)
  }
  */
  
  /*
   * A tiny helper to replicate the regsub memory expansions.
   */
  /*
  func appendToSPACE(_ sp: inout SPACE, _ src: UnsafeMutablePointer<CChar>, _ length: Int) {
    cspace(&sp, src, length, .APPEND)
  }
  */
  /*
  func appendCharToSPACE(_ sp: inout SPACE, _ c: Character) {
    var local = String(c).utf8.map { CChar(bitPattern: $0) }
    local.append(0)
    cspace(&sp, local, local.count - 1, .APPEND)
  }
   */
  
  /*
   * cfclose -- close all cached open files.
   * In Swift, we track this with file descriptors if we want direct bridging to C.
   */
  // FIXME: put this back when I reinstate calling it
  /*
  func cfclose(_ start: s_command?, _ end: s_command?) {
    var cp = start
    while cp != nil && cp !== end {
      switch cp!.code {
        case "s":
          if let ssub = cp.s {
            if ssub.wfd != -1 {
              close(ssub.wfd)
            }
            ssub.wfd = -1
          }
        case "w":
          if cp.fd != -1 {
            close(cp.fd)
          }
          cp.fd = -1
        case "{":
          cfclose(cp.c, cp.next)
        default:
          break
      }
      cp = cp!.next
    }
  }
  */
  
  /**
   * Minimal file I/O helpers for the 'w' command usage.
   */
  func openFileForWCommand(_ path: String) throws(CompileErr) -> FileHandle {
    // O_WRONLY|O_APPEND|O_CREAT|O_TRUNC in the original code => open for writing
    do {
      let fd = try FileHandle(forWritingTo: URL(filePath: path))
      //    let fd = open(path, O_WRONLY | O_APPEND | O_CREAT | O_TRUNC, 0o666)
      //    if fd == -1 {
    return fd
    } catch {
      throw CompileErr("\(path): \(error.localizedDescription)")
    }
  }

  /*
  func writeFd(_ fd: Int32, _ buf: UnsafeMutablePointer<CChar>?, _ length: Int) {
    guard let buf = buf else { return }
    let written = write(fd, buf, length)
    if written != length {
      err(1, "Error writing to fd \(fd)")
    }
  }
  
  func writeFd(_ fd: FileHandle, _ str: String) {
    // Write the first count bytes of `str`
    do {
      if let d = str.data(using: .utf8) {
        try fd.write(contentsOf: d)
      }
    } catch {
      err(1, "Error writing to fd \(fd)")
    }
  }
  */
  
  /*
   * Helper to write a String to outfile (FileHandle)
   */
  // FIXME: combine with OUT() ?
  func writeStringToOutfile(_ s: String, _ sedState : SedState) throws {
    if let data = s.data(using: .utf8) {
      try sedState.outfile.write(contentsOf: data)
    }
  }
  
  /**
   * Rough equivalent to memchr in C for scanning up to "count" bytes
   * for the character c.  In actual Swift, you'd do safer operations.
   */
  /*
  func memchr(_ ptr: UnsafeMutablePointer<CChar>?, _ value: Int32, _ count: Int) -> UnsafeMutablePointer<CChar>? {
    guard let ptr = ptr else { return nil }
    for i in 0..<count {
      if ptr[i] == CChar(value) {
        return ptr + i
      }
    }
    return nil
  }
  */
  
  /*
   * In the original code, goto new: => finalize line, etc.
   * We used placeholders above. A thorough Swift rewrite should reorganize
   * the loops to remove gotos entirely.
   *
   * This completes a near-literal Swift translation of process.c.
   */
}
