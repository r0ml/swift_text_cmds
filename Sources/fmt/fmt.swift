
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/* Copyright (c) 1997 Gareth McCaughan. All rights reserved.
 
  Redistribution and use of this code, in source or binary forms,
  with or without modification, are permitted subject to the following
  conditions:
 
   - Redistribution of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
 
   - If you distribute modified source code it must also include
     a notice saying that it has been modified, and giving a brief
     description of what changes have been made.
 
  Disclaimer: I am not responsible for the results of using this code.
              If it formats your hard disc, sends obscene messages to
              your boss and kills your children then that's your problem
              not mine. I give absolutely no warranty of any sort as to
              what the program will do, and absolutely refuse to be held
              liable for any consequences of your using it.
              Thank you. Have a nice day.
 */

/* Sensible version of fmt
 *
 * Syntax: fmt [ options ] [ goal [ max ] ] [ filename ... ]
 *
 * Since the documentation for the original fmt is so poor, here
 * is an accurate description of what this one does. It's usually
 * the same. The *mechanism* used may differ from that suggested
 * here. Note that we are *not* entirely compatible with fmt,
 * because fmt gets so many things wrong.
 *
 * 1. Tabs are expanded, assuming 8-space tab stops.
 *    If the `-t <n>' option is given, we assume <n>-space
 *    tab stops instead.
 *    Trailing blanks are removed from all lines.
 *    x\b == nothing, for any x other than \b.
 *    Other control characters are simply stripped. This
 *    includes \r.
 * 2. Each line is split into leading whitespace and
 *    everything else. Maximal consecutive sequences of
 *    lines with the same leading whitespace are considered
 *    to form paragraphs, except that a blank line is always
 *    a paragraph to itself.
 *    If the `-p' option is given then the first line of a
 *    paragraph is permitted to have indentation different
 *    from that of the other lines.
 *    If the `-m' option is given then a line that looks
 *    like a mail message header, if it is not immediately
 *    preceded by a non-blank non-message-header line, is
 *    taken to start a new paragraph, which also contains
 *    any subsequent lines with non-empty leading whitespace.
 *    Unless the `-n' option is given, lines beginning with
 *    a . (dot) are not formatted.
 * 3. The "everything else" is split into words; a word
 *    includes its trailing whitespace, and a word at the
 *    end of a line is deemed to be followed by a single
 *    space, or two spaces if it ends with a sentence-end
 *    character. (See the `-d' option for how to change that.)
 *    If the `-s' option has been given, then a word's trailing
 *    whitespace is replaced by what it would have had if it
 *    had occurred at end of line.
 * 4. Each paragraph is sent to standard output as follows.
 *    We output the leading whitespace, and then enough words
 *    to make the line length as near as possible to the goal
 *    without exceeding the maximum. (If a single word would
 *    exceed the maximum, we output that anyway.) Of course
 *    the trailing whitespace of the last word is ignored.
 *    We then emit a newline and start again if there are any
 *    words left.
 *    Note that for a blank line this translates as "We emit
 *    a newline".
 *    If the `-l <n>' option is given, then leading whitespace
 *    is modified slightly: <n> spaces are replaced by a tab.
 *    Indented paragraphs (see above under `-p') make matters
 *    more complicated than this suggests. Actually every paragraph
 *    has two `leading whitespace' values; the value for the first
 *    line, and the value for the most recent line. (While processing
 *    the first line, the two are equal. When `-p' has not been
 *    given, they are always equal.) The leading whitespace
 *    actually output is that of the first line (for the first
 *    line of *output*) or that of the most recent line (for
 *    all other lines of output).
 *    When `-m' has been given, message header paragraphs are
 *    taken as having first-leading-whitespace empty and
 *    subsequent-leading-whitespace two spaces.
 *
 * Multiple input files are formatted one at a time, so that a file
 * never ends in the middle of a line.
 *
 * There's an alternative mode of operation, invoked by giving
 * the `-c' option. In that case we just center every line,
 * and most of the other options are ignored. This should
 * really be in a separate program, but we must stay compatible
 * with old `fmt'.
 *
 * QUERY: Should `-m' also try to do the right thing with quoted text?
 * QUERY: `-b' to treat backslashed whitespace as old `fmt' does?
 * QUERY: Option meaning `never join lines'?
 * QUERY: Option meaning `split in mid-word to avoid overlong lines'?
 * (Those last two might not be useful, since we have `fold'.)
 *
 * Differences from old `fmt':
 *
 *   - We have many more options. Options that aren't understood
 *     generate a lengthy usage message, rather than being
 *     treated as filenames.
 *   - Even with `-m', our handling of message headers is
 *     significantly different. (And much better.)
 *   - We don't treat `\ ' as non-word-breaking.
 *   - Downward changes of indentation start new paragraphs
 *     for us, as well as upward. (I think old `fmt' behaves
 *     in the way it does in order to allow indented paragraphs,
 *     but this is a broken way of making indented paragraphs
 *     behave right.)
 *   - Given the choice of going over or under |goal_length|
 *     by the same amount, we go over; old `fmt' goes under.
 *   - We treat `?' as ending a sentence, and not `:'. Old `fmt'
 *     does the reverse.
 *   - We return approved return codes. Old `fmt' returns
 *     1 for some errors, and *the number of unopenable files*
 *     when that was all that went wrong.
 *   - We have fewer crashes and more helpful error messages.
 *   - We don't turn spaces into tabs at starts of lines unless
 *     specifically requested.
 *   - New `fmt' is somewhat smaller and slightly faster than
 *     old `fmt'.
 *
 * Bugs:
 *
 *   None known. There probably are some, though.
 *
 * Portability:
 *
 *   I believe this code to be pretty portable. It does require
 *   that you have `getopt'. If you need to include "getopt.h"
 *   for this (e.g., if your system didn't come with `getopt'
 *   and you installed it yourself) then you should arrange for
 *   NEED_getopt_h to be #defined.
 *
 *   Everything here should work OK even on nasty 16-bit
 *   machines and nice 64-bit ones. However, it's only really
 *   been tested on my FreeBSD machine. Your mileage may vary.
 */

