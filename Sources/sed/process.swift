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

import CMigration

public enum Branch : Error {
  case to(ArraySlice<Int>)
}

class SedProcess {
  var defpreg : regex_t? = nil
  var sdone : Bool = false
  
  var appends: [any Appendable] = []

  var lastaddr = false
  var match: [regmatch_t] = []

  var maxnsub : Int = 0

//  var inpst : SourceReader!
  
  var inp : PeekableAsyncIterator?
  // here rather than in PeekableAsyncIterator because it continues across files
  var linenum : Int = 0
  var oldfname : String?
  var tmpfname : FilePath?
  
  var nflag : Bool = false
  var filelist : [String]

  var termwidth = -1

  // The C code references a few other global variables or functions not shown here:
  var outfile = FileDescriptor.standardOutput
  var outfname: String = "(standard output)"   // used in error messages
  var HS = SPACE("")
  
  var labels : [String:ArraySlice<Int>] = [:]

  var prog : [s_command]
  var options : sed.CommandOptions
  
  var quit = false
      
  var tracing = false
  
  /* The s_addr structure references the type of address. */
  enum at_type {
    case AT_RE
    case AT_LINE
    case AT_RELLINE
  }
  

  /**
   * Helper function roughly equivalent to the #define OUT() macro.
   * Writes the current pattern space to `outfile` plus a newline if needed.
   */
  func OUT(_ OS : SPACE) throws {
    try writeStringToOutfile(OS.space)
    if OS.append_newline {
      try writeStringToOutfile("\n")
    }
  }
  
  /**
   * The main function from process.c
   */
  init( _ cs : sed.CompileState, _ options : sed.CommandOptions) {
    
    // FIXME: create sedstate from compilestate?
    
    maxnsub = cs.maxnsub
    match = Array(repeating: regmatch_t(), count: cs.maxnsub+1)
    labels = cs.labels
    
    // The loop: for each line from the input, store it in PS
    //    var st = sedState.inpst
    filelist = options.files
    nflag = options.nflag
    
    prog = cs.prog
    self.options = options
  }
  
  func process() async throws {
    while let ppp = try await mf_fgets() {
      var PS = SPACE( ppp )
      
      // FIXME: branching is tricky if I don't have linked lists with pointers.
      // the solution is to pop up the stack to here (either with a throw or by multiple returns)
      // and providing an array of command indices to navigate to:
      // e.g. [4,2] means starting with the original prog -- go to the fourth command, and then the second command of that block
      var branch : ArraySlice<Int> = []
      while true {
        do {
          try await process_line(&PS, &prog, branch)
          break
        } catch Branch.to(let e) {
//          print("branch to \(e)")
          if e.isEmpty { break }
          branch = e
        }
      }
      
      if !nflag && !PS.deleted {
        try OUT(PS)
      }
      try flush_appends()

    } // while cp != nil
    
    // label 'new': After finishing the commands for this line
    // if !nflag && !pd => OUT()
    
  } // while lines in input

