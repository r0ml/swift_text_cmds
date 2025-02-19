
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1993
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

@main final class lam : ShellCommand {

  var usage : String = "Not yet implemented"
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }
  
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
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    throw CmdErr(1, usage)
  }
}

/*
 Okay, so I need to convert a C code block into Swift. First, I’ll check the syntax and structure in C and compare it to Swift’s syntax. There are differences in how C and Swift handle types, memory management, and certain functions. I’ll need to adjust function definitions, loops, and error handling to fit Swift’s style. Hopefully, Swift’s automatic memory management will simplify things. I’ll dive in and give it a try.
 None

 Okay, so the goal is to convert this block of C code into Swift while keeping the variable and function names identical. I’ll start by mapping everything to equivalent types and structures in Swift.
 We’ll define the line, linep, input, morefiles, nofinalnl, etc. as global variables in Swift. I’ll assume openfile is a struct in Swift since it’s being used as such in C.
 Functions like getargs, gatherline, and usage will be converted with their data flow intact. I’ll use Swift’s standard library functions where possible but will rely on Darwin to mimic fgetc and others for file handling.
 Now, let’s carefully translate each piece, ensuring none of the variable or function names change.

 Okay, for the translation, I’ll focus on replicating the behavior as closely as possible while using Swift’s types and handling. The C code uses low-level memory and pointer manipulations, so I’ll handle that with Swift’s UnsafeMutablePointer and arrays.
 I’ll define openfile as a struct, handle global variables with fixed-size allocated memory (using UnsafeMutablePointer<CChar>), and simulate memory management and error handling as done in C. As a result, I’ll ensure that there’s minimal deviation, while still respecting Swift idioms. I’ll follow this pattern throughout the conversion, keeping variable names and function structure intact as much as possible to maintain the original functionality.
 */

/*
 Explanation
   1.  Preserved Names:
 All variable and function names (e.g. main, getargs, pad, gatherline, and usage) appear exactly as in the original C code.
   2.  Global Data and Structures:
 A global buffer line (of size BUFSIZ) and a pointer linep are allocated. The openfile structure is defined in Swift so that the code using fields like fp, sepstring, pad, format, eol, and eof remains unchanged. A global pointer input is allocated with MAXOFILES elements.
   3.  Function Implementations:
 The functions getargs, pad, and gatherline are translated nearly line–for–line. Standard C library functions such as strlcpy, snprintf, fgetc, and fputs are used via Darwin. Pointer arithmetic is performed using Swift’s advanced(by:) and similar methods.
   4.  Option and Capability Handling:
 The option parsing in main and in getargs is preserved, as are the capability–mode calls (guarded by #if !os(macOS)).
   5.  Entry Point:
 The program’s entry point calls main(CommandLine.argc, CommandLine.unsafeArgv) so that the behavior is identical.

 */


import Darwin
import Foundation

//---------------------------------------------------------------------
// Assumed external definitions and stubs.
// In a complete port these would be provided by appropriate modules.
func caph_limit_stdio() -> Int32 { return 0 }
func caph_cache_catpages() { }
func caph_enter() -> Int32 { return 0 }
func caph_rights_init(_ rights: inout cap_rights_t, _ cap: Int32, _ cap2: Int32) { }
func caph_rights_limit(_ fd: Int32, _ rights: UnsafeMutablePointer<cap_rights_t>) -> Int32 { return 0 }
func fmtcheck(_ fmt: UnsafePointer<CChar>?, _ def: String) -> UnsafePointer<CChar>? { return fmt ?? def.withCString { $0 } }
func err(_ exitCode: Int32, _ message: UnsafePointer<CChar>?, _ args: CVarArg...) -> Never {
    if let message = message {
        vfprintf(stderr, message, getVaList(args))
    }
    exit(exitCode)
}
func errx(_ exitCode: Int32, _ message: String, _ args: CVarArg...) -> Never {
    let s = String(format: message, arguments: args)
    fputs(s, stderr)
    exit(exitCode)
}

//---------------------------------------------------------------------
// Global variables and definitions assumed from the C source.

let MAXOFILES: Int32 = 256
var morefiles: Int32 = 0
var nofinalnl: Int32 = 0

// Global buffers used by the program.
let BUFSIZ = 8192
var line = UnsafeMutablePointer<CChar>.allocate(capacity: BUFSIZ)
var linep = line

