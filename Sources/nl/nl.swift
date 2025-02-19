
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
 * SPDX-License-Identifier: BSD-2-Clause-NetBSD
 
  Copyright (c) 1999 The NetBSD Foundation, Inc.
  All rights reserved.
 
  This code is derived from software contributed to The NetBSD Foundation
  by Klaus Klein.
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
  ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
 */


import Foundation
import CMigration

@main final class nl : ShellCommand {

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
 Okay, we’re tasked with converting this C code to Swift without changing any variable or function names. The code is pretty massive and includes typedefs, structures, enums like numbering_type, and struct numbering_property. There are also #define macros like NP_LAST, along with functions such as filter, parse_numbering, and usage. Additionally, there are global variables like intbuffer, delim, and delimlen. Re-reading everything carefully will help me keep the translation as close to the original as possible.

 For this task, we need to produce Swift code that preserves variable and function names. So, we’ll aim to use Swift constructs and libraries, like Darwin for low-level C calls and Foundation when needed.
 We need to define an enum numbering_type in Swift based on the original C code. Similarly, we’ll define the struct numbering_property, keeping the field names intact. The regex_t from C will need to be handled by importing Darwin.
 For constants like FORMAT_LN, FOOTER, and others, we’ll define them as Swift constants (let). The array numbering_properties should be translated into an array of numbering_property structs in Swift.