  func process_line(_ PS : inout SPACE, _ prog : inout [s_command], _ branch : ArraySlice<Int>) async throws {
    var bb = branch
    for (i, cp) in prog.enumerated().dropFirst(bb.first ?? 0) {
      if bb.count > 1 {
        bb.removeFirst()
        if case .c(var cc) = cp.u {
          try await process_line(&PS, &cc, bb)
//          cp.u = .c(cc)
          continue
        }
        fatalError("branch target error")
      }
      
      let (sl, b) = try await applies(PS, cp)
      prog[i].startline = sl
      if (!b) { continue }
      
      if tracing {
        cp.trace()
        print("PS: \(PS.space)")
        print("HS: \(HS.space)")
      }
      
      switch cp.code {
        case "{":
          if case .c(var cc) = cp.u {
            try await process_line(&PS, &cc, branch.dropFirst())
            prog[i].u = .c(cc)
          } else {
            fatalError("not possible")
          }
        case "a":
          appends.append(cp.t) // s_appends(type: .AP_STRING, s: cp.t))
          
        case "b":
          if cp.t.isEmpty { throw Branch.to([]) }
          if let b = labels[cp.t] {
            throw Branch.to(b)
          } else {
            throw CmdErr(1, "undefined label '\(cp.t)'")

/*
            try await process_line(&PS, &cc, &options, &sedState)
            // FIXME: this finds the label -- but it should give me the subarray from the label to the end
            // probably mucked up by "fixlabels"
            prog[i].u = .c(cc)
            return
 */
          }
          fatalError("not possible")
        case "c":
          PS.deleted = true
          PS.space = ""
          let b = cp.a2 == nil || lastaddr
          let bb = if b {
            b
          } else {
            await lastline()
          }
          if bb {
            // c command prints cp->t
            try `writeStringToOutfile`(cp.t)
          }
          
        case "d":
          PS.deleted = true
          // goto new: basically we go to the bottom of the loop
          // That means we skip the rest and do OUT() if needed, then next line
          //            gotoNew()
          // return  // in C, it jumps; we replicate by returning from this function
                  // or do a 'break top-level while'. Here we simplify with a function.
          throw Branch.to([])
          
        case "D":
          if PS.deleted {
            return
          }
          // p = memchr(ps, '\n', psl)
          let pp = PS.space.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
          if pp.count == 2 {
            PS.space = String(pp[1])
            // goto top
            // FIXME: is this right?
            try await process_line(&PS, &prog, [])
          } else {
            PS.deleted = true
          }
          throw Branch.to([])
          
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
          try writeStringToOutfile(cp.t)
          
        case "l":
          try lputs(PS.space)
          
        case "n":
          if !nflag && !PS.deleted {
            try OUT(PS)
          }
          try flush_appends()
          if let nl = try await mf_fgets() {
            PS = SPACE(nl)
            /*
              PS.space = nl
            PS.deleted = false
            // FIXME: could be false if last line does not end in newline
            PS.append_newline = true
             */
          } else {
            exit(0)
            // We'll treat this as done. Return from process().
            return
          }
          
        case "N":
          try flush_appends()
          PS.space.append("\n")
          if var nl = try await mf_fgets() {
            if nl.last == "\n" {
              nl.removeLast()
              PS.append_newline = true
            } else if nl.last == "\r\n" {
              PS.append_newline = true
              nl = nl.dropLast() + "\r"
            } else {
              PS.append_newline = false
            }
            PS.space.append(nl)
          } else {
            exit(0)
            return
          }
          
        case "p":
          if PS.deleted {
            break
          }
          try OUT(PS)
          
        case "P":
          if PS.deleted {
            break
          }
          // p = memchr(ps, '\n', psl)
          let ppp = PS.space.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
          if ppp.count == 2 {
            try writeStringToOutfile(ppp[0]+"\n")
          } else {
            try OUT(PS)
          }
          

        case "q":
          if options.inplace == nil {
            if !nflag && !PS.deleted {
              try OUT(PS)
            }
            try flush_appends()
            exit(0)
          }
          quit = true
          
        case "r":
          try? appends.append(FileDescriptor(forReading: cp.t)) // s_appends(type: .AP_FILE, s: cp.t))

        case "s":
          let j = try substitute(&PS, cp)
          sdone = sdone || j
          
          
        case "t":
          if sdone {
            sdone = false
            if cp.t.isEmpty { throw Branch.to([]) }
            if let b = labels[cp.t] {
              throw Branch.to(b)
            } else {
              throw CmdErr(1, "undefined label '\(cp.t)'")
            }
          }

        case "w":
          if PS.deleted {
            break
          }
          if case var .fd(fh) = cp.u {
            if fh == nil {
              // open file for writing
              fh = try openFileForWCommand(cp.t)
              prog[i].u = .fd(fh)
              //            cp.fd = fh
            }
            fh!.write(PS.space)
            fh!.write("\n")
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
          try writeStringToOutfile("\(linenum)\n")
          
        default:
          break
      }
    }
  }

  // FIXME: there is more to it than this
  func lastline() async -> Bool {
    let t = try? await peek()
    return t == nil
  }
  /**
   * The function that determines if a command applies to the current line.
   * Matches addresses, etc. Return 1 if it applies, 0 if not.
   */
  // inout s_command is for cp.startline
  func applies(_ PS : SPACE, _ cp: s_command) async throws -> (Int, Bool) {
    lastaddr = false
    var res = cp.startline
    if cp.a1 == nil && cp.a2 == nil {
      return (res, !cp.nonsel) // if ! flag then invert
    } else if let a2 = cp.a2 {
      if cp.startline > 0 {
        switch a2 {
          case .AT_RELLINE(let u_int):
            // if (linenum - cp->startline <= cp->a2->u.l)
            if linenum - cp.startline <= u_int {
              if (tracing) {
                print("RELLINE: \(u_int)")
              }
              return (res, !cp.nonsel)
            } else {
              return (0, cp.nonsel)
            }
          default:
            if try await MATCH(PS, a2) {
              lastaddr = true
              return (0, !cp.nonsel)
            } else if case let .AT_LINE(u_int) = a2, linenum > u_int {
              return (0, cp.nonsel)
            } else {
              return (res, !cp.nonsel)
            }
        }
      } else if let a1 = cp.a1, try await MATCH(PS, a1) {
        // If the second address is a number <= the line number first selected
        // or if relative line is zero => single line selected
        if let a2 = cp.a2, case let .AT_LINE(u_int) = a2, linenum >= u_int {
          lastaddr = true
        } else if case let .AT_RELLINE(u_int) = a2, u_int == 0 {
          lastaddr = true
        } else {
          // FIXME: move startline to sedState?
          res = linenum
        }
        return (res, !cp.nonsel)
      } else {
        return (res, cp.nonsel)
      }
    } else if let a1 = cp.a1 {
      if try await MATCH(PS, a1) {
        return (res, !cp.nonsel)
      } else {
        return (res, cp.nonsel)
      }
    }
    return (res, false)
  }

  /*
   * Helper function that checks if an address matches the current line.
   * In the original code: #define MATCH(a) ...
   */
  func MATCH(_ PS : SPACE, _ a: s_addr) async throws -> Bool {
    switch a {
      case .AT_RE(let regexp, let src):
        let k = try regexec_e(regexp, PS.space, 0, true, 0, Int64(PS.space.count))
        if tracing {
          print("applies (\(k)) \(src)")
        }
        return k
      case .AT_LINE(let u_int):
        let k = linenum == u_int
        if tracing {
          print("applies (\(k)) \(u_int)")
        }
        return k
      case .AT_RELLINE:
        // Not used in MATCH directly in the original macro,
        // but the code does check for relative line within applies().
        return false
      case .AT_LAST:
        return try await nil == peek()

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
  func substitute(_ PS : inout SPACE, _ cp: s_command) throws -> Bool {
    guard case let .s(ssub) = cp.u else { return false }

    var s = PS.space
    let re = ssub.re
    if re == nil {
      // error if defpreg is also nil
      if defpreg != nil &&
          ssub.maxbref > defpreg!.re_nsub {
        linenum = ssub.linenum
        throw CompileErr("\(ssub.maxbref) not defined in the RE")
      }
    }

    if tracing {
      print("substitute \(ssub.src!) -> \(ssub.tgt!)" )
    }
    
    // Try to match.
    if try !regexec_e(re, PS.space, 0, false, 0, Int64(PS.space.utf8.count)) {
      return false
    }
    
    // Probably this just needs to be a String
    var SS = SPACE("") // substitute space
    var n = ssub.n  // 'n' is the numeric suffix of s/// (e.g. s/xxx/yyy/2)
    var lastempty = true
    
    var le: Int = 0
    var done = false
    
    repeat {
      // Copy the leading retained string
      if n <= 1 && match[0].rm_so > le {
        SS.space.append(contentsOf: s.prefix(Int(match[0].rm_so) - le) )
      }
      
      // Skip zerolength matches right after other matches.

      if lastempty || Int(match[0].rm_so) - le != 0 || match[0].rm_eo != match[0].rm_so {
        if n <= 1 {
          // Want this match: append replacement
          regsub(match, &SS, PS.space, ssub.new! )
          if n == 1 { n = -1 }
        } else {
          // Want a later match: append original.
          if Int(match[0].rm_eo) - le != 0 {
            SS.space.append(contentsOf: s.prefix( Int(match[0].rm_eo) - le))
          }
          n -= 1
        }
      }
      
      // move past this match
      s = String(PS.space.utf8.dropFirst(Int(match[0].rm_eo)))!
      le = Int(match[0].rm_eo)
      
      // After a zero-length match, advance one byte, and at the end of the line, terminate.b
      if match[0].rm_so == match[0].rm_eo {
        // zero-length match
        if s.isEmpty || s.first == "\n" {
          done = true
        }
        
        if !s.isEmpty {
          // advance one character
          SS.space.append(s.first!) // (&SS, ps! + sPtr, 1, .APPEND)
          let k = s.removeFirst()
          le += k.utf8.count
        }
        lastempty = true
      } else {
        lastempty = false
      }
    } while try n >= 0 && s.count >= 0 && !done && regexec_e(re, PS.space, Int(REG_NOTBOL),
//                                             NSRegularExpression.Options(rawValue: 0),
                                                             false, Int64(le), Int64(PS.space.utf8.count)
    )
    
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
      try OUT(PS)
    }
    // If 'w' is set
    if let wfile = ssub.wfile, !PS.deleted {
      if ssub.wfd == nil {
        ssub.wfd = try openFileForWCommand(wfile)
      }
      // write pattern space to ssub.wfd
      ssub.wfd?.write(PS.space)
      ssub.wfd?.write("\n")
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
  func flush_appends() throws {
    for ap in appends {
      switch ap {
        case is String: // .AP_STRING:
          try writeStringToOutfile(ap as! String)
        case is FileDescriptor: // .AP_FILE:
          // read the file and write it to outfile
          do {
            let f = ap as! FileDescriptor
              // read in chunks
            while true {
              let data = try f.readUpToCount(8*1024)
              if data.count == 0 { break }
              try outfile.write(data)
            }
            try f.close()
          } catch {
            // In the original code, it's not necessarily an error if the file doesn't exist
          }
        default:
          fatalError("unexpected append type")
      }
    }
    appends.removeAll()
    sdone = false
    // check if output is in error
    // In Swift, you'd check with `outfile.streamError`, etc. If there's an error, you can fail.
  }
  
  let escapes : [Character : String ] = ["\u{07}" : "\\a",
                                     "\u{08}" : "\\b",
                                     "\u{0c}" : "\\f",
                                     "\u{0d}" : "\\r",
                                     "\u{09}" : "\\t",
                                     "\u{0b}" : "\\v",
  ]
  /**
   * lputs -- implement the 'l' command output (show non-printable characters etc.).
   * In the original code, it does advanced handling, column wrapping, etc.
   * We'll replicate in simplified form.
   */
  func lputs(_ s : String) throws {
    if outfile != FileDescriptor.standardOutput {
      termwidth = 60
    }
    var win = winsize()
    
    // Set the termwidth if it has not yet been set
    if termwidth == -1 {
      if let c = getenv("COLUMNS"), !c.isEmpty {
        if let cc = Int(c) {
          termwidth = cc
        }
      } else if
        ioctl(FileDescriptor.standardOutput.rawValue, TIOCGWINSZ, &win) != 0 && win.ws_col > 0 {
          termwidth = Int(win.ws_col)
        } else {
          termwidth = 60
        }
      }
      if termwidth <= 0 {
        termwidth = 1
      }
      
    // Start processing the 'l' command
      var col = 0
      for wc in s {
        if wc == "\n" {
          if col + 1 >= termwidth {
            outfile.write("\\\n")
          }
          outfile.write("$\n")
          col = 0
/*        } else if wc == "\r\n" {
          if col + 1 >= termwidth {
            outfile.write("\\\n")
          }
          outfile.write("$\n")
          col = 0
 */
        } else if wc.iswprint {
          let width = wc.wcwidth
          if col + width >= termwidth {
            outfile.write("\\\n")
            col = 0
          }
          outfile.write(String(wc))
          col += width
        } else if let ewc = escapes[wc] {
          if col + 2 >= termwidth {
            outfile.write("\\\n")
            col = 0
          }
          outfile.write(ewc)
          col += ewc.count
        } else {
          let k = wc.utf16.map { $0.magnitude }
          if col + 4 * k.count >= termwidth {
            outfile.write("\\\n")
            col = 0
          }
          for kk in k {
            let z = cFormat("\\%03o", kk)
            outfile.write(z)
          }
          col += 4 * k.count
        }
      }
      if col + 1 >= termwidth {
        outfile.write("\\\n")
      }
      outfile.write("$\n")
    }
  
  
  func regexec_e(_ preg : regex_t?, _ string : String,
                 _ eflags : Int, _ nomatch : Bool,
                 _ start : Int64, _ stop: Int64)
  throws(CmdErr)-> Bool
  {
    
    if (preg == nil) {
      if (defpreg == nil) {
        errx(1, "first RE may not be empty")
      }
    } else {
      defpreg = preg;
    }
    
    /* Set anchors */
    match[0].rm_so = start;
    match[0].rm_eo = stop;
    
    let eval =
    
    withUnsafeMutablePointer(to: &match[0]) { mp in
      withUnsafeMutablePointer(to: &defpreg!) { dp in
        regexec(dp, string,
                nomatch ? 0 : maxnsub + 1, mp, Int32(eflags) | REG_STARTEND);
      }
    }
    
    switch eval {
    case 0:
      return true
    case REG_NOMATCH:
      return false
    default:
        let se = regerror(eval, defpreg!)
      throw CmdErr(1, "RE on \(string) error: \(se)")
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
          sp.space.append(contentsOf: String(stringPtr.utf8.dropFirst(so).prefix(length))!) // appendToSPACE(&sp, stringPtr + so, length)
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
  

  /*
  func writeFd(_ fd: Int32, _ buf: UnsafeMutablePointer<CChar>?, _ length: Int) {
    guard let buf = buf else { return }
    let written = write(fd, buf, length)
    if written != length {
      err(1, "Error writing to fd \(fd)")
    }
  }
  
  func writeFd(_ fd: FileDescriptor, _ str: String) {
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
   * Helper to write a String to outfile (FileDescriptor)
   */
  // FIXME: combine with OUT() ?
  func writeStringToOutfile(_ s: String) throws {
      outfile.write(s)
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