import Foundation
import CMigration

@main final class fmt : ShellCommand {
  
  var usage : String =  """
    usage:   fmt [-cmps] [-d chars] [-l num] [-t num]
                 [-w width | -width | goal [maximum]] [file ...]
    Options: -c     center each line instead of formatting
             -d <chars> double-space after <chars> at line end
             -l <n> turn each <n> spaces at start of line into a tab
             -m     try to make sure mail header lines stay separate
             -n     format lines beginning with a dot
             -p     allow indented paragraphs
             -s     coalesce whitespace inside lines
             -t <n> have tabs every <n> columns
             -w <n> set maximum width to <n>
             goal   set target width to goal
    """
  
  
  struct CommandOptions {
    var centerP = false                      // Try to center lines?
    var goalLength: Int = 0                  // Target length for output lines
    var maxLength: Int = 0                   // Maximum length for output lines
    var coalesceSpaces = false               // Coalesce multiple whitespace into a single space
    var allowIndentedParagraphs = false      // Allow first line to have different indentation
    var tabWidth: Int = 8                     // Number of spaces per tab stop
    var outputTabWidth: Int = 8               // Number of spaces per tab when squashing leading spaces
    var sentenceEnders: [Character] = [".", "?", "!"] // Characters after which to double-space
    var grokMailHeaders = false              // Treat embedded mail headers specially
    var formatTroff = false                   // Format troff?
    
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "0123456789cd:l:mnpst:w:"
    let go = BSDGetopt(supportedFlags)
    
    thewhile: while let (k, v) = try go.getopt() {
      switch k {
        case "-":
          break thewhile
        case "c":
          options.centerP = true
          options.formatTroff = true
        case "d":
          if !v.isEmpty {
            options.sentenceEnders = Array(v)
          } else {
            throw CmdErr(Int(EX_USAGE), "Error: -d requires an argument")
          }
        case "l":
          if !v.isEmpty {
            options.outputTabWidth = getNonNegative(v, errMess: "output tab width must be non-negative", fussyP: true)
          } else {
            throw CmdErr(Int(EX_USAGE), "Error: -l requires an argument")
          }
        case "m":
          options.grokMailHeaders = true
        case "n":
          options.formatTroff = true
        case "p":
          options.allowIndentedParagraphs = true
        case "s":
          options.coalesceSpaces = true
        case "t":
          if !v.isEmpty {
            options.tabWidth = getPositive(v, errMess: "tab width must be positive", fussyP: true)
          } else {
            throw CmdErr(Int(EX_USAGE), "Error: -t requires an argument")
          }
        case "w":
          if !v.isEmpty {
            options.goalLength = getPositive(v, errMess: "width must be positive", fussyP: true)
            options.maxLength = options.goalLength
          } else {
            throw CmdErr(Int(EX_USAGE), "Error: -w requires an argument")
          }
        case "0"..."9":
          if options.goalLength == 0 {
            let numberString = String(k)
            options.goalLength = getPositive(numberString, errMess: "width must be nonzero", fussyP: true)
            options.maxLength = options.goalLength
          }
        case "h": fallthrough
        default: throw CmdErr(1)
      }
    }
    