 We have the max macro in C, and while Swift already has a built-in max function, we can keep the original name for compatibility. So, we can use Swift’s built-in max function rather than rethinking it.
 For constants like INT_STRLEN_MAXIMUM, we can manually calculate the equivalent in Swift. Because we don’t have sizeof(int) in Swift, we can approximate using MemoryLayout<Int32>.size.
 Then, we’ll define global variables conditionally (like intbuffer for non-Apple platforms using #if conditions).
 Finally, we set up other variables such as delim, format, etc., with their original names but in Swift syntax.

 The main function involves parsing options with getopt, where several options influence global variables and control logic. We’ll transition this to Swift using Darwin for necessary C calls (like getopt, mbrlen, freopen). For input handling, we recreate the behaviors using Swift’s memory management facilities while retaining variable names exactly as in the original C code. Functions like filter, parse_numbering, and usage will be mirrored in Swift, ensuring the same functionality. I’ll need stubs for functions like regcomp and will use fatalError for certain errors to preserve the error handling style. The key is preserving structure and variable names as much as possible while leveraging Swift’s capabilities. Let’s build this translation!

 For this translation, we’re defining Swift versions of C constructs. Starting with numbering_type as an enum, we create the numbering_property struct, using regex_t from Darwin. Then constants like FORMAT_LN, FOOTER, BODY are defined, keeping their original C names. The global array numbering_properties is populated with numbering_property structs using Swift’s memory management functions.
 For function declarations (filter, parse_numbering, etc.), we ensure they follow Swift syntax and keep the names precise.
 In the main function, we convert the logic while maintaining the original behavior, using Darwin for certain functions necessary for compatibility (e.g., getopt, mbrlen). We process options using Swift’s C libraries and manage memory allocations conditionally based on the platform. The structure is very much aligned with the original C, just adapted for Swift.
 */

/*
 Explanation
   1.  Enum, Structure, and Global Constants:
 The numbering_type enum and numbering_property structure are defined exactly as in the original C code. The constants for line numbering formats (FORMAT_LN, FORMAT_RN, FORMAT_RZ) and section identifiers (FOOTER, BODY, HEADER, NP_LAST) are declared with the same names and values.
   2.  Global Variables:
 Global variables such as numbering_properties, intbuffer (when not on APPLE), delim, delimlen, format, incr, nblank, restart, sep, startnum, and width are declared exactly as in the C source.
   3.  main Function:
 The main function uses getopt to process command-line options exactly as in the original. It parses options for -p, -b, -d, -f, -h, -i, -l, -n, -s, -v, and -w without renaming any variables. File handling (using freopen) and delimiter generation (using memcpy) are translated directly.
   4.  filter, parse_numbering, usage:
 The functions filter, parse_numbering, and usage are translated as directly as possible. For example, filter() reads lines using getline, checks for delimiter lines, and prints numbered lines using printf/fputs/fwrite. The function parse_numbering sets the numbering type (or compiles a regular expression) exactly as in the C code.
   5.  Entry Point:
 The entry point calls main(CommandLine.argc, CommandLine.unsafeArgv) so that the program starts just as in the C version.

 */


import Darwin
import Foundation

//======================================================================
// MARK: - Enum, Structures, and Macros
//======================================================================

enum numbering_type: Int {
    case number_all         // number all lines
    case number_nonempty    // number non-empty lines
    case number_none        // no line numbering
    case number_regex       // number lines matching regular expression
}

struct numbering_property {
    let name: UnsafePointer<CChar>   // const char * const name
    var type: numbering_type         // numbering type
    var expr: regex_t                // for type == number_regex
}

// Line numbering formats
let FORMAT_LN = "%-*d"   // left justified, leading zeros suppressed
let FORMAT_RN = "%*d"    // right justified, leading zeros suppressed
let FORMAT_RZ = "%0*d"   // right justified, leading zeros kept

// Section constants
let FOOTER = 0
let BODY   = 1
let HEADER = 2
let NP_LAST = HEADER

// Global numbering properties array (initialized exactly as in C)
var numbering_properties: [numbering_property] = [
    numbering_property(name: ("footer" as NSString).utf8String!, type: .number_none, expr: regex_t()),
    numbering_property(name: ("body"   as NSString).utf8String!, type: .number_nonempty, expr: regex_t()),
    numbering_property(name: ("header" as NSString).utf8String!, type: .number_none, expr: regex_t())
]

// Macro: max(a, b)
func max<T: Comparable>(_ a: T, _ b: T) -> T {
    return a > b ? a : b
}

// Maximum number of characters required for a decimal representation of an int.
// ((sizeof (int) * CHAR_BIT - 1) * 302 / 1000 + 2)
let INT_STRLEN_MAXIMUM = ((MemoryLayout<Int32>.size * Int(CHAR_BIT) - 1) * 302 / 1000 + 2)

//======================================================================
// MARK: - Function Prototypes
//======================================================================

func filter(void) -> Void
func parse_numbering(_ argstr: UnsafePointer<CChar>!, _ section: Int) -> Void
func usage(void) -> Never

#if !os(macOS)
var intbuffer: UnsafeMutablePointer<CChar>? = nil
#endif

// Delimiter characters that indicate the start of a logical page section
var delim = [CChar](repeating: 0, count: 2 * Int(MB_LEN_MAX))
var delimlen: size_t = 0

// Configurable parameters
var format: UnsafePointer<CChar>? = FORMAT_RN.withCString { $0 }
var incr: Int32 = 1
var nblank: UInt32 = 1
var restart: Int32 = 1
var sep: UnsafePointer<CChar>? = "\t".withCString { $0 }
var startnum: Int32 = 1
var width: Int32 = 6

//======================================================================
// MARK: - main()
//======================================================================

@discardableResult
func main(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    var c: Int32 = 0
    var val: Int64 = 0
    var uval: UInt64 = 0
    var ep: UnsafeMutablePointer<CChar>? = nil
    #if !os(macOS)
    var intbuffersize: size_t = 0, clen: size_t = 0
    #else
    var clen: size_t = 0
    #endif
    var delim1 = [CChar](repeating: 0, count: Int(MB_LEN_MAX))
    var delim2 = [CChar](repeating: 0, count: Int(MB_LEN_MAX))
    var delim1len: size_t = 1, delim2len: size_t = 1

    setlocale(LC_ALL, "")

    while { c = getopt(argc, argv, "pb:d:f:h:i:l:n:s:v:w:"); return c != -1 }() {
        switch c {
        case Int32(Character("p").asciiValue!):
            restart = 0
        case Int32(Character("b").asciiValue!):
            parse_numbering(optarg, BODY)
        case Int32(Character("d").asciiValue!):
            clen = mbrlen(optarg, MB_CUR_MAX, nil)
            if clen == size_t(bitPattern: -1) || clen == size_t(bitPattern: -2) {
                errc(EXIT_FAILURE, EILSEQ, nil)
            }
            if clen != 0 {
                memcpy(&delim1, optarg, clen)
                delim1len = clen
                clen = mbrlen(optarg + Int(delim1len), MB_CUR_MAX, nil)
                if clen == size_t(bitPattern: -1) || clen == size_t(bitPattern: -2) {
                    errc(EXIT_FAILURE, EILSEQ, nil)
                }
                if clen != 0 {
                    memcpy(&delim2, optarg + Int(delim1len), clen)
                    delim2len = clen
                    if optarg[Int(delim1len + clen)] != 0 {
                        errx(EXIT_FAILURE, "invalid delim argument -- %s", optarg)
                    }
                }
            }
        case Int32(Character("f").asciiValue!):
            parse_numbering(optarg, FOOTER)
        case Int32(Character("h").asciiValue!):
            parse_numbering(optarg, HEADER)
        case Int32(Character("i").asciiValue!):
            errno = 0
            val = strtol(optarg, &ep, 10)
            if (ep != nil && ep!.pointee != 0) ||
               ((val == LONG_MIN || val == LONG_MAX) && errno != 0) {
                errx(EXIT_FAILURE, "invalid incr argument -- %s", optarg)
            }
            incr = Int32(val)
        case Int32(Character("l").asciiValue!):
            errno = 0
            uval = strtoul(optarg, &ep, 10)
            if (ep != nil && ep!.pointee != 0) ||
               (uval == ULONG_MAX && errno != 0) {
                errx(EXIT_FAILURE, "invalid num argument -- %s", optarg)
            }
            nblank = UInt32(uval)
        case Int32(Character("n").asciiValue!):
            if strcmp(optarg, "ln") == 0 {
                format = FORMAT_LN.withCString { $0 }
            } else if strcmp(optarg, "rn") == 0 {
                format = FORMAT_RN.withCString { $0 }
            } else if strcmp(optarg, "rz") == 0 {
                format = FORMAT_RZ.withCString { $0 }
            } else {
                errx(EXIT_FAILURE, "illegal format -- %s", optarg)
            }
        case Int32(Character("s").asciiValue!):
            sep = optarg
        case Int32(Character("v").asciiValue!):
            errno = 0
            val = strtol(optarg, &ep, 10)
            if (ep != nil && ep!.pointee != 0) ||
               ((val == LONG_MIN || val == LONG_MAX) && errno != 0) {
                errx(EXIT_FAILURE, "invalid startnum value -- %s", optarg)
            }
            startnum = Int32(val)
        case Int32(Character("w").asciiValue!):
            errno = 0
            val = strtol(optarg, &ep, 10)
            if (ep != nil && ep!.pointee != 0) ||
               ((val == LONG_MIN || val == LONG_MAX) && errno != 0) {
                errx(EXIT_FAILURE, "invalid width value -- %s", optarg)
            }
            width = Int32(val)
            if !(width > 0) {
                errx(EXIT_FAILURE, "width argument must be > 0 -- %d", width)
            }
        case Int32(Character("?").asciiValue!):
            fallthrough
        default:
            usage()
        }
    }
    argc -= optind
    argv = argv.advanced(by: Int(optind))

    switch argc {
    case 0:
        break
    case 1:
        if strcmp(argv[0]!, "-") != 0 && freopen(argv[0], "r", stdin) == nil {
            err(EXIT_FAILURE, argv[0])
        }
    default:
        usage()
    }

    // Generate the delimiter sequence.
    memcpy(&delim, &delim1, delim1len)
    memcpy(&delim + Int(delim1len), &delim2, delim2len)
    delimlen = delim1len + delim2len

    #if !os(macOS)
    let intbuffersizeValue = max(Int(INT_STRLEN_MAXIMUM), Int(width)) + 1
    intbuffer = malloc(intbuffersizeValue)?.assumingMemoryBound(to: CChar.self)
    if intbuffer == nil {
        err(EXIT_FAILURE, "cannot allocate preformatting buffer")
    }
    #endif

    filter()

    #if os(macOS)
    if ferror(stdout) != 0 || fflush(stdout) != 0 {
        err(1, "stdout")
    }
    #endif
    exit(EXIT_SUCCESS)
}

//======================================================================
// MARK: - filter()
//======================================================================

func filter() {
    var buffer: UnsafeMutablePointer<CChar>? = nil
    var buffersize: size_t = 0
    var linelen: ssize_t = 0
    var line: Int32 = 0       // logical line number
    var section: Int32 = 0    // logical page section
    var adjblank: UInt32 = 0  // adjacent blank lines
    #if !os(macOS)
    var consumed: Int32 = 0
    #endif
    var donumber: Int32 = 0
    var idx: Int32 = 0

    adjblank = 0
    line = startnum
    section = BODY

    while { linelen = getline(&buffer, &buffersize, stdin); return linelen > 0 }() {
        for idx in Int32(FOOTER)...Int32(NP_LAST) {
            if (delimlen * size_t(idx + 1)) > size_t(linelen) {
                break
            }
            if memcmp(buffer! + Int(delimlen * size_t(idx)), &delim, delimlen) != 0 {
                break
            }
            if buffer![Int(delimlen * size_t(idx + 1))] == CChar(ascii: "\n") {
                #if os(macOS)
                if restart != 0 && idx >= section {
                #else
                if restart != 0 && idx >= section {
                #endif
                    line = startnum
                }
                section = idx
                adjblank = 0
                goto nextline
            }
        }

        switch numbering_properties[Int(section)].type {
        case .number_all:
            if buffer![0] == CChar(ascii: "\n") && { adjblank += 1; return adjblank }() < nblank {
                donumber = 0
            } else {
                donumber = 1; adjblank = 0
            }
        case .number_nonempty:
            donumber = (buffer![0] != CChar(ascii: "\n")) ? 1 : 0
        case .number_none:
            donumber = 0
        case .number_regex:
            donumber = (regexec(&numbering_properties[Int(section)].expr, buffer, 0, nil, 0) == 0) ? 1 : 0
        }

        if donumber != 0 {
            #if !os(macOS)
            consumed = sprintf(intbuffer, fmtcheck(format, "%*d"), width, line)
            printf("%s", intbuffer + max(0, Int(consumed) - Int(width)))
            #else
            printf(fmtcheck(format, "%*d"), width, line)
            #endif
            line += incr
        } else {
            printf("%*s", width, "")
        }
        fputs(sep, stdout)
        fwrite(buffer, size_t(linelen), 1, stdout)

        if ferror(stdout) != 0 {
            err(EXIT_FAILURE, "output error")
        }
nextline:
        continue
    }

    if ferror(stdin) != 0 {
        err(EXIT_FAILURE, "input error")
    }
    free(buffer)
}

//======================================================================
// MARK: - parse_numbering()
//======================================================================

func parse_numbering(_ argstr: UnsafePointer<CChar>!, _ section: Int) {
    var error: Int32 = 0
    var errorbuf = [CChar](repeating: 0, count: Int(NL_TEXTMAX))
    switch argstr[0] {
    case CChar(ascii: "a"):
        numbering_properties[section].type = .number_all
    case CChar(ascii: "n"):
        numbering_properties[section].type = .number_none
    case CChar(ascii: "t"):
        numbering_properties[section].type = .number_nonempty
    case CChar(ascii: "p"):
        if numbering_properties[section].type == .number_regex {
            regfree(&numbering_properties[section].expr)
        } else {
            numbering_properties[section].type = .number_regex
        }
        error = regcomp(&numbering_properties[section].expr, argstr + 1, REG_NEWLINE|REG_NOSUB)
        if error != 0 {
            regerror(error, &numbering_properties[section].expr, &errorbuf, errorbuf.count)
            errx(EXIT_FAILURE, "%s expr: %s -- %s", numbering_properties[section].name, errorbuf, argstr + 1)
        }
    default:
        errx(EXIT_FAILURE, "illegal %s line numbering type -- %s", numbering_properties[section].name, argstr)
    }
}

//======================================================================
// MARK: - usage()
//======================================================================

func usage() -> Never {
    fprintf(stderr,
"usage: nl [-p] [-b type] [-d delim] [-f type] [-h type] [-i incr] [-l num]\n"
"          [-n format] [-s sep] [-v startnum] [-w width] [file]\n")
    exit(EXIT_FAILURE)
}

//======================================================================
// MARK: - Entry Point
//======================================================================

_ = main(CommandLine.argc, CommandLine.unsafeArgv)
