
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

import CMigration

// for regex options
import Darwin

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

  var options : CommandOptions!

  func parseOptions() async throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "EHI:ae:f:i:lnru"
    let go = BSDGetopt(supportedFlags)

    while let (k, v) = try go.getopt() {
      switch k {
        case "r", "E":
          options.rflags |= UInt32(REG_EXTENDED)
        case "H":
          // for Apple
          // rflags |= REG_ENHANCED, but that is non-standard, so we just define a placeholder:
          options.rflags |= UInt32(REG_ENHANCED)
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
      throw CmdErr(0, "")
    } else {
      // add_file(NULL) => means read from stdin
      options.files = ["/dev/stdin"] // add_file(nil)
    }
    
    return options
  }
  
  func runCommand() async throws(CmdErr) {
    
    var cs : CompileState
    
    // FIXME: this is because somewhere in the bowels, nflag might be set.
//    var options = optionsx
    // compile() the sed commands
    do {
      cs = try await compile(&options)
      // Process
      let p = SedProcess(cs, options)
      try await p.process()
      
    } catch {
      if let e = error as? CompileErr {
        throw CmdErr(1, e.localizedDescription)
      } else if let e = error as? CmdErr {
        throw e
      }
      else {
        throw CmdErr(1, "\(error)")
      }
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
  
  // Swift doesn't have a direct global "program name" like getprogname() in macOS/BSD.
  // We'll define a helper or store a static name, or you might retrieve from CommandLine.arguments[0].
  func getprogname() -> String {
    return "sed"   // or extract from CommandLine.arguments[0]
  }
}


/**
 * Minimal file I/O helpers for the 'w' command usage.
 */
func openFileForWCommand(_ path: String) throws(CompileErr) -> FileDescriptor {
  // O_WRONLY|O_APPEND|O_CREAT|O_TRUNC in the original code => open for writing
  do {
    let fd = try FileDescriptor.open(path, .writeOnly, options: [.create, .append], permissions: [.ownerReadWrite])

    //    let fd = open(path, O_WRONLY | O_APPEND | O_CREAT | O_TRUNC, 0o666)
    //    if fd == -1 {
  return fd
  } catch {
    throw CompileErr("\(path): \(error)")
  }
}
