// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation

// MARK: - Data Structures

/// Structure representing a field format (min.max) with alignment and padding flags.
struct FieldFormat {
    let minWidth: Int
    let maxWidth: Int
    let leftAdjust: Bool   // if true, left-adjusted (pad on right)
    let padWithZeros: Bool // if true, pad with zeros (ignored if leftAdjust is true)
}

/// Options for each input file.
struct FileOptions {
    var fieldFormat: FieldFormat? = nil  // if nil, no formatting is applied
    var pad: Bool = false                // if true, when file is exhausted, output an empty formatted field
    var separator: String = ""           // printed immediately before this file’s fragment
    var terminator: Character = "\n"     // character used to split the file into fragments (default newline)
}

/// A “column” associates a filename with its options. The name "-" means standard input.
struct Column {
    let filename: String
    let options: FileOptions
}

/// A structure representing a streaming reader for file fragments.
/// It reads a file handle piecewise until the terminator (given as a single byte) is found.
struct FragmentReader {
    let fileHandle: FileHandle
    let terminator: UInt8
    var buffer = Data()
    let chunkSize = 4096
    var atEOF = false

    init(fileHandle: FileHandle, terminator: Character) {
        self.fileHandle = fileHandle
        self.terminator = terminator.asciiValue ?? 10
    }

    /// Reads the next fragment (up to the terminator) from the file.
    mutating func readFragment() -> String? {
        while true {
            if let pos = buffer.firstIndex(of: terminator) {
                let fragmentData = buffer[..<pos]
                buffer.removeSubrange(..<buffer.index(after: pos))
                return String(data: fragmentData, encoding: .utf8)
            }
            if atEOF {
                if !buffer.isEmpty {
                    let fragmentData = buffer
                    buffer.removeAll()
                    return String(data: fragmentData, encoding: .utf8)
                } else {
                    return nil
                }
            }
            if let data = try? fileHandle.read(upToCount: chunkSize), let data = data, !data.isEmpty {
                buffer.append(data)
            } else {
                atEOF = true
            }
        }
    }
}

/// Associates a Column with its streaming FragmentReader.
struct StreamFileData {
    let column: Column
    var reader: FragmentReader
}

// MARK: - Formatting Helpers

/// Format a fragment string using a FieldFormat: truncate if too long and pad if too short.
func formatFragment(_ fragment: String, using format: FieldFormat) -> String {
    var s = fragment
    if s.count > format.maxWidth {
        s = String(s.prefix(format.maxWidth))
    }
    let paddingNeeded = max(0, format.minWidth - s.count)
    if paddingNeeded > 0 {
        let padChar: Character = (format.padWithZeros && !format.leftAdjust) ? "0" : " "
        let padding = String(repeating: padChar, count: paddingNeeded)
        s = format.leftAdjust ? (s + padding) : (padding + s)
    }
    return s
}

/// Parse a field format string of the form "min.max".
/// If min begins with '-' (left-adjusted) or '0' (pad with zeros), the corresponding flag is set.
func parseFieldFormat(_ token: String) -> FieldFormat? {
    let parts = token.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, let maxWidth = Int(parts[1]) else { return nil }
    
    var minStr = String(parts[0])
    var leftAdjust = false
    var padWithZeros = false
    
    if let first = minStr.first {
        if first == "-" {
            leftAdjust = true
            minStr.removeFirst()
        } else if first == "0" {
            padWithZeros = true
        }
    }
    
    guard let minWidth = Int(minStr) else { return nil }
    
    return FieldFormat(minWidth: minWidth, maxWidth: maxWidth, leftAdjust: leftAdjust, padWithZeros: padWithZeros)
}

// MARK: - Command Line Parsing