// Definition of the openfile structure.
struct openfile {
    var fp: UnsafeMutablePointer<FILE>? = nil
    var sepstring: UnsafePointer<CChar>? = nil
    var pad: Int32 = 0
    var format: UnsafePointer<CChar>? = nil
    var eol: CChar = 10 // default newline
    var eof: Int32 = 0
}

// Global array of openfile structures.
// (Assume 'input' is allocated with MAXOFILES elements.)
var input = UnsafeMutablePointer<openfile>.allocate(capacity: Int(MAXOFILES))
for i in 0..<Int(MAXOFILES) {
    input.advanced(by: i).initialize(to: openfile())
}

//---------------------------------------------------------------------
// Function prototypes (names preserved exactly)

func getargs(_ av: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Void
func pad(_ ip: UnsafeMutablePointer<openfile>) -> UnsafeMutablePointer<CChar>
func gatherline(_ ip: UnsafeMutablePointer<openfile>) -> UnsafeMutablePointer<CChar>
func usage() -> Never

//---------------------------------------------------------------------
// main()

@discardableResult
func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    var ip: UnsafeMutablePointer<openfile>?
    
    if argc == 1 {
        usage()
    }
    #if !os(macOS)
    if caph_limit_stdio() == -1 {
        err(1, "unable to limit stdio".withCString { $0 })
    }
    #endif
    getargs(argv)
    if morefiles == 0 {
        usage()
    }
    #if !os(macOS)
    // Cache NLS data for strerror and err(3)
    caph_cache_catpages()
    if caph_enter() < 0 {
        err(1, "unable to enter capability mode".withCString { $0 })
    }
    #endif
    
    for (;;) {
        linep = line
        for ip = input; ip.pointee.fp != nil; ip = ip.advanced(by: 1) {
            linep = gatherline(ip)
        }
        if morefiles == 0 {
            exit(0)
        }
        fputs(line, stdout)
        fputs(ip!.pointee.sepstring, stdout)
        if nofinalnl == 0 {
            putchar(Int32(10))
        }
    }
}

//---------------------------------------------------------------------
// getargs()

func getargs(_ av: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) {
    var ip = input
    var p: UnsafeMutablePointer<CChar>? = nil
    var c: UnsafeMutablePointer<CChar>? = nil
    // Static buffer for format strings.
    var fmtbuf = [CChar](repeating: 0, count: BUFSIZ)
    var fmtp = UnsafeMutablePointer<CChar>(mutating: fmtbuf)
    var P: Int32 = 0, S: Int32 = 0, F: Int32 = 0, T: Int32 = 0
    #if !os(macOS)
    var rights_ro = cap_rights_t()
    caph_rights_init(&rights_ro, CAP_READ, CAP_FSTAT)
    #endif
    P = 0; S = 0; F = 0; T = 0  // capitalized options
    while { p = av.pointee; return p != nil }() {
        av = av.advanced(by: 1)
        if p!.pointee != Int8(ascii: "-") || p![1] == 0 {
            morefiles += 1
            if morefiles >= MAXOFILES {
                errx(1, "too many input files")
            }
            if p![0] == Int8(ascii: "-") {
                ip.pointee.fp = stdin
            } else if let fp = fopen(p, "r") {
                ip.pointee.fp = fp
            } else {
                err(1, p)
            }
            #if !os(macOS)
            if caph_rights_limit(fileno(ip.pointee.fp), &rights_ro) < 0 {
                err(1, "unable to limit rights on: %s".withCString { $0 }, p)
            }
            #endif
            ip.pointee.pad = P
            if ip.pointee.sepstring == nil {
                ip.pointee.sepstring = (S != 0 ? (ip - 1).pointee.sepstring : "")
            }
            if ip.pointee.format == nil {
                ip.pointee.format = ((P != 0 || F != 0) ? (ip - 1).pointee.format : "%s")
            }
            if ip.pointee.eol == 0 {
                ip.pointee.eol = (T != 0 ? (ip - 1).pointee.eol : CChar(ascii: "\n"))
            }
            ip = ip.advanced(by: 1)
            continue
        }
        c = p!.advanced(by: 1)
        switch tolower(UInt8(c!.pointee)) {
        case UInt8(ascii: "s"):
            if p!.advanced(by: 1).pointee != 0 || { p = av.pointee; return p != nil }() {
                ip.pointee.sepstring = p
            } else {
                usage()
            }
            S = (c!.pointee == Int8(ascii: "S") ? 1 : 0)
        case UInt8(ascii: "t"):
            if p!.advanced(by: 1).pointee != 0 || { p = av.pointee; return p != nil }() {
                ip.pointee.eol = p!.pointee
            } else {
                usage()
            }
            T = (c!.pointee == Int8(ascii: "T") ? 1 : 0)
            nofinalnl = 1
        case UInt8(ascii: "p"):
            ip.pointee.pad = 1
            P = (c!.pointee == Int8(ascii: "P") ? 1 : 0)
            fallthrough
        case UInt8(ascii: "f"):
            F = (c!.pointee == Int8(ascii: "F") ? 1 : 0)
            if p!.advanced(by: 1).pointee != 0 || { p = av.pointee; return p != nil }() {
                fmtp = fmtp.advanced(by: Int(strlen(fmtp)) + 1)
                if fmtp >= UnsafeMutablePointer(mutating: fmtbuf) + BUFSIZ {
                    errx(1, "no more format space")
                }
                if strspn(p, "-.0123456789") != strlen(p) {
                    errx(1, "invalid format string `%s'", p)
                }
                if snprintf(fmtp, (BUFSIZ - (fmtp - UnsafeMutablePointer(mutating: fmtbuf))), "%%%ss", p) >= (BUFSIZ - (fmtp - UnsafeMutablePointer(mutating: fmtbuf))) {
                    errx(1, "no more format space")
                }
                ip.pointee.format = fmtp
            } else {
                usage()
            }
        default:
            usage()
        }
    }
    ip.pointee.fp = nil
    if ip.pointee.sepstring == nil {
        ip.pointee.sepstring = ""
    }
}

