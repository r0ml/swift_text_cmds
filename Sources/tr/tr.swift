
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
    var input = FileDescriptor.standardInput
    
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
            let k = try FileDescriptor(forReading: v)
            options.input = k
          } catch {
            throw CmdErr(1, "error reading \(v): \(error)")
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
    
    return options
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    
    // The original C code distinguishes several cases:
    //   - tr -ds string1 string2 : delete characters in string1 then squeeze using string2
    //   - tr -d string1        : deletion mode
    //   - tr -s string1        : squeeze mode
    //   - tr string1 string2   : translation mode (with optional squeeze)
    
    /*
     * tr -ds [-Cc] string1 string2
     * Delete all characters (or complemented characters) in string1.
     * Squeeze all characters in string2.
     */

    if options.dflag && options.sflag {
      // Both deletion and squeeze:
      
      let delete = try setup(options.string1, options)
      var opx = options
      opx.cflag = false
      opx.Cflag = false
      let squeeze = try setup(options.string2!, opx)
      
      do {
        var lastch : UnicodeScalar? = nil
        for try await ch in options.input.bytes.unicodeScalars {
          if !delete.contains(ch) &&
              (lastch != ch || !squeeze.contains(ch)) {
            lastch = ch
            print(ch, terminator: "")
          }
        }
      } catch {
        throw CmdErr(1, "read error: \(error.localizedDescription)")
      }

      
      // )(on: input, set1: config.string1, complement: config.complement)
      // Then, squeeze the result using the second argument.

      /*
       * tr -d [-Cc] string1
       * Delete all characters (or complemented characters) in string1.
       */
    } else if options.dflag {
        if options.string2 != nil {
          throw CmdErr(1)
        }
        
        let delete = try setup(options.string1, options)
        
        do {
          for try await ch in options.input.bytes.unicodeScalars {
            if !delete.contains(ch) {
              print(ch, terminator: "")
            }
          }
        } catch {
          throw CmdErr(1, "read error: \(error.localizedDescription)")
        }
        
      /*
       * tr -s [-Cc] string1
       * Squeeze all characters (or complemented characters) in string1.
       */

      } else if options.sflag, options.string2 == nil {
        // Squeeze-only mode.
        let squeeze = try setup(options.string1, options)
        
        do {
          var lastch : UnicodeScalar? = nil
          for try await ch in options.input.bytes.unicodeScalars {
            if lastch != ch || !squeeze.contains(ch) {
              lastch = ch
              print(ch, terminator: "")
            }
          }
        } catch {
          throw CmdErr(1, "read error: \(error.localizedDescription)")
        }
        
        /*
         * tr [-Ccs] string1 string2
         * Replace all characters (or complemented characters) in string1 with
         * the character in the same position in string2.  If the -s option is
         * specified, squeeze all the characters in string2.
         */
      } else {
        if options.string2 == nil {
          throw CmdErr(1)
        }
      
      // translation from one string to the other
      
        
        if options.Cflag || options.cflag {
          // ??
        }
        
        var s2 = STR(options.string2!)
        if try !s2.next() {
          throw CmdErr(1, "empty string2")
        }
        
        /*
         * For -s result will contain only those characters defined
         * as the second characters in each of the toupper or tolower
         * pairs.
         */

        var squeeze = XCharacterSet()
        var map : [UnicodeScalar : UnicodeScalar] = [:]
        var defaultMap : UnicodeScalar?
        var carray = [UnicodeScalar]()
        
        let s1 = STR(options.string1)
 
      endloop:
        while try s1.next() {
          
          again: while true {
            if (s1.state == .cclassLower &&
                s2.state == .cclassUpper &&
                s1.cnt == 1 && s2.cnt == 1) {
              repeat {
                let ch = s1.lastch!.properties.uppercaseMapping.unicodeScalars.first!
                map[s1.lastch!] = ch
                if (options.sflag && ch.properties.isUppercase) {
                  squeeze.insert(ch)
                }
                
                if try !s1.next() {
                  break endloop
                }
              } while (s1.state == .cclassLower && s1.cnt > 1)
              /* skip upper set */
              repeat {
                if try !s2.next() {
                  break
                }
              } while (s2.state == .cclassUpper && s2.cnt > 1);
              continue again
            } else if (s1.state == .cclassUpper &&
                       s2.state == .cclassLower &&
                       s1.cnt == 1 && s2.cnt == 1) {
              repeat {
                let ch = s1.lastch!.properties.lowercaseMapping.unicodeScalars.first!
                map[s1.lastch!] = ch
                if options.sflag && ch.properties.isLowercase {
                  squeeze.insert(ch)
                }
                if try !s1.next() {
                  break endloop;
                }
              } while (s1.state == .cclassUpper && s1.cnt > 1);
              /* skip lower set */
              repeat {
                if try !s2.next() {
                  break;
                }
              } while (s2.state == .cclassLower && s2.cnt > 1);
              continue again
            } else {
              map[s1.lastch!]=s2.lastch
              if options.sflag {
                squeeze.insert(s2.lastch!)
              }
            }
            let _ = try s2.next()
            break again
          }
        }
        
        
        if options.cflag || (options.Cflag && ___mb_cur_max() > 1 )  {
          /*
           * This is somewhat tricky: since the character set is
           * potentially huge, we need to avoid allocating a map
           * entry for every character. Our strategy is to set the
           * default mapping to the last character of string #2
           * (= the one that gets automatically repeated), then to
           * add back identity mappings for characters that should
           * remain unchanged. We don't waste space on identity mappings
           * for non-characters with the -C option; those are simulated
           * in the I/O loop.
           */
          s2.str = Substring(s2.originalStr)
//          s2 = STR(options.string2!)
          s2.state = .normal
          for cnt in 0 ..< WINT_MAX {
            if options.Cflag && 0 == iswrune(cnt) {
              continue
            }
            let ucnt = UnicodeScalar(UInt32(cnt))!
            if map[ucnt] == nil {
              if try s2.next() {
                map[ucnt] = s2.lastch
                if options.sflag {
                  squeeze.insert(s2.lastch!)
                }
              }
            } else {
              map[ucnt] = ucnt
            }
            if (s2.state == .eos || s2.state == .infinite) &&
                cnt >= map.keys.max()!.value {
              break
            }
          }
          defaultMap = s2.lastch
        } else if options.Cflag {
          for cnt in 0 ..< NCHARS_SB {
//          for (p = carray, cnt = 0; cnt < NCHARS_SB; cnt++) {
            let ucnt = UnicodeScalar(UInt32(cnt))!
            if map[ucnt] == nil && iswrune(Int32(cnt)) != 0 {
              carray.append(ucnt)
            }
            else {
              map[ucnt] = ucnt
            }
          }
          let n = carray.count
          if (options.Cflag && n > 1) {
            carray.sort()
//            (void)mergesort(carray, n, sizeof(*carray), charcoll);
          }

          s2 = STR(options.string2!)
          for cnt in 0..<n {
            let _ = try s2.next()
            map[carray[cnt]] = s2.lastch
            /*
             * Chars taken from s2 can be different this time
             * due to lack of complex upper/lower processing,
             * so fill string2 again to not miss some.
             */
            if options.sflag {
              squeeze.insert(s2.lastch!)
            }
          }
        }
        
        
//        cset_cache(squeeze);
//        cmap_cache(map);

        do {
          if options.sflag {
            var lastch : UnicodeScalar? = nil
            for try await ch in options.input.bytes.unicodeScalars {
              let ch2 = !options.Cflag || iswrune(Int32(ch.value)) != 0 ?
              map[ch, default: defaultMap ?? ch] : ch
              if lastch != ch2 || !squeeze.contains(ch) {
                lastch = ch2
                print(ch2, terminator: "")
              }
            }
          }
          else {
            for try await ch in options.input.bytes.unicodeScalars {
              if let ch2 = !options.Cflag || iswrune(Int32(ch.value)) != 0 ? map[ch] : ch {
                print(String(ch2), terminator: "")
              } else {
                print(String(ch), terminator: "")
              }
            }
            
          }
        } catch {
          throw CmdErr(1, "read error: \(error.localizedDescription)")
        }
        
    }
    fsync(FileDescriptor.standardOutput.rawValue)
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
  
  func setup(_ arg : String, _ options : CommandOptions) throws(CmdErr) -> XCharacterSet {
    var cs = XCharacterSet()
    let str = STR(arg)
    while try str.next() {
      switch str.state {
        case .normal, .set:
          cs.insert(str.lastch!)
        case .cclass:
          if let c = str.cclass {
            switch c {
              case is CharacterSet:
                cs.cs.formUnion(c as! CharacterSet)
              case is XCharacterSet:
                cs.formUnion(c as! XCharacterSet)
              default:
                fatalError("not possible")
            }
          }
          str.state = .normal
        case .equiv:
          cs.eqc.insert(str.equiv!)
        default:
          fatalError("unknown string class")
      }
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
}