/// Processes the command-line arguments and returns an array of Columns along with an optional trailing separator.
func parseArguments() -> (columns: [Column], trailingSeparator: String?) {
    var columns: [Column] = []
    var trailingSeparator: String? = nil
    
    // currentDefaults holds the options for subsequent files.
    var currentDefaults = FileOptions()
    // nextOptions (if non-nil) applies only to the next file operand.
    var nextOptions: FileOptions? = nil
    
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < args.count {
        let arg = args[i]
        if arg.hasPrefix("-") && arg != "-" {
            let optionLetter = arg[arg.index(arg.startIndex, offsetBy: 1)]
            i += 1
            guard i < args.count else {
                fputs("Missing parameter for option \(arg)\n", stderr)
                exit(1)
            }
            let param = args[i]
            switch optionLetter {
            case "f", "F":
                guard let fmt = parseFieldFormat(param) else {
                    fputs("Invalid field format: \(param)\n", stderr)
                    exit(1)
                }
                if optionLetter == "f" {
                    if nextOptions == nil { nextOptions = currentDefaults }
                    nextOptions?.fieldFormat = fmt
                    nextOptions?.pad = false
                } else {
                    currentDefaults.fieldFormat = fmt
                    currentDefaults.pad = false
                    nextOptions = currentDefaults
                }
            case "p", "P":
                guard let fmt = parseFieldFormat(param) else {
                    fputs("Invalid pad format: \(param)\n", stderr)
                    exit(1)
                }
                if optionLetter == "p" {
                    if nextOptions == nil { nextOptions = currentDefaults }
                    nextOptions?.fieldFormat = fmt
                    nextOptions?.pad = true
                } else {
                    currentDefaults.fieldFormat = fmt
                    currentDefaults.pad = true
                    nextOptions = currentDefaults
                }
            case "s", "S":
                if optionLetter == "s" {
                    if nextOptions == nil { nextOptions = currentDefaults }
                    nextOptions?.separator = param
                } else {
                    currentDefaults.separator = param
                    nextOptions = currentDefaults
                }
            case "t", "T":
                guard let termChar = param.first else {
                    fputs("Invalid terminator: \(param)\n", stderr)
                    exit(1)
                }
                if optionLetter == "t" {
                    if nextOptions == nil { nextOptions = currentDefaults }
                    nextOptions?.terminator = termChar
                } else {
                    currentDefaults.terminator = termChar
                    nextOptions = currentDefaults
                }
            default:
                fputs("Unknown option: \(arg)\n", stderr)
                exit(1)
            }
        } else {
            let opts = nextOptions ?? currentDefaults
            columns.append(Column(filename: arg, options: opts))
            nextOptions = nil
        }
        i += 1
    }
    if let pending = nextOptions, pending.separator != "" {
        trailingSeparator = pending.separator
    }
    return (columns, trailingSeparator)
}

// MARK: - Laminating (Streaming Version)

/// Laminates the input files by reading one fragment at a time from each file,
/// assembling the n-th fragments into a single output line.
func laminateStream(columns: [Column], trailingSeparator: String?) {
    var streams: [StreamFileData] = []
    // Open each file (or standard input) and create a FragmentReader.
    for col in columns {
        let fileHandle: FileHandle
        if col.filename == "-" {
            fileHandle = FileHandle.standardInput
        } else {
            do {
                fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: col.filename))
            } catch {
                fputs("Error opening file \(col.filename): \(error)\n", stderr)
                exit(1)
            }
        }
        let reader = FragmentReader(fileHandle: fileHandle, terminator: col.options.terminator)
        streams.append(StreamFileData(column: col, reader: reader))
    }
    
    // Determine whether any file uses a terminator other than newline.
    let omitNewlineOutput = columns.contains { $0.options.terminator != "\n" }
    
    while true {
        var anyRealFragment = false
        var outputLine = ""
        
        // For each file stream, attempt to read the next fragment.
        for i in 0..<streams.count {
            let opts = streams[i].column.options
            var fragment: String? = streams[i].reader.readFragment()
            if let frag = fragment {
                anyRealFragment = true
                outputLine += opts.separator
                if let fmt = opts.fieldFormat {
                    outputLine += formatFragment(frag, using: fmt)
                } else {
                    outputLine += frag
                }
            } else if opts.pad {
                outputLine += opts.separator
                let padded = opts.fieldFormat != nil ? formatFragment("", using: opts.fieldFormat!) : ""
                outputLine += padded
            }
        }
        if !anyRealFragment {
            break
        }
        if let trail = trailingSeparator {
            outputLine += trail
        }
        if omitNewlineOutput {
            if let data = outputLine.data(using: .utf8) {
                FileHandle.standardOutput.write(data)
            }
        } else {
            print(outputLine)
        }
    }
    
    // Close all file handles except standard input.
    for stream in streams where stream.column.filename != "-" {
        try? stream.reader.fileHandle.close()
    }
}

// MARK: - Main Entry Point

@main
struct Lam {
    static func main() {
        let (columns, trailingSeparator) = parseArguments()
        if columns.isEmpty {
            fputs("Usage: lam [options] file ...\n", stderr)
            exit(1)
        }
        laminateStream(columns: columns, trailingSeparator: trailingSeparator)
    }
}
