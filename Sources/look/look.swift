
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1991, 1993
   The Regents of the University of California.  All rights reserved.
 
  This code is derived from software contributed to Berkeley by
  David Hitz of Auspex Systems, Inc.
 
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

@main final class look : ShellCommand {

  var usage : String = "Not yet implemented"
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }

  var options: CommandOptions!
  
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
}

/*
 Alright, the task is clear: I need to convert the provided C code to Swift while keeping all variable and function names identical, like “static char _path_words[] = _PATH_WORDS;” and so on. My main job is translating the structure of the code without changing any of the identifiers. I’ll focus on converting each part of the C code piece by piece, ensuring the names and overall logic are preserved. It’s just a matter of translating syntax, and I need to keep an eye on swift syntax!

 To convert this C code to Swift, I first need to preserve all the variable and function names exactly as they appear. For instance, _path_words[] = _PATH_WORDS in C will have to retain the same naming and structure in Swift. There are also key functions like binary_search, look, and prepkey in C that I’ll need to rewrite in Swift while maintaining functionality. I’ll focus on translating C syntax and structures into Swift equivalents, step by step.

 Alright, I’m looking at how to convert these search functions to Swift. For binary_search, I’ll need to translate the logic and make sure the syntax matches Swift, but keeping the function behavior intact. I’ll need similar approaches for linear_search and print_from too. The core idea is all about comparing strings, searching through memory, and printing matches. I’ll be careful to reflect the correct return types and preserve the structure while adapting it to Swift conventions, especially for loops and string handling.
 None
 */

/*
 Explanation
   1.  Global Definitions:
 The variable _path_words is defined (with a stub value) exactly as in C. The macros for EQUAL, GREATER, and LESS are defined as constants.
   2.  Function Prototypes and Names:
 All functions—binary_search, compare, linear_search, look, prepkey, print_from, and usage—are declared and defined with the same names and parameter types (using unsafe pointers to represent C pointers).
   3.  Option Processing:
 The longopts array is defined using Darwin’s option structure. The getopt_long loop in main processes the options just as in C.
   4.  Main Function:
 The main function closely follows the original C logic: setting the locale, processing command–line options, adjusting argc/argv, calling prepkey, then opening files, mmapping the file contents, and repeatedly calling look.
   5.  Helper Functions:
 Functions such as prepkey, look, binary_search, linear_search, print_from, and compare are translated in a nearly line–for–line style using pointer arithmetic (via advanced(by:) and successor()) and C library functions (like mbrtowc, wcschr, and putchar).

 */

import Darwin
import Foundation

// -----------------------------------------------------------------------------
// Global definitions and macros
// -----------------------------------------------------------------------------

// In C: static char _path_words[] = _PATH_WORDS;
// For our purposes, assume _PATH_WORDS is defined elsewhere; here we supply a stub.
let _PATH_WORDS = "/usr/share/dict/words"
var _path_words: [CChar] = Array(_PATH_WORDS.utf8CString)

// Macros:
let EQUAL: Int32 = 0
let GREATER: Int32 = 1
let LESS: Int32 = -1

// Global flags:
var dflag: Int32 = 0
var fflag: Int32 = 0

// -----------------------------------------------------------------------------
// Function prototypes (with identical names)
// -----------------------------------------------------------------------------

// Note: All functions below are declared with the same names and parameter types as in C.
// The C types are represented via UnsafeMutablePointer and related types.

