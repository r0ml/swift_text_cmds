// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024


// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

import Foundation
import Shared

let MB_CUR_MAX = 4

@main final class vis : ShellCommand {
  
  var usage : String = "Usage: vis [-bcfhlMmNnoSstw] [-e extra] [-F foldwidth] [file ...]"
  
  struct CommandOptions {
    var eflags : visOptions = []
    var debug = 0
    var extra : String? = nil
    var foldwidth : Int = 80
    var fold : Int = 0
    var markeol : Int = 0
    var none : Int = 0
    var args : [String] = CommandLine.arguments
  }
  
  struct visOptions : OptionSet {
    var rawValue : Int = 0
    
    static let NOSLASH = visOptions(rawValue: 1 << 0)
    static let CSTYLE = visOptions(rawValue: 1 << 1)
    static let HTTPSTYLE = visOptions(rawValue: 1 << 2)
    static let META = visOptions(rawValue: 1 << 3)
    static let NOLOCALE = visOptions(rawValue: 1 << 4)
    static let OCTAL = visOptions(rawValue: 1 << 5)
    static let SHELL = visOptions(rawValue: 1 << 6)
    static let WRITE = visOptions(rawValue: 1 << 7)
    static let MIMESTYLE = visOptions(rawValue: 1 << 8)
    static let SAFE = visOptions(rawValue: 1<<9)
    static let TAB = visOptions(rawValue: 1<<10)
    static let WHITE = visOptions(rawValue: 1<<19)
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "bcde:F:fhlMmNnoSstw"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "b" : options.eflags.insert(.NOSLASH)
        case "c" : options.eflags.insert(.CSTYLE)
        case "d": options.debug += 1
        case "e" : options.extra = v
        case "F":
          if let foldwidth = Int(v),
             foldwidth >= 5 {
            options.foldwidth = foldwidth
            options.markeol += 1
          } else {
            throw CmdErr(1, "can't fold lines to less than 5 cols")
          }
        case "f":
          options.fold += 1
        case "h":
          options.eflags.insert(.HTTPSTYLE)
        case "l":
          options.markeol += 1
        case "M":
          options.eflags.insert(.META)
        case "m":
          options.eflags.insert(.MIMESTYLE)
          if options.foldwidth == 80 {
            options.foldwidth = 76
          }
        case "N":
          options.eflags.insert(.NOLOCALE)
        case "n":
          options.none += 1
        case "o":
          options.eflags.insert(.OCTAL)
        case "S":
          options.eflags.insert(.SHELL)
        case "s":
          options.eflags.insert(.SAFE)
        case "t":
          options.eflags.insert(.TAB)
        case "w":
          options.eflags.insert(.WHITE)
        case "?":
          throw CmdErr(1)
        default: throw CmdErr(1)
      }
      if options.eflags.contains(.HTTPSTYLE) && options.eflags.contains(.MIMESTYLE) {
        throw CmdErr(1, "Can't specify -m and -h at the same time")
      }
    }
    
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    
    if options.args.isEmpty {
      process(fileHandle: FileHandle.standardInput)
    } else {
      for f in options.args {
        do {
          process(fileHandle: try FileHandle(forReadingFrom: URL(fileURLWithPath: f)))
        } catch(let e) {
          warn(e.localizedDescription)
        }
      }
    }
  }
  
  
  // ================================================
  
  func process(fileHandle: FileHandle) {
    var col = 0
    let nul: [UInt8] = [0]
    var cp: [UInt8] = [0]
    var c: UInt8 = 0
    var c1: UInt8 = 0
    var rachar: UInt8 = 0
    var mbibuff = [UInt8](repeating: 0, count: 2 * Int(MB_CUR_MAX) + 1)
    var buff = [UInt8](repeating: 0, count: 4 * Int(MB_CUR_MAX) + 1)
    var cerr = false
    var raerr = false
    
    // Helper to read a byte
    func readByte() -> UInt8? {
      guard let data = try? fileHandle.read(upToCount: 1),
            let byte = data.first else {
        return nil
      }
      return byte
    }
    
    // Helper to convert a character to its visual representation
    func visEncode(_ char: UInt8, _ lookahead: UInt8) -> String {
      // Simplified encoding logic, expand as needed for your use case
      if Character(UnicodeScalar(char) ).isASCII && char != 10 { // Handle ASCII and not newline
        return String(UnicodeScalar(char))
      } else {
        // Example: encode non-ASCII characters
        return "\\x" + String(format: "%02x", char)
      }
    }
    
    // Read the first character
    if let byte = readByte() {
      c = byte
    } else {
      cerr = true
      c = 0
    }
    
    while c != 0 {
      // Clear multibyte input buffer
      mbibuff = [UInt8](repeating: 0, count: mbibuff.count)
      
      // Read-ahead character
      if !cerr {
        if let byte = readByte() {
          rachar = byte
        } else {
          raerr = true
          rachar = 0
        }
      }
      
      // Process the current character
      if cerr || raerr {
        // Directly append erroneous byte
        buff[0] = c
      } else {
        // Convert character using custom visEncode logic
        let encoded = visEncode(c, rachar)
        let encodedBytes = [UInt8](encoded.utf8)
        buff.replaceSubrange(0..<encodedBytes.count, with: encodedBytes)
      }
      
      // Print the encoded string
      if let encodedStr = String(bytes: buff, encoding: .utf8) {
        print(encodedStr, terminator: "")
      }
      
      // Advance to the next character
      c = rachar
      cerr = raerr
    }
    
    // Handle partial lines
    if col > 0 {
      print("\\n")
    }
  }
  
}
