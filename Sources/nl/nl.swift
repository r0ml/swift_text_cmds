
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


import CMigration

/// <#Description#>
@main final class nl : ShellCommand {
  
  var usage : String = """
usage: nl [-p] [-b type] [-d delim] [-f type] [-h type] [-i incr] [-l num]
          [-n format] [-s sep] [-v startnum] [-w width] [file]
"""
  
  struct CommandOptions {
    var format = FORMAT.RN
    var restart = true // 1?
    var sep: String = "\t"
    var startnum = 1
    var width = 6
    
    var incr : Int = 1
    var nblank : UInt = 1
    var delim1 : Character = "\\"
    var delim2 : Character = ":"
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    setlocale(LC_ALL, "")
    
    var options = CommandOptions()
    let supportedFlags = "pb:d:f:h:i:l:n:s:v:w:"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "p":
          options.restart = false
        case "b":
          try parse_numbering(v, .BODY)
        case "d":
          switch v.count {
            case 0: throw CmdErr(1, "missing delim argument")
            case 1:
              options.delim1 = v.first!
            case 2:
              options.delim1 = v.first!
              options.delim2 = v.dropFirst().first!
            default:
              throw CmdErr(1, "invalid delim argument -- \(v)")
          }
        case "f":
          try parse_numbering(v, .FOOTER)
        case "h":
          try parse_numbering(v, .HEADER)
        case "i":
          if let val = Int(v) {
            options.incr = val
          } else {
            throw CmdErr(1, "invalid incr argument -- \(v)")
          }
        case "l":
          if let uval = UInt(v) {
            options.nblank = uval
          } else {
            throw CmdErr(1, "invalid num argument -- \(v)")
          }
        case "n":
          if v == "ln" {
            options.format = FORMAT.LN
          } else if v == "rn" {
            options.format = FORMAT.RN
          } else if v == "rz" {
            options.format = FORMAT.RZ
          } else {
            throw CmdErr(1, "illegal format -- \(v)")
          }
        case "s":
          options.sep = v
        case "v":
          if let val = Int(v) {
            options.startnum = val
          } else {
            throw CmdErr(1, "invalid startnum value -- \(v)")
          }
        case "w":
          if let val = Int(v), val > 0 {
            options.width = val
          } else {
            throw CmdErr(1, "invalid width value -- \(v)")
          }
        case "?":
          fallthrough
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {

    var fp = FileDescriptor.standardInput
    switch options.args.count {
      case 0:
        break
      case 1:
        if options.args[0] != "-" {
          do {
            fp = try FileDescriptor(forReading: options.args[0] )
          } catch {
            throw CmdErr(1, "\(options.args[0]): \(error)")
          }
        }
      default:
        throw CmdErr(1)
    }
    
    try await filter(fp, options)
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
    var type: numbering_type         // numbering type
    var expr: regex_t?               // for type == number_regex
  }
  
  // Line numbering formats
  enum FORMAT : String {
    case LN = "%-*d"   // left justified, leading zeros suppressed
    case RN = "%*d"    // right justified, leading zeros suppressed
    case RZ = "%0*d"   // right justified, leading zeros kept
  }
  
  // Section constants
  enum Section : Int, CaseIterable {
    case FOOTER = 0
    case BODY   = 1
    case HEADER = 2
  }
  
  var numbering_properties: [Section : numbering_property] = [
    .FOOTER :  numbering_property(type: .number_none),
    .BODY : numbering_property(type: .number_nonempty),
    .HEADER : numbering_property(type: .number_none)
  ]
  
  // Macro: max(a, b)
  func max<T: Comparable>(_ a: T, _ b: T) -> T {
    return a > b ? a : b
  }
  
  // Maximum number of characters required for a decimal representation of an int.
  // ((sizeof (int) * CHAR_BIT - 1) * 302 / 1000 + 2)
  let INT_STRLEN_MAXIMUM = ((MemoryLayout<Int32>.size * Int(CHAR_BIT) - 1) * 302 / 1000 + 2)
  
  func filter(_ fp : FileDescriptor, _ options : CommandOptions) async throws(CmdErr) {
    
    var adjblank: UInt = 0  // adjacent blank lines
    
    var donumber = false
    
    var line = options.startnum
    var section = Section.BODY
    let dd = String(options.delim2)
    do {
      for try await buffer in fp.bytes.lines {
        
        var idx : Section?
        if buffer == String(repeating: dd, count: 3) {
          idx = .HEADER
        } else if buffer == String(repeating: dd, count: 2) {
          idx = .BODY
        } else if buffer == String(dd) {
          idx = .FOOTER
        }
        
        if let idx {
          if options.restart && idx.rawValue >= section.rawValue {
            line = options.startnum
          }
          section = idx
          adjblank = 0
          continue
        }
        
        switch numbering_properties[section]!.type {
          case .number_all:
            if buffer.isEmpty && { adjblank += 1; return adjblank }() < options.nblank {
              donumber = false
            } else {
              donumber = true
              adjblank = 0
            }
          case .number_nonempty:
            donumber = !buffer.isEmpty
          case .number_none:
            donumber = false
          case .number_regex:
            donumber = regexec(&numbering_properties[section]!.expr!, buffer, 0, nil, 0) == 0
        }
        
        if donumber {
          
          // print(String(fmtcheck(options.format, "%*d"), options.width, line), terminator: "")
          print(cFormat(options.format.rawValue, options.width, line), terminator: "")
          
          line += options.incr
        } else {
          print("%*s", options.width, "")
        }
        print(options.sep, terminator: "")
        print(buffer)
      }
    } catch {
      throw CmdErr(1, "read error: \(error)")
    }
  }
  
    //======================================================================
    // MARK: - parse_numbering()
    //======================================================================
    
    func parse_numbering(_ argstr: String, _ section: Section) throws(CmdErr) {
      switch argstr.first {
        case "a":
          numbering_properties[section]?.type = .number_all
        case "n":
          numbering_properties[section]?.type = .number_none
        case "t":
          numbering_properties[section]?.type = .number_nonempty
        case "p":
          if numbering_properties[section]?.type == .number_regex {
//            regfree(&numbering_properties[section]?.expr)
          } else {
            numbering_properties[section]?.type = .number_regex
          }
          
          var expr = regex_t()
          let astr = String(argstr.dropFirst())
          let error = astr.withCString {
            regcomp(&expr, $0, REG_NEWLINE|REG_NOSUB)
          }
          if error != 0 {
            let t = regerror(error, expr)
            throw CmdErr(1, "\(numbering_properties[section]!.type) expr: \(t) -- \(astr)")
          }
          numbering_properties[section]!.expr = expr
          
//          &numbering_properties[section].expr, &errorbuf, errorbuf.count)

        default:
          let k = numbering_properties[section]!
          // FIXME: does k.description work?
          throw CmdErr(1, "illegal \(k.type) line numbering type -- \(argstr)")
      }
    }
       
    
  }
  
