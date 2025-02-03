
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 2013 Johann 'Myrkraverk' Oskarsson.
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

import Foundation
import CMigration

// We replicate the Apple usage of PATH_MAX or fallback
let PATH_MAX: Int32 = 1024

// FIXME: use the real progname
let progname = "sed"

@main final class sed : ShellCommand {

  var usage : String = """
usage: \(progname) script [-EHalnru] [-i extension] [file ...]
\t\(progname) [-EHalnu] [-i extension] [-e script] ... [-f script_file]
"""
  
  struct CommandOptions {
    var aflag : Bool = false
    var rflags : UInt32 = 0
    var eflag : Bool = false
    var nflag : Bool = false
    
    var fflag = false
    var fflagstdin = false

    var ispan: Bool = false
    var inplace: String? = nil
    
    var script : [s_compunit] = []
    var files : [String] = []
    
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() async throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "EHI:ae:f:i:lnru"
    let go = BSDGetopt(supportedFlags)

    setlocale(LC_ALL, "") // In Swift, you'd do something else or ignore.
    
    options.inplace = nil
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "r", "E":
          options.rflags |= UInt32(REG_EXTENDED)
        case "H":
          // for Apple
          // rflags |= REG_ENHANCED, but that is non-standard, so we just define a placeholder:
          let REG_ENHANCED: UInt32 = 0x80000000
          options.rflags |= REG_ENHANCED
        case "I":
          options.inplace = v
          options.ispan = true
        case "a":
          options.aflag = true
        case "e":
          // next is the script argument
          options.eflag = true
          options.script.append(s_compunit.CU_STRING(v))
        case "f":
          options.fflag = true
          if v == "-" {
            options.fflagstdin = true
          }
          options.script.append(s_compunit.CU_FILE(v))
        case "i":
          options.inplace = v
          options.ispan = false
        case "l":
          // FIXME: set line buffered output
          // Swift doesn't have direct setvbuf, but we can do best-effort or skip
          // We'll just skip or do a small warning
          // warnx("line buffering not directly supported in Swift")
          break
        case "n":
          options.nflag = true
        case "u":
          // FIXME: set unbuffered
          // Swift doesn't have direct setvbuf. We'll skip
          // warnx("unbuffered output not directly supported in Swift")
          break
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    
    // "First usage case": if no -e or -f and we have an argument => treat that argument as script
    if !options.eflag, !options.fflag, !options.args.isEmpty {
      options.script.append(s_compunit.CU_STRING(options.args[0]))
      options.args.removeFirst()
    }
    
    if !options.args.isEmpty {
      // Add each file
    
      options.files = options.args
//      for fileArg in options.args {
//        add_file(fileArg)
//
    } else if options.fflagstdin {
      // If we read script from stdin but no input files => exit
      exit(0)
    } else {
      // add_file(NULL) => means read from stdin
      options.files = ["/dev/stdin"] // add_file(nil)
    }

    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {

    var cs : CompileState
    
    // compile() the sed commands
    do {
      cs = try await compile(options)
      // Process
      try await process(cs.prog, cs, options)
      
    } catch {
      throw CmdErr(1, error.localizedDescription)
    }
    
    // close commands
    // FIXME: put this back -- close all the files
   // cfclose(prog, nil)
    
    // if fclose(stdout) ...
    // Swift doesn't have direct "stdout" as a FILE*, you might do:
    //  if let handle = stdoutFILE { ... }
    // We'll skip direct check for demonstration.

  }
  
  
  
  // ==========================================
  
  //
  // MARK: - Types and global variables mirroring main.c
  //
  
  enum s_compunit {
    case CU_FILE(String)
    case CU_STRING(String)
  }
    
  public var quit = false
  
  // Whether inplace editing spans across files
  
  public var outfname: String = ""     // Current output file name
  private var oldfname = [CChar](repeating: 0, count: Int(PATH_MAX))
  private var tmpfname = [CChar](repeating: 0, count: Int(PATH_MAX))
  
  // Swift doesn't have a direct global "program name" like getprogname() in macOS/BSD.
  // We'll define a helper or store a static name, or you might retrieve from CommandLine.arguments[0].
  func getprogname() -> String {
    return "sed"   // or extract from CommandLine.arguments[0]
  }
  
  //
  /*
  enum scriptSource {
    case ST_String(String)
    case ST_File(String)
  }
  */
  
  // We simulate static with a global or static var. For demonstration, we store in a global.
  // But let's do it with a single static instance:
  // local static states in C code
  struct inp_state {
//    var f: AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator? = nil
//    var s: String? = nil
    var inp : inpSource = .ST_EOF
    var linenum : Int = 0
    var fname : String = "?"
    var script: [s_compunit] = []
    var nflag : Bool = false
  }
  
  enum inpSource {
    case ST_EOF
    case ST_FILE(AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator, FileHandle?)
    case ST_STRING(Substring)
//    case ST_UNKNOWN
  }

//  var current_script : FileHandle = FileHandle.standardInput
  
  func next_file(_ st : inout inp_state, _ options : CommandOptions ) throws(CmdErr) -> Bool {
    // script is a global list
    if st.script.isEmpty {
      return false
    }
    st.linenum = 0
    
    switch st.script.removeFirst() {
      case .CU_FILE(let fnam):
      // open file
      if fnam == "-"  || fnam == "/dev/stdin" {
        st.inp = .ST_FILE(FileHandle.standardInput.bytes.lines.makeAsyncIterator(), nil)
        st.fname = "stdin"
        
        if options.inplace != nil {
          throw CmdErr(1, "-I or -i may not be used with stdin")
        }

        
        
      } else {
        do {
          let fh = try FileHandle(forReadingFrom: URL(filePath: fnam))
          st.inp =  .ST_FILE( fh.bytes.lines.makeAsyncIterator(), fh)
        } catch {
          throw CmdErr(1, "\(fnam): \(error.localizedDescription)")
        }
        st.fname = fnam
      }
      return true
      case .CU_STRING(let sref):
      if sref.count >= 27 {
        st.fname = "\"\(sref.prefix(24)) ...\""
      } else {
        st.fname = "\"\(sref)\""
      }
        st.inp = .ST_STRING(Substring(sref))
      // goto again
      return true
    }

  }
  
  
  
