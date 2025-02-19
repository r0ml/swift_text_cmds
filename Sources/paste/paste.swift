
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1989, 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  Adam S. Moskowitz of Menlo Consulting.
 
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

@main final class paste : ShellCommand {

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
 I’m given a C code to convert to Swift, and there’s a key instruction to not change any variable or function names. It’s clear that the task is about preserving the original code while translating it, so I’ll focus on the syntax and structural differences between C and Swift. I need to be careful with things that might differ, like memory management or type declarations, but I’m definitely supposed to keep the variable and function names untouched.
 None

 In the C code, we see the global variables tab and delim, and we need to preserve those in Swift. I’ll declare tab as a fileprivate var, possibly like fileprivate var tab: [wchar_t] = [9, 0]. For delim, which is a pointer, I’ll declare it as var delim: UnsafeMutablePointer<wchar_t>? = nil. Likewise, delimcnt becomes an Int. In Swift, we’ll still need a main function to match the C main, but with Swift syntax. I’ll also map C functions like getopt and setlocale to their Swift equivalents where needed.

 In the C code, I see variable declarations like ch, rval, seq, and types like wchar_t *warg. I’ll translate these to Swift types such as Int32 for the integers and UnsafeMutablePointer<wchar_t>? for pointers, keeping variable names intact.
 For memory allocations, in Swift, I’ll use UnsafeMutableRawPointer for malloc, or better, define classes like LIST to handle instances. The parallel function uses LIST *lp for file handling, and I’ll convert this into an appropriate Swift class-based solution with a while loop to process argv.
 */


/*
 Explanation
   1.  Global Variables and Types:
 The global variable tab is defined as a pointer to a wide‐character array (L”\t”). Two additional globals, delim and delimcnt, are declared exactly as in C.
   2.  main Function:
 The Swift main function uses the same variable names as in C. It calls setlocale(LC_CTYPE, "") and then processes command–line options via getopt("d:s"). When the -d option is encountered it converts the multibyte string in optarg to wide characters using mbsrtowcs (first to determine length, then to perform the conversion). The result is stored in warg and then assigned to delim (and its count computed via a call to tr).
   3.  File Processing:
 After option processing the code checks for at least one filename. Then, depending on whether the -s flag was set, it calls either sequential or parallel (both accepting the remaining argv array). Finally, on Apple platforms it checks for output errors and then exits with the appropriate return value.
   4.  LIST, parallel, and sequential:
 The C structure _list is translated to the class LIST with identical member names. The functions parallel and sequential traverse the list of file names and process them as in the original C code, printing wide–characters with putwchar and using getwc for input.
   5.  tr and usage:
 The function tr processes a wide–character string by translating escape sequences (e.g. \n, \t, \0) exactly as in C. The usage function prints the usage message and exits.
 */

import Darwin
import Foundation

// Global variables (preserving the names)
fileprivate var tab: UnsafeMutablePointer<wchar_t> = {
    // Create a wide‐character array containing L"\t" (i.e. a tab and a terminating NUL)
    let ptr = UnsafeMutablePointer<wchar_t>.allocate(capacity: 2)
    ptr[0] = 9      // tab character (ASCII 9)
    ptr[1] = 0
    return ptr
}()

// Global variables used by main and other functions.
var delim: UnsafeMutablePointer<wchar_t>? = nil
var delimcnt: Int = 0

// MARK: - Helper Functions and Stubs

// Stub: err() and errx() wrappers.
func err(_ exitCode: Int32, _ message: UnsafePointer<Int8>?) -> Never {
    if let msg = message {
        fputs(String(cString: msg), stderr)
    }
    exit(exitCode)
}

func errx(_ exitCode: Int32, _ message: String, _ args: CVarArg...) -> Never {
    let s = String(format: message, arguments: args)
    fputs(s, stderr)
    exit(exitCode)
}

// Stub: usage() is defined later.

// MARK: - main()

@discardableResult
func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32 {
    var ch: Int32 = 0
    var rval: Int32 = 0
    var seq: Int32 = 0
    var warg: UnsafeMutablePointer<wchar_t>? = nil
    var arg: UnsafePointer<Int8>? = nil
    var len: size_t = 0

    // Set locale for character conversion.
    setlocale(LC_CTYPE, "")

    seq = 0
    // Process options using getopt. (The option string is "d:s")
    while true {
        ch = getopt(argc, argv, "d:s")
        if ch == -1 { break }
        switch ch {
        case Int32(Character("d").asciiValue!):
            // 'd' option: convert optarg (a multibyte string) to wide characters.
            arg = optarg
            // First, get required length.
            len = mbsrtowcs(nil, &arg, 0, nil)
            if len == size_t(bitPattern: -1) {
                err(1, "delimiters")
            }
            warg = UnsafeMutablePointer<wchar_t>.allocate(capacity: Int(len + 1))
            if warg == nil {
                err(1, nil)
            }
            arg = optarg
            len = mbsrtowcs(warg, &arg, len + 1, nil)
            if len == size_t(bitPattern: -1) {
                err(1, "delimiters")
            }
            // Set global delim and delimcnt by calling tr.
            delim = warg
            delimcnt = tr(delim!)
        case Int32(Character("s").asciiValue!):
            seq = 1
        case Int32(Character("?").asciiValue!):
            fallthrough
        default:
            usage()
        }
    }

    // Adjust argc and argv after option processing.
    var newArgc = argc - optind
    var newArgv = argv.advanced(by: Int(optind))

    if newArgc == 0 || newArgv.pointee == nil {
        usage()
    }
    if delim == nil {
        delimcnt = 1
        delim = tab
    }

    if seq != 0 {
        rval = sequential(newArgv)
    } else {
        rval = parallel(newArgv)
    }
    #if os(macOS)
    if ferror(stdout) != 0 || fflush(stdout) != 0 {
        err(2, "stdout")
    }
    #endif
    exit(rval)
}

// MARK: - LIST Type Definition

// Translating: typedef struct _list { ... } LIST;
class LIST {
    var next: LIST? = nil
    var fp: UnsafeMutablePointer<FILE>! = nil
    var cnt: Int = 0
    var name: UnsafeMutablePointer<Int8>? = nil
}

// MARK: - parallel()

func parallel(_ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int {
    var lp: LIST? = nil
    var cnt: Int = 0
    var ich: wint_t = 0
    var ch: wchar_t = 0
    var p: UnsafeMutablePointer<Int8>? = nil
    var head: LIST? = nil
    var tmp: LIST? = nil
    var opencnt: Int = 0
    var output: Int = 0

    cnt = 0
    head = nil
    tmp = nil
    var currentArgv = argv
    // Build linked list of files.
    while let pUnwrapped = currentArgv.pointee {
        p = pUnwrapped
        let newLP = LIST()
        // Allocate new LIST.
        // If p is "-" (a single dash) then use stdin.
        if p[0] == Int8(ascii: "-") && p[1] == 0 {
            newLP.fp = stdin
        } else if let fpTemp = fopen(p, "r") {
            newLP.fp = fpTemp
        } else {
            err(1, p)
        }
        newLP.next = nil
        newLP.cnt = cnt
        newLP.name = p
        if head == nil {
            head = newLP
            tmp = newLP
        } else {
            tmp?.next = newLP
            tmp = newLP
        }
        cnt += 1
        currentArgv = currentArgv.advanced(by: 1)
    }
    opencnt = cnt

    while opencnt != 0 {
        output = 0
        var iter: LIST? = head
        while let currentLP = iter {
            if currentLP.fp == nil {
                if output != 0 && currentLP.cnt != 0,
                   (ch = delim![ (currentLP.cnt - 1) % delimcnt ]) != 0 {
                    putwchar(Int32(ch))
                }
                iter = currentLP.next
                continue
            }
            ich = getwc(currentLP.fp)
            if ich == WEOF {
                opencnt -= 1
                currentLP.fp = nil
                if output != 0 && currentLP.cnt != 0,
                   (ch = delim![ (currentLP.cnt - 1) % delimcnt ]) != 0 {
                    putwchar(Int32(ch))
                }
                iter = currentLP.next
                continue
            }
            if output == 0 {
                output = 1
                for i in 0 ..< currentLP.cnt {
                    ch = delim![ i % delimcnt ]
                    if ch != 0 {
                        putwchar(Int32(ch))
                    }
                }
            } else if (ch = delim![ (currentLP.cnt - 1) % delimcnt ]) != 0 {
                putwchar(Int32(ch))
            }
            if ich == Int32(10) { // newline
                iter = currentLP.next
                continue
            }
            repeat {
                putwchar(ich)
                ich = getwc(currentLP.fp)
            } while ich != WEOF && ich != Int32(10)
            if ferror(currentLP.fp) != 0 {
                errx(EX_IOERR, "Error reading %s", String(cString: currentLP.name!))
            }
            iter = currentLP.next
        }
        if output != 0 {
            putwchar(Int32(10))
        }
    }
    return 0
}

// MARK: - sequential()

func sequential(_ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int {
    var fp: UnsafeMutablePointer<FILE>! = nil
    var cnt: Int = 0
    var failed: Int = 0
    var needdelim: Int = 0
    var ch: wint_t = 0
    var p: UnsafeMutablePointer<Int8>? = nil

    failed = 0
    var currentArgv = argv
    while let pUnwrapped = currentArgv.pointee {
        p = pUnwrapped
        if p[0] == Int8(ascii: "-") && p[1] == 0 {
            fp = stdin
        } else if let fpTemp = fopen(p, "r") {
            fp = fpTemp
        } else {
            // warn() in C prints a warning.
            fputs(String(cString: p), stderr)
            failed = 1
            currentArgv = currentArgv.advanced(by: 1)
            continue
        }
        cnt = 0
        needdelim = 0
        while (ch = getwc(fp)) != WEOF {
            if needdelim != 0 {
                needdelim = 0
                if delim![cnt] != 0 {
                    putwchar(Int32(delim![cnt]))
                }
                cnt += 1
                if cnt == delimcnt {
                    cnt = 0
                }
            }
            if ch != Int32(10) {
                putwchar(ch)
            } else {
                needdelim = 1
            }
        }
        if needdelim != 0 {
            putwchar(Int32(10))
        }
        if fp != stdin {
            fclose(fp)
        }
        currentArgv = currentArgv.advanced(by: 1)
    }
    return (failed != 0) ? 1 : 0
}

// MARK: - tr()

func tr(_ arg: UnsafeMutablePointer<wchar_t>) -> Int {
    var cnt: Int = 0
    var ch: wchar_t = 0
    var p = arg
    var argPtr = arg
    // For each character in arg.
    while true {
        ch = p.pointee
        if ch == 0 { break }
        p = p.successor()
        if ch == UInt32(ascii: "\\") {
            ch = p.pointee
            p = p.successor()
            switch ch {
            case UInt32(ascii: "n"):
                argPtr.pointee = UInt32(ascii: "\n")
            case UInt32(ascii: "t"):
                argPtr.pointee = UInt32(ascii: "\t")
            case UInt32(ascii: "0"):
                argPtr.pointee = 0
            default:
                argPtr.pointee = ch
            }
        } else {
            argPtr.pointee = ch
        }
        argPtr = argPtr.successor()
        cnt += 1
    }
    if cnt == 0 {
        errx(1, "no delimiters specified")
    }
    return cnt
}

// MARK: - usage()

func usage() -> Never {
    _ = fprintf(stderr, "usage: paste [-s] [-d delimiters] file ...\n")
    exit(1)
}

// MARK: - Entry Point

_ = main(CommandLine.argc, CommandLine.unsafeArgv)