    options.args = go.remaining
    
    
    // Handle positional arguments: [goal [maximum]]
    if let firstArg = options.args.first, options.goalLength == 0 {
      options.goalLength = getPositive(firstArg, errMess: "goal length must be positive", fussyP: false)
      options.args.removeFirst()
      if let secondArg = options.args.first {
        options.maxLength = getPositive(secondArg, errMess: "max length must be positive", fussyP: false)
        options.args.removeFirst()
        if options.maxLength < options.goalLength {
          throw CmdErr(Int(EX_USAGE), "Error: max length must be >= goal length")
        }
      }
    }
    
    if options.goalLength == 0 {
      options.goalLength = 65
    }
    if options.maxLength == 0 {
      options.maxLength = options.goalLength + 10
    }
    if options.maxLength >= Int.max {
      throw CmdErr(Int(EX_USAGE), "Error: max length too large")
    }
    
    
    
    return options
  }
  
  
  var nErrors = 0                           // Number of failed files. Return on exit.
  var outputBuffer = ""                     // Output line buffer
  var outputInParagraph = false             // Indicates if any part of the current paragraph has been written out
  var x: Int = 0                            // Horizontal position in output line
  var x0: Int = 0                           // Horizontal position ignoring leading whitespace
  var pendingSpaces: Int = 0                // Spaces to add before the next word

  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    
    setlocale(LC_CTYPE, "")
    var goalLengthSet = false
    
    // Initialize the output buffer
    outputBuffer = ""
    
    // Process files or standard input
    if !options.args.isEmpty {
      for file in options.args {
        process_named_file(file, options)
      }
    } else {
      // Read from standard input
      if let standardInput = InputStream(fileAtPath: "/dev/stdin") {
        processStream(stream: standardInput, name: "standard input", options)
      } else {
        throw CmdErr(Int(EX_NOINPUT), "Error: Could not open standard input")
      }
    }
    