  /**
   * cu_fgets: like fgets, but reads from the chain of compilation units, ignoring empty strings/files.
   * Fills `buf` with up to `n` characters. If `more` is non-nil, it’s set to 1 if more data might be available, else 0.
   */
  func cu_fgets(_ st : inout inp_state, _ options : CommandOptions) async throws(CmdErr) -> String? {
    
  again: while true {
    switch st.inp {
          case .ST_EOF:
          if try next_file(&st, options) { continue again }
            else { return nil}

          case .ST_FILE(var fp, let fh):
            do {
              if let got = try await fp.next() {
                st.linenum += 1
                if st.linenum == 1 && got.hasPrefix("#n") {
                  st.nflag = true
                }
                return got
              }
              
              try fh?.close()
              st.inp = .ST_EOF
              continue again
            } catch {
              throw CmdErr(1, "reading \(st.fname): \(error.localizedDescription)")
            }
          case .ST_STRING(var p):
            if st.linenum == 0,
                p.hasPrefix("#n") {
              st.nflag = true
            }
            if p.isEmpty {
              st.inp = .ST_EOF
              continue again
            }
            let sPtr = p.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            if sPtr.count == 2 {
              p = sPtr[1]
              return String(sPtr[0])
            } else if sPtr.count == 1 {
              p = ""
              st.inp = .ST_EOF
              return String(sPtr[0])
            } else {
              fatalError("not possible")
            }
        }
      }
    }
    
  
  /**
   * mf_fgets: read next line from the list of files, storing in SPACE sp.
   * If spflag == REPLACE, we replace contents; if APPEND, we append.
   * Returns 1 if line read, 0 if no more lines.
   */
  /*
   * Like fgets, but go through the list of files chaining them together.
   * Set len to the length of the line.
   */

  // FIXME: mf_fgets is different than cu_fgets --
  // including resetstate
  
  func mf_fgets(_ st : inout inp_state, _ options : CommandOptions) async throws -> String? {
    // The code in C references static vars, handles inFile, oldfname, etc.
    // We'll replicate in simpler Swift form. A direct translation is tricky
    // because it uses POSIX I/O with FILE*, rename, unlink, etc. We'll do our best.
    
    // We skip some checks for S_ISREG, lstat, etc. for brevity. In real code, you'd
    // call the Swift equivalents via `FileManager`.
    // We'll replicate the logic that tries to read one line from the current inFile,
    // or else open the next file, possibly do backups, etc.
    
    // 1) If inFile is nil, open the first file or handle stdin
    // 2) If we read a character => we have data
    // 3) Else, move on to next file, etc.
    
    // Because a fully literal translation requires bridging all these calls
    // (fopen, rename, link, unlink, fchmod, fchown), below is a partial replication:
    
    // We'll do a partial approach: attempt to read a line from the current file handle
    // using a Swift helper, etc.
    
    /*
     var inFile = FileHandle.standardInput.bytes.lines.makeAsyncIterator()
     while let l = try await inFile.next() {
     
     }
     */
    
    // Pseudocode:
    while true {
      
      // open file if needed
      switch st.inp {
        case .ST_EOF:
          if try next_file(&st, options) { continue }
          else { return nil }
          
        case .ST_FILE(var fp, let fh):
          do {
            
            if let got = try await fp.next() {
              st.linenum += 1
              if st.linenum == 1 && got.hasPrefix("#n") {
                st.nflag = true
              }
              return got
            }
            NSLog("EOF")
            try fh?.close()
            st.inp = .ST_EOF
            continue
          }
          // FIXME: handle the 'inplace' option
          
        case .ST_STRING:
          fatalError("not possible")
      }
    }
  }
      
    // If we got here, we have an open inFile with data available. We'll read one line
/*
    var len = getline_swift(linePtr, 1024, inFile)
    if len < 0 {
      err(1, "\(fname)")
    }
    // check newline
    if len != 0, linePtr[len-1] == CChar(UInt8(ascii: "\n")) {
      sp.append_newline = 1
      len -= 1
    } else if !lastline() {
      sp.append_newline = 1
    } else {
      sp.append_newline = 0
    }
    // cspace => store in sp
    cspace(&sp, linePtr, spflag)
    linenum += 1
    return 1
  }
*/
  
  /**
   * lastline(): check if the current file is at EOF and no next file has lines.
   */
/*  func lastline() -> Bool {
    // The code in C checks feof(inFile), etc. Then it checks if next files have lines.
    // We'll do a partial approach:
    if feof(inFile) != 0 {
      return !((inplace == nil || ispan != 0) && next_files_have_lines() != 0)
    }
    // check next char
    if let c = fgetc(inFile) {
      ungetc(c, inFile)
      return false
    }
    // EOF
    return !((inplace == nil || ispan != 0) && next_files_have_lines() != 0)
  }
  
  // helper to check next files for lines
  private func next_files_have_lines() -> Int32 {
    var file = files
    while let fnode = file?.next {
      file = fnode
      if let file_fd = fopen(fnode.fname ?? "", "r") {
        if let ch = fgetc(file_fd) {
          ungetc(ch, file_fd)
          fclose(file_fd)
          return 1
        }
        fclose(file_fd)
      }
    }
    return 0
  }
  */
  
}
