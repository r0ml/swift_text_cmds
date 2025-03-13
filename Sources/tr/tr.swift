
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025 using ChatGPT
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1988, 1993
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

@main final class tr : ShellCommand {
  
  var usage : String = """
    usage: tr [-Ccsu] string1 string2
           tr [-Ccu] -d string1
           tr [-Ccu] -s string1
           tr [-Ccu] -ds string1 string2
    """
  
  struct CommandOptions {
    var Cflag = false
    var cflag = false
    var dflag = false
    var sflag = false
    var uflag = false   // -u: unbuffered output
    var input = FileHandle.standardInput
    
    var string1: String = ""
    var string2: String? = nil     // Only used for translation and squeeze+delete mode.
    var args : [String] = CommandLine.arguments
  }
  
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    // Set the locale (as in the original C code).
    setlocale(LC_ALL, "")
    
    var options = CommandOptions()
    
    
    let supportedFlags = "Ccdsui:"
    let go = BSDGetopt(supportedFlags)
    
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "C":
          options.Cflag = true
          options.cflag = false
        case "c":
          options.cflag = true
          options.Cflag = false
        case "d":
          options.dflag = true
        case "s":
          options.sflag = true
        case "u":
          // unbuffered is not a thing anymore
          break
        case "i":
          do {
            let k = try FileHandle(forReadingFrom: URL(filePath: v))
            options.input = k
          } catch {
            throw CmdErr(1, "error reading \(v): \(error.localizedDescription)")
          }
        case "?":
          fallthrough
        default: throw CmdErr(1)
      }
    }
    let args = go.remaining
    
    // Now expect one or two remaining arguments.
    switch args.count {
      case 1:
        options.string1 = args[0]
      case 2:
        options.string1 = args[0]
        options.string2 = args[1]
      case 0:
        fallthrough
      default:
        throw CmdErr(1)
    }
    
    // In deletion mode (-d) only one string is allowed.
    if options.dflag {
      if options.string2 != nil {
        throw CmdErr(1)
      }
      
    }
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    
    // The original C code distinguishes several cases:
    //   - tr -ds string1 string2 : delete characters in string1 then squeeze using string2
    //   - tr -d string1        : deletion mode
    //   - tr -s string1        : squeeze mode
    //   - tr string1 string2   : translation mode (with optional squeeze)
    
    if options.dflag && options.sflag {
      // Both deletion and squeeze:
      // First, build the deletion set from string1 (possibly complemented).
      
      //      let delete = setup(string1,
      
      // )(on: input, set1: config.string1, complement: config.complement)
      // Then, squeeze the result using the second argument.

      fatalError("dflag+sflag not yet implemented" )
    } else if options.dflag {
        if options.string2 != nil {
          throw CmdErr(1)
        }
        
        let delete = setup(options.string1, options)
        
        do {
          for try await ch in options.input.bytes.unicodeScalars {
            if !delete.contains(ch) {
              print(ch, terminator: "")
            }
          }
        } catch {
          throw CmdErr(1, "read error: \(error.localizedDescription)")
        }
        
      } else if options.sflag, options.string2 == nil {
        // Squeeze-only mode.
        fatalError("squeeze-only not implemented")
        /*
         output = runSqueeze(on: input, set1: config.string1, complement: config.complement)
         */
      } else {
        if options.string2 == nil {
          throw CmdErr(1)
        }
      
      // translation from one string to the other
      
      fatalError("translation not implemented")
      /*
       output = runTranslation(on: input, config: config)
       
       // Write the result to stdout.
       // (If unbuffered output is requested, flush immediately.)
       print(output, terminator: "")
       */
    }
    try? FileHandle.standardOutput.synchronize()
  }
  
  
  
  /*
   The task is to convert a long C code snippet that forms part of a ‘tr’ command implementation into Swift. The C code includes things like signal processing logic, handling multiple options (e.g., -C, -c), and string manipulations like translation, squeeze, and delete.
   I’m noticing that several functions and types like cset_alloc, cset_add, or setup are referenced but undefined in the snippet. This will need more attention when converting to Swift. The conversion should also account for these undefined functions and variables, like s1 and s2.
   
   The code uses global/static variables like s1 and s2, and I can see that translating it into Swift will be pretty complex. The C code handles various options for the tr command — deleting, squeezing, translating characters, and complementing character sets with options like -C and -c. It also uses wide character functions and setlocale, which are not standard in Swift. I think I’ll have to emulate this behavior with equivalents in Swift, like creating CSet and CMap classes.
   
   To convert to Swift, I’ll use Unicode string processing like Swift’s String and Unicode scalars. Instead of getwchar(), I can use readLine() to capture input. For character processing, I’ll iterate over Unicode scalars. Command-line options like -C, -c, -d, -s, and -u can be handled with CommandLine.arguments for parsing. I’ll aim for a rough translation of the C functionality, focusing on operations like deletion, squeezing, and translation mapping. Classes for CSet and CMap will likely be essential for handling character sets and mappings.
   
   To implement the tr functionality in Swift, I’ll focus on handling flags like -d, -s, and -C, as well as managing translation, deletion, and squeezing of characters. The program will parse command-line input using CommandLine.arguments, then set flags. Depending on the flags, the program will handle deletion, squeezing, or character translation with appropriate logic for uppercase and lowercase conversions.
   I’ll implement supporting functions like “setup” using Set<Character> for deletion sets and add a dictionary for mapping characters in translation. For simplicity, I’ll skip some advanced behavior but will aim to replicate the core logic.
   */
  
  /*
   Explanation
   1.  Command–Line Parsing:
   The Swift version uses a simple parser that examines CommandLine.arguments and fills a TRConfig struct with flags (‑C/‑c, ‑d, ‑s, and ‑u) plus the operand strings. If the number of operands is incorrect, the program calls usage().
   2.  Input and Processing:
   The entire standard input is read into a single string (using readLine()) and then processed.
   •  In deletion mode (‑d) the program builds a set of characters to delete (or its complement) and filters them out.
   •  In squeeze mode (‑s) it “squeezes” adjacent duplicate characters (only for those in the given set).
   •  In translation mode the program builds a mapping (using a Swift dictionary) from characters in string1 to string2 (repeating the last character if necessary) and then applies that mapping. If both ‑s and translation are requested the output is “squeezed” as it is produced.
   3.  Simplifications:
   This Swift code is a simplified version. For example, the original C code’s wide–character handling, case–conversion (using towlower/towupper), and complex mapping and caching (via cmap/cset) have been replaced by Swift’s native Unicode support and dictionary/set types. In a production-quality port you might want to more closely mimic all the nuances of the original.
   
   */
  
  // -----------------------------------------------------------------------------
  
  /*
  /// In deletion mode, remove characters (or their complement) specified in `set1` from `input`.
  func runDeletion(on input: String, set1: String, complement: Bool) -> String {
    // Build the deletion set.
    // (For simplicity we consider the set of characters in string1.
    // In a more complete version you might work over the entire Unicode range.)
    let baseSet = Set(set1)
    let deletionSet: Set<Character>
    if complement {
      // Complement: remove all characters that are NOT in set1.
      // For demonstration we limit our universe to ASCII printable characters.
      var universe = Set<Character>()
      for scalar in Unicode.Scalar(32)...Unicode.Scalar(126) {
        universe.insert(Character(scalar))
      }
      deletionSet = universe.subtracting(baseSet)
    } else {
      deletionSet = baseSet
    }
    
    // Build the output by skipping any character in the deletion set.
    let result = input.filter { !deletionSet.contains($0) }
    return result
  }
  */
  
  func setup(_ arg : String, _ options : CommandOptions) -> CharacterSet {
    var cs = CharacterSet()
    let str = STR(arg)
    while str.next() {
      cs.insert(str.lastch)
    }
    if options.Cflag {
      fatalError("Cflag not implemented")
     // cs.insert(charactersIn: ...type rune...)
    }
    if options.cflag || options.Cflag {
      cs.invert()
    }
    return cs
  }

  
  /*
  
  
  /// In squeeze mode, collapse sequences of identical characters (from `set1`) into a single occurrence.
  func runSqueeze(on input: String, set1: String, complement: Bool) -> String {
    let baseSet = Set(set1)
    let squeezeSet: Set<Character>
    if complement {
      var universe = Set<Character>()
      for scalar in Unicode.Scalar(32)...Unicode.Scalar(126) {
        universe.insert(Character(scalar))
      }
      squeezeSet = universe.subtracting(baseSet)
    } else {
      squeezeSet = baseSet
    }
    
    var output = ""
    var last: Character? = nil
    for ch in input {
      if let lastCh = last, lastCh == ch, squeezeSet.contains(ch) {
        continue // Skip duplicate.
      }
      output.append(ch)
      last = ch
    }
    return output
  }
   
   */
  
  
  /*
  /// In translation mode, build a mapping from characters in string1 to characters in string2.
  /// If string1 is longer than string2, the last character of string2 is repeated.
  func buildTranslationMap(from string1: String, to string2: String, complement: Bool) -> [Character: Character] {
    var map = [Character: Character]()
    let s1 = Array(string1)
    let s2 = Array(string2)
    
    if complement {
      // For complement mode, the translation applies to all characters NOT in s1.
      // For demonstration we limit our universe to ASCII printable characters.
      var universe = [Character]()
      for scalar in Unicode.Scalar(32)...Unicode.Scalar(126) {
        let ch = Character(scalar)
        if !s1.contains(ch) {
          universe.append(ch)
        }
      }
      for (i, ch) in universe.enumerated() {
        let replacement = (i < s2.count) ? s2[i] : s2.last!
        map[ch] = replacement
      }
    } else {
      // Normal translation: map characters in s1 to corresponding characters in s2.
      for (i, ch) in s1.enumerated() {
        let replacement = (i < s2.count) ? s2[i] : s2.last!
        map[ch] = replacement
      }
    }
    
    return map
  }
  
   */
  
  
  /*
  /// Processes the input text in translation mode.
  /// If squeeze is true, then after translating characters a squeeze set is used
  /// to collapse duplicate output.
  func runTranslation(on input: String, options: CommandOptions) throws(CmdErr) -> String {
    guard let string2 = options.string2 else {
      throw CmdErr(1)
    }
    
    // Build the translation mapping.
    let map = buildTranslationMap(from: options.string1, to: string2, complement: options.cflag)
    
    // For squeeze mode in translation, we “squeeze” any output character that is a mapping target.
    let squeezeSet: Set<Character> = options.sflag ? Set(map.values) : []
    
    var output = ""
    var lastOut: Character? = nil
    for ch in input {
      // Look up a translation if available.
      let newCh: Character
      if options.cflag {
        // In complement mode, only characters not in string1 are translated.
        if !options.string1.contains(ch), let mapped = map[ch] {
          newCh = mapped
        } else {
          newCh = ch
        }
      } else {
        newCh = map[ch] ?? ch
      }
      
      if options.sflag, newCh == lastOut, squeezeSet.contains(newCh) {
        continue
      }
      
      output.append(newCh)
      lastOut = newCh
    }
    return output
  }
  */
}

/*
extension CharacterSet {
  init(_ arg : String, _ options : tr.CommandOptions) {
    while let n = next(arg) {
      self.insert(n)
    }
    
    if options.Cflag {
      // what goes here?
    }
    
    if options.Cflag || options.cflag {
      self.invert()
    }
  }
  
  func cset_in(_ arg : String, _ ch : Character) -> Bool {
    return arg.contains(ch)
  }
}
*/
