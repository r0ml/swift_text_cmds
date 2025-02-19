
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1987, 1992, 1993
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

@main final class rev : ShellCommand {

  var usage : String = "usage: rev [file ...]"
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "belnstuv"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        case "?": fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    var rval = 0
    for f in options.args {
      do {
      let fh = try FileHandle(forReadingFrom: URL(filePath: f))
        for try await line in fh.bytes.lines {
          print(String(line.reversed()))
        }
        try fh.close()
      } catch {
        warn("read failure on \(f)")
        rval = 1
      }
    }
    exit(Int32(rval) )
  }
}

/*
 Okay, so the user’s asking for a C program to be converted to Swift without changing variable or function names. First, I need to look at the syntax differences between C and Swift. In C, we use things like pointers, while Swift handles memory differently, sometimes through references or optionals. I’ll keep the logic intact but adjust for Swift’s type system and syntax—like replacing printf with print and getting rid of manual memory management. Let’s go step-by-step to ensure it’s accurate!

 Alright, I’ve got the C code, and the user wants it converted to Swift while keeping all variable names intact. First, I’ll look for equivalents in Swift for things like file handling (C’s fopen will become Swift’s FileHandle or String methods). We have wide characters in C (wchar_t); Swift will need to handle this differently using String since Swift doesn’t directly use wide characters.
 The loop processing seems straightforward, but I’ll need to adjust syntax for Swift’s error handling and file reading. Let’s get to converting!

 Okay, the user’s asking to convert C to Swift while preserving variable names, like filename, p, t, etc. We can’t use the standard argc, argv method in Swift, but can use CommandLine.arguments. I’ll set setlocale with Swift’s Darwin or Foundation imports. For getopt, I can try using Darwin.getopt, although it’s empty for this case. For the file reading, I’ll adapt fgetwln with String(contentsOf:), then reverse lines as per the original logic—all while ensuring the variable names stay the same. Let’s go step-by-step!
 */

/*
 Explanation
   •  Variable and Function Names:
 All names (e.g. filename, p, t, fp, len, ch, rval, usage(), and main()) appear exactly as in the C code.
   •  Option Parsing:
 The getopt loop is preserved (with an empty options string).
   •  File Processing:
 The code sets fp to stdin by default, then for each argument attempts to open the file (or continues with stdin if no arguments are present).
   •  Line Reversal:
 The helper function fgetwln mimics the C function by using a fixed buffer and computing the length via wcslen. Each line’s trailing newline (if any) is removed, and the characters are printed in reverse order via putwchar.
   •  Error Handling:
 If an error occurs when reading a file, a warning is printed (using fprintf), and rval is set to 1.
   •  Entry Point:
 The Swift code calls main(CommandLine.argc, CommandLine.unsafeArgv) at the end.
 */


import Darwin
import Foundation


// Helper: Simulate fgetwln() by reading a wide–character line.
// This implementation allocates a fixed–size buffer, reads with fgetws(),
// and returns the buffer (which the caller must free) along with its length.
func fgetwln(_ fp: UnsafeMutablePointer<FILE>!, _ len: inout Int) -> UnsafeMutablePointer<wchar_t>? {
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<wchar_t>.allocate(capacity: bufferSize)
    // fgetws returns nil on error or EOF.
    if fgetws(buffer, Int32(bufferSize), fp) == nil {
        buffer.deallocate()
        return nil
    }
    len = Int(wcslen(buffer))
    return buffer
}

func usage() -> Never {
    _ = fprintf(stderr, "usage: rev [file ...]\n")
    exit(1)
}

func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32 {
    var filename: UnsafePointer<Int8>? // const char *filename
    var p: UnsafeMutablePointer<wchar_t>? // wchar_t *p
    var t: UnsafeMutablePointer<wchar_t>? // wchar_t *t
    var fp: UnsafeMutablePointer<FILE>!  // FILE *fp
    var len: Int = 0
    var ch: Int32 = 0
    var rval: Int32 = 0

    setlocale(LC_ALL, "")

    // Process options (none are defined; getopt returns -1 immediately).
    while (ch = getopt(argc, argv, "")) != -1 {
        switch ch {
        case Int32(UInt8(ascii: "?")):
            usage()
        default:
            usage()
        }
    }

    // Adjust argc and argv to skip options.
    var newArgc = argc - optind
    var newArgv = argv.advanced(by: Int(optind))

    fp = stdin
    filename = ("stdin" as NSString).utf8String
    rval = 0

    repeat {
        if newArgc > 0, let arg = newArgv.pointee {
            // Try to open the file.
            fp = fopen(arg, "r")
            if fp == nil {
                _ = fprintf(stderr, "%s\n", arg)
                rval = 1
                newArgc -= 1
                newArgv = newArgv.advanced(by: 1)
                continue
            }
            filename = arg
            newArgc -= 1
            newArgv = newArgv.advanced(by: 1)
        }
        while { p = fgetwln(fp, &len); return p != nil }() {
            if len > 0, p![len - 1] == UInt32(10) { // '\n' in wchar_t
                len -= 1
            }
            // Reverse the line: for (t = p + len - 1; t >= p; --t)
            var tIndex = len - 1
            while tIndex >= 0 {
                t = p! + tIndex
                putwchar(Int32(t.pointee))
                tIndex -= 1
            }
            putwchar(Int32(10))
            free(p)
        }
        if ferror(fp) != 0 {
            if let fn = filename {
                _ = fprintf(stderr, "%s\n", fn)
            }
            clearerr(fp)
            rval = 1
        }
        fclose(fp)
    } while (newArgv.pointee != nil)
    exit(rval)
}

_ = main(CommandLine.argc, CommandLine.unsafeArgv)