func binary_search(_ string: UnsafeMutablePointer<wchar_t>,
                   _ front: UnsafeMutablePointer<UInt8>,
                   _ back: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<CChar>?
                   
func compare(_ s1: UnsafeMutablePointer<wchar_t>,
             _ s2: UnsafeMutablePointer<UInt8>,
             _ back: UnsafeMutablePointer<UInt8>) -> Int32
             
func linear_search(_ string: UnsafeMutablePointer<wchar_t>,
                   _ front: UnsafeMutablePointer<UInt8>,
                   _ back: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<CChar>?
                   
func look(_ string: UnsafeMutablePointer<wchar_t>,
          _ front: UnsafeMutablePointer<UInt8>,
          _ back: UnsafeMutablePointer<UInt8>) -> Int32
          
func prepkey(_ string: UnsafePointer<CChar>, _ termchar: wchar_t) -> UnsafeMutablePointer<wchar_t>

func print_from(_ string: UnsafeMutablePointer<wchar_t>,
                _ front: UnsafeMutablePointer<UInt8>,
                _ back: UnsafeMutablePointer<UInt8>) -> Void

func usage() -> Never

// -----------------------------------------------------------------------------
// Option definitions
// -----------------------------------------------------------------------------

// Define longopts array exactly as in C.
var longopts: [option] = [
    option(name: "alternative", has_arg: no_argument, flag: nil, val: Int32(Character("a").asciiValue!)),
    option(name: "alphanum",    has_arg: no_argument, flag: nil, val: Int32(Character("d").asciiValue!)),
    option(name: "ignore-case", has_arg: no_argument, flag: nil, val: Int32(Character("i").asciiValue!)),
    option(name: "terminate",   has_arg: required_argument, flag: nil, val: Int32(Character("t").asciiValue!)),
    option(name: nil,           has_arg: 0,           flag: nil, val: 0)
]

// -----------------------------------------------------------------------------
// main()
// -----------------------------------------------------------------------------

@discardableResult
func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    var sb = stat()
    var ch: Int32 = 0, fd: Int32 = 0, match: Int32 = 0
    var termchar: wchar_t = 0
    var back: UnsafeMutablePointer<UInt8>! = nil
    var front: UnsafeMutablePointer<UInt8>! = nil
    var file: UnsafePointer<UInt8>! = nil
    var key: UnsafeMutablePointer<wchar_t>! = nil

    setlocale(LC_CTYPE, "")

    file = _path_words.withUnsafeBufferPointer { $0.baseAddress! }
    termchar = 0
    while { ch = getopt_long(argc, argv, "+adft:", &longopts, nil); return ch != -1 }() {
        switch ch {
        case Int32(Character("a").asciiValue!):
            // COMPATIBILITY – do nothing.
            break
        case Int32(Character("d").asciiValue!):
            dflag = 1
        case Int32(Character("f").asciiValue!):
            fflag = 1
        case Int32(Character("t").asciiValue!):
            if mbrtowc(&termchar, optarg, MB_LEN_MAX, nil) != strlen(optarg) {
                errx(2, "invalid termination character")
            }
        case Int32(Character("?").asciiValue!), default:
            usage()
        }
    }
    var newArgc = argc - optind
    var newArgv = argv.advanced(by: Int(optind))
    #if os(macOS)
    if newArgc <= 0 { usage() }
    #else
    if newArgc == 0 { usage() }
    #endif
    if newArgc == 1 { // But set -df by default.
        dflag = 1
        fflag = 1
    }
    key = prepkey(newArgv.pointee!, termchar)
    newArgc -= 1
    newArgv = newArgv.advanced(by: 1)
    if newArgc >= 1 {
        file = UnsafePointer(newArgv.pointee!)
        newArgc -= 1
        newArgv = newArgv.advanced(by: 1)
    }
    match = 1
    repeat {
        fd = open(UnsafePointer(mutating: file), O_RDONLY, 0)
        if fd < 0 || fstat(fd, &sb) != 0 {
            err(2, file)
        }
        if UIntmax(sb.st_size) > UIntmax(SIZE_T_MAX) {
            errx(2, "%s: %s", file, strerror(EFBIG))
        }
        if sb.st_size == 0 {
            close(fd)
            continue
        }
        front = mmap(nil, size_t(sb.st_size), PROT_READ, MAP_SHARED, fd, 0) as! UnsafeMutablePointer<UInt8>
        if front == MAP_FAILED {
            err(2, file)
        }
        back = front.advanced(by: Int(sb.st_size))
        match *= look(key, front, back)
        close(fd)
    } while (newArgc > 0 && { file = UnsafePointer(newArgv.pointee!); newArgc -= 1; newArgv = newArgv.advanced(by: 1); return true }())
    exit(match)
}

// -----------------------------------------------------------------------------
// prepkey()
// -----------------------------------------------------------------------------

func prepkey(_ string: UnsafePointer<CChar>, _ termchar: wchar_t) -> UnsafeMutablePointer<wchar_t> {
    let slen = strlen(string)
    let key = malloc(MemoryLayout<wchar_t>.size * (slen + 1))!.assumingMemoryBound(to: wchar_t.self)
    var readp = string
    var writep = key
    var ch: wchar_t = 0
    var clen: size_t = 0
    while true {
        clen = mbrtowc(&ch, readp, MB_LEN_MAX, nil)
        if clen == 0 { break }
        if clen == size_t(bitPattern: -1) || clen == size_t(bitPattern: -2) {
            errc(2, EILSEQ, nil)
        }
        if fflag != 0 {
            ch = towlower(ch)
        }
        if dflag == 0 || iswalnum(ch) != 0 {
            writep.pointee = ch
            writep = writep.successor()
        }
        readp = readp.advanced(by: Int(clen))
    }
    writep.pointee = 0
    if termchar != 0, let pos = wcschr(key, termchar) {
        pos.successor().pointee = 0
    }
    return key
}

// -----------------------------------------------------------------------------
// look()
// -----------------------------------------------------------------------------

func look(_ string: UnsafeMutablePointer<wchar_t>,
          _ front: UnsafeMutablePointer<UInt8>,
          _ back: UnsafeMutablePointer<UInt8>) -> Int32 {
    let bs = binary_search(string, front, back)
    let ls = linear_search(string, UnsafeMutablePointer(mutating: bs!), back)
    if ls != nil {
        print_from(string, UnsafeMutablePointer(mutating: ls!), back)
    }
    return (ls != nil) ? 0 : 1
}

// -----------------------------------------------------------------------------
// binary_search()
// -----------------------------------------------------------------------------

func binary_search(_ string: UnsafeMutablePointer<wchar_t>,
                   _ front: UnsafeMutablePointer<UInt8>,
                   _ back: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<CChar>? {
    var p = front.advanced(by: (back - front) / 2)
    // SKIP_PAST_NEWLINE: increment p until (p < back && *p != '\n'), then p++
    while p < back && p.pointee != UInt8(ascii: "\n") {
        p = p.successor()
    }
    while p < back && back > front {
        if compare(string, p, back) == GREATER {
            front = p
        } else {
            back = p
        }
        p = front.advanced(by: (back - front) / 2)
        while p < back && p.pointee != UInt8(ascii: "\n") {
            p = p.successor()
        }
    }
    // Return front as a CChar pointer.
    return front.withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
}

// -----------------------------------------------------------------------------
// linear_search()
// -----------------------------------------------------------------------------

func linear_search(_ string: UnsafeMutablePointer<wchar_t>,
                   _ front: UnsafeMutablePointer<UInt8>,
                   _ back: UnsafeMutablePointer<UInt8>) -> UnsafeMutablePointer<CChar>? {
    var f = front
    while f < back {
        switch compare(string, f, back) {
        case EQUAL:
            return f.withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
        case LESS:
            return nil
        case GREATER:
            break
        default:
            break
        }
        while f < back && f.pointee != UInt8(ascii: "\n") {
            f = f.successor()
        }
    }
    return nil
}

// -----------------------------------------------------------------------------
// print_from()
// -----------------------------------------------------------------------------

func print_from(_ string: UnsafeMutablePointer<wchar_t>,
                _ front: UnsafeMutablePointer<UInt8>,
                _ back: UnsafeMutablePointer<UInt8>) {
    var f = front
    while f < back && compare(string, f, back) == EQUAL {
        while f < back && f.pointee != UInt8(ascii: "\n") {
            if putchar(Int32(f.pointee)) == EOF {
                err(2, "stdout")
            }
            f = f.successor()
        }
        if putchar(Int32(10)) == EOF {
            err(2, "stdout")
        }
    }
}

// -----------------------------------------------------------------------------
// compare()
// -----------------------------------------------------------------------------

func compare(_ s1: UnsafeMutablePointer<wchar_t>,
             _ s2: UnsafeMutablePointer<UInt8>,
             _ back: UnsafeMutablePointer<UInt8>) -> Int32 {
    var s1Ptr = s1
    var s2Ptr = s2
    var ch1: wchar_t = 0, ch2: wchar_t = 0
    var len2: size_t = 0
    while s1Ptr.pointee != 0 && s2Ptr < back && s2Ptr.pointee != UInt8(ascii: "\n") {
        ch1 = s1Ptr.pointee
        len2 = mbrtowc(&ch2, s2Ptr, back - s2Ptr, nil)
        if len2 == size_t(bitPattern: -1) || len2 == size_t(bitPattern: -2) {
            ch2 = wchar_t(s2Ptr.pointee)
            len2 = 1
        }
        if fflag != 0 {
            ch2 = towlower(ch2)
        }
        if dflag != 0 && iswalnum(ch2) == 0 {
            s1Ptr = s1Ptr.advanced(by: -1)
            continue
        }
        if ch1 != ch2 {
            return (ch1 < ch2) ? LESS : GREATER
        }
        s1Ptr = s1Ptr.successor()
        s2Ptr = s2Ptr.advanced(by: Int(len2))
    }
    return (s1Ptr.pointee != 0) ? GREATER : EQUAL
}

// -----------------------------------------------------------------------------
// usage()
// -----------------------------------------------------------------------------

func usage() -> Never {
    fprintf(stderr, "usage: look [-df] [-t char] string [file ...]\n")
    exit(2)
}

// -----------------------------------------------------------------------------
// Entry Point
// -----------------------------------------------------------------------------

_ = main(CommandLine.argc, CommandLine.unsafeArgv)