    // Exit with appropriate status
    exit(nErrors > 0 ? EX_NOINPUT : 0)
  }
  
  
  
  // MARK: - Constants
  
  let SILLY: Int = Int.max // Represents a value that should never be a genuine line length
  
  // MARK: - Helper Functions
  
  /// Converts a string to an array of wide characters.
  /// Swift's `Character` type handles Unicode scalars, which suffices for most cases.
  func stringToWideCharacters(_ string: String) -> [Character] {
    return Array(string)
  }
  
  /// Safely converts a string to a positive integer. Exits with an error message if conversion fails.
  func getPositive(_ s: String, errMess: String, fussyP: Bool) -> Int {
    if let result = Int(s), result > 0 {
      return result
    } else {
      if fussyP {
        fputs("Error: \(errMess)\n", stderr)
        exit(EX_USAGE)
      } else {
        return 0
      }
    }
  }
  
  /// Safely converts a string to a non-negative integer. Exits with an error message if conversion fails.
  func getNonNegative(_ s: String, errMess: String, fussyP: Bool) -> Int {
    if let result = Int(s), result >= 0 {
      return result
    } else {
      if fussyP {
        fputs("Error: \(errMess)\n", stderr)
        exit(EX_USAGE)
      } else {
        return 0
      }
    }
  }
  
  /// Checks if a line might be a mail header based on specific criteria.
  func mightBeHeader(_ line: String) -> Bool {
    guard let first = line.first, first.isUppercase else {
      return false
    }
    let pattern = "^[A-Z][-A-Za-z0-9]*:\\s"
    if let _ = line.range(of: pattern, options: .regularExpression) {
      return true
    }
    return false
  }
  
  /// Calculates the length of indentation (number of leading spaces) in a line.
  func indentLength(_ line: String) -> Int {
    return line.prefix { $0 == " " }.count
  }
  
  // MARK: - Paragraph Handling
  
  /// Begins a new paragraph with specified indentation.
  func newParagraph(oldIndent: Int, indent: Int, _ options : CommandOptions) {
    if !outputBuffer.isEmpty {
      if oldIndent > 0 {
        outputIndent(nSpaces: oldIndent, options)
      }
      print(outputBuffer)
    }
    x = indent
    x0 = 0
    outputBuffer = ""
    pendingSpaces = 0
    outputInParagraph = false
  }
  
  /// Outputs spaces or tabs for leading indentation.
  func outputIndent(nSpaces: Int, _ options : CommandOptions) {
    var spaces = nSpaces
    if options.outputTabWidth > 0 {
      while spaces >= options.outputTabWidth {
        print("\t", terminator: "")
        spaces -= options.outputTabWidth
      }
    }
    for _ in 0..<spaces {
      print(" ", terminator: "")
    }
  }
  
  /// Outputs a single word or adds it to the buffer.
  func outputWord(indent0: Int, indent1: Int, word: String, spaces: Int, _ options : CommandOptions) {
    let indent = outputInParagraph ? indent1 : indent0
    let width = word.reduce(0) { $0 + wcwidth($1) }
    let newX = x + pendingSpaces + width
    
    // Determine the number of spaces to add
    var actualSpaces = spaces
    if options.coalesceSpaces || spaces == 0 {
      if let lastChar = word.last, options.sentenceEnders.contains(lastChar) {
        actualSpaces = 2
      } else {
        actualSpaces = 1
      }
    }
    
    if newX <= options.goalLength {
      // Add spaces and word to the buffer
      outputBuffer += String(repeating: " ", count: pendingSpaces)
      outputBuffer += word
      x += pendingSpaces + width
      pendingSpaces = actualSpaces
    } else {
      // Output the current buffer
      if indent > 0 {
        outputIndent(nSpaces: indent, options)
      }
      print(outputBuffer, terminator: "")
      if x0 == 0 || (newX <= options.maxLength && (newX - options.goalLength) <= (options.goalLength - x)) {
        // Add spaces before the word
        print(String(repeating: " ", count: pendingSpaces), terminator: "")
        // Add the word to the buffer
        outputBuffer = word
        x = indent1 + width
        pendingSpaces = actualSpaces
      } else {
        // If the word itself exceeds maxLength, print it on a new line
        if indent + width > options.maxLength {
          print()
          if indent > 0 {
            outputIndent(nSpaces: indent, options)
          }
          print(word, terminator: "")
          x = indent1
          pendingSpaces = 0
          outputBuffer = ""
        } else {
          // Start a new buffer with the word
          outputBuffer = word
          x = indent1 + width
          pendingSpaces = actualSpaces
        }
      }
      print()
      outputInParagraph = true
    }
  }
  
  /// Centers each line in the stream.
  func centerStream(stream: InputStream, name: String, _ options : CommandOptions) {
    let buffer = StreamReader(stream: stream)
    while let line = buffer.nextLine() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      let lineWidth = trimmedLine.reduce(0) { $0 + wcwidth($1) }
      var padding = ""
      var currentWidth = 0
      while currentWidth < options.goalLength - lineWidth {
        padding += " "
        currentWidth += 1
      }
      print("\(padding)\(trimmedLine)")
    }
    if buffer.hasError {
      fputs("Error reading \(name)\n", stderr)
      nErrors += 1
    }
  }
  
  /// Reads a single line from the stream, handling tabs, control characters, and backspaces.
  func getLine(stream: InputStream, _ options : CommandOptions) -> String? {
    var line = ""
    var spacesPending = 0
    var troff = false
    var col = 0
    
    let buffer = StreamReader(stream: stream)
    if let rawLine = buffer.nextLine() {
      var characters = Array(rawLine)
      if !characters.isEmpty && characters[0] == "." && !options.formatTroff {
        troff = true
      }
      for ch in characters {
        if ch == " " {
          spacesPending += 1
        } else if ch == "\t" {
          spacesPending += options.tabWidth - (col + spacesPending) % options.tabWidth
        } else if ch == "\u{07}" {
          if !line.isEmpty {
            line.removeLast()
            if col > 0 { col -= 1 }
          }
        } else if troff || 0 != iswprint(Int32(ch.unicodeScalars.first!.value) ) {
          line += String(repeating: " ", count: spacesPending)
          spacesPending = 0
          line.append(ch)
          col += wcwidth(ch)
        }
      }
      return line
    }
    return nil
  }
  
  /// Safely reallocates memory. In Swift, memory management is handled automatically,
  /// so this function is not needed. Included for completeness.
  func xrealloc(_ ptr: Any?, _ nbytes: Int) -> Any? {
    // Swift handles memory automatically. Placeholder function.
    return nil
  }
  

  // MARK: - Stream Reader
  
  /// A simple line reader for InputStream.
  class StreamReader {
    let stream: InputStream
    let bufferSize: Int
    var buffer: [UInt8]
    var atEOF: Bool = false
    
    init(stream: InputStream, bufferSize: Int = 4096) {
      self.stream = stream
      self.bufferSize = bufferSize
      self.buffer = [UInt8](repeating: 0, count: bufferSize)
      stream.open()
    }
    
    deinit {
      stream.close()
    }
    
    var hasError: Bool = false
    
    func nextLine() -> String? {
      var line = ""
      while true {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
          hasError = true
          return nil
        }
        if bytesRead == 0 {
          return line.isEmpty ? nil : line
        }
        if let range = buffer[0..<bytesRead].firstIndex(of: UInt8(ascii: "\n")) {
          if range > 0 {
            if let str = String(bytes: Array(buffer[0..<range]), encoding: .utf8) {
              line += str
            }
          }
          // Move the stream's read position past the newline
          let remaining = bytesRead - (range + 1)
          if remaining > 0 {
            let newBuffer = Array(buffer[(range + 1)..<bytesRead])
            buffer = newBuffer + Array(repeating: 0, count: bufferSize - remaining)
          }
          return line
        } else {
          if let str = String(bytes: Array(buffer[0..<bytesRead]), encoding: .utf8) {
            line += str
          }
        }
      }
    }
  }
  
  // MARK: - Processing Functions
  
  /// Processes a single named file.
  func processNamedFile(_ name: String, _ options : CommandOptions) {
    guard let fileStream = InputStream(fileAtPath: name) else {
      fputs("Warning: Could not open file \(name)\n", stderr)
      nErrors += 1
      return
    }
    processStream(stream: fileStream, name: name, options)
    if fileStream.streamStatus == .error {
      fputs("Warning: Error reading file \(name)\n", stderr)
      nErrors += 1
    }
  }
  
  /// Processes a stream. This is where the real work happens, except centering is handled separately.
  func processStream(stream: InputStream, name: String, _ options: CommandOptions) {
    var lastIndent = SILLY
    var paraLineNumber = 0
    var firstIndent = SILLY
    var prevHeaderType: HdrType = .paragraphStart
    
    if options.centerP {
      centerStream(stream: stream, name: name, options)
      return
    }
    
    let buffer = StreamReader(stream: stream)
    while let line = buffer.nextLine() {
      let np = indentLength(line)
      var headerType: HdrType = .nonHeader
      
      if options.grokMailHeaders && prevHeaderType != .nonHeader {
        if np == 0 && mightBeHeader(line) {
          headerType = .header
        } else if np > 0 && prevHeaderType.rawValue > HdrType.nonHeader.rawValue {
          headerType = .continuation
        }
      }
      
      // Determine if a new paragraph should be started
      let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
      let isTroff = line.starts(with: ".") && !options.formatTroff
      let shouldStartNewParagraph = isBlank ||
      isTroff ||
      headerType == .header ||
      (headerType == .nonHeader && prevHeaderType.rawValue > HdrType.nonHeader.rawValue) ||
      (np != lastIndent && headerType != .continuation && (!options.allowIndentedParagraphs || paraLineNumber != 1))
      
      if shouldStartNewParagraph {
        newParagraph(oldIndent: outputInParagraph ? lastIndent : firstIndent, indent: np, options)
        paraLineNumber = 0
        firstIndent = np
        lastIndent = np
        if headerType == .header {
          lastIndent = 2 // For continuation lines
        }
        if isBlank || isTroff {
          if isBlank {
            print()
          } else {
            print(line)
          }
          prevHeaderType = .paragraphStart
          continue
        }
      } else {
        if np != lastIndent && headerType != .continuation {
          lastIndent = np
        }
      }
      prevHeaderType = headerType
      
      // Process the words in the line
      let words = line.split(separator: " ", omittingEmptySubsequences: false)
      for (index, wordSlice) in words.enumerated() {
        let word = String(wordSlice)
        let spaces = (index < words.count - 1) ? 1 : 0
        outputWord(indent0: firstIndent, indent1: lastIndent, word: word, spaces: spaces, options)
      }
      paraLineNumber += 1
    }
    
    // Finish the last paragraph
    newParagraph(oldIndent: outputInParagraph ? lastIndent : firstIndent, indent: 0, options)
    if buffer.hasError {
      fputs("Warning: Error reading \(name)\n", stderr)
      nErrors += 1
    }
  }
  
  /// Processes a named file by opening it and passing its stream to `processStream`.
  func process_named_file(_ name: String, _ options : CommandOptions) {
    processNamedFile(name, options)
  }
  
  // MARK: - Enumeration
  
  /// Types of mail header continuation lines.
  enum HdrType: Int {
    case paragraphStart = -1
    case nonHeader = 0
    case header = 1
    case continuation = 2
  }
  
}