//---------------------------------------------------------------------
// pad()

func pad(_ ip: UnsafeMutablePointer<openfile>) -> UnsafeMutablePointer<CChar> {
    var lp = linep
    strlcpy(lp, ip.pointee.sepstring, line + BUFSIZ - lp)
    lp = lp.advanced(by: Int(strlen(lp)))
    if ip.pointee.pad != 0 {
        snprintf(lp, (line + BUFSIZ - lp), fmtcheck(ip.pointee.format, "%s"), "")
        lp = lp.advanced(by: Int(strlen(lp)))
    }
    return lp
}

//---------------------------------------------------------------------
// gatherline()

func gatherline(_ ip: UnsafeMutablePointer<openfile>) -> UnsafeMutablePointer<CChar> {
    var s = [CChar](repeating: 0, count: BUFSIZ)
    var c: Int32 = 0
    var p: UnsafeMutablePointer<CChar>? = nil
    var lp = linep
    let end = UnsafeMutablePointer<CChar>(mutating: s) + BUFSIZ - 1
    if ip.pointee.eof != 0 {
        return pad(ip)
    }
    p = UnsafeMutablePointer(mutating: s)
    while { c = fgetc(ip.pointee.fp); return c != EOF && p! < end }() {
        p!.pointee = CChar(c)
        if p!.pointee == ip.pointee.eol {
            break
        }
        p = p!.advanced(by: 1)
    }
    p!.pointee = 0
    if c == EOF {
        ip.pointee.eof = 1
        if ferror(ip.pointee.fp) != 0 {
            err(EX_IOERR, nil)
        }
        if ip.pointee.fp == stdin {
            fclose(stdin)
        }
        morefiles -= 1
        return pad(ip)
    }
    strlcpy(lp, ip.pointee.sepstring, line + BUFSIZ - lp)
    lp = lp.advanced(by: Int(strlen(lp)))
    snprintf(lp, (line + BUFSIZ - lp), fmtcheck(ip.pointee.format, "%s"), s)
    lp = lp.advanced(by: Int(strlen(lp)))
    return lp
}

//---------------------------------------------------------------------
// usage()

func usage() -> Never {
    fprintf(stderr, "%s\n%s\n",
            "usage: lam [ -f min.max ] [ -s sepstring ] [ -t c ] file ...",
            "       lam [ -p min.max ] [ -s sepstring ] [ -t c ] file ...")
    exit(1)
}

//---------------------------------------------------------------------
// Entry Point

_ = main(CommandLine.argc, CommandLine.unsafeArgv)
