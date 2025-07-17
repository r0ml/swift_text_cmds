// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import CMigration

import errno_h
import Darwin

public func encodeLatin1Lossy(_ string: String) -> [UInt8] {
    string.unicodeScalars.map { scalar in
        scalar.value <= 0xFF ? UInt8(scalar.value) : UInt8(ascii: "?")
    }
}

/// Converts a BRE pattern string to an ERE-compatible pattern string.
public func convertBREtoERE(_ bre: String) -> String {
    var result = ""
    let chars = Array(bre)
    var i = 0

    while i < chars.count {
        let c = chars[i]

        if c == "\\" && i + 1 < chars.count {
            let next = chars[i + 1]
            switch next {
            case "(", ")", "{", "}", "+", "?", "|":
                result.append(next) // Escaped group/quantifier → remove \
                i += 2
            case "\\":
                result.append("\\") // Escaped backslash
                i += 2
            default:
                result.append("\\")
                result.append(next)
                i += 2
            }
        } else {
            switch c {
            case // "(", ")", "{", "}":
                "(", ")", "{", "}", "+", "?", "|":
                result.append("\\") // Literal parens → escape them
                result.append(c)
            default:
                result.append(c)
            }
            i += 1
        }
    }

    return result
}

/// Memory-maps a file read-only and returns its contents as an `UnsafeRawBufferPointer`.
public func mmapFileReadOnly(_ fd: FileDescriptor) throws -> UnsafeRawBufferPointer {
    // Get file size
  var statBuf = Darwin.stat()
  let statResult = Darwin.fstat(fd.rawValue, &statBuf)

    if statResult != 0 {
        try? fd.close()
        throw Errno(rawValue: errno)
    }

    let size = Int(statBuf.st_size)
    guard size > 0 else {
        try? fd.close()
        throw Errno.invalidArgument
    }

    // Map file into memory
    let addr = mmap(nil, size, PROT_READ, MAP_PRIVATE | MAP_NOCACHE, fd.rawValue, 0)
    try fd.close() // Safe to close after mmap

    guard addr != MAP_FAILED else {
        throw Errno(rawValue: errno)
    }

    return UnsafeRawBufferPointer(start: addr, count: size)
}


public extension Array where Element: Equatable {
    /// Returns the first index of the subarray within the specified range, or `nil` if not found.
    func firstIndex(of subarray: [Element], in range: Range<Int>) -> Int? {
        guard !subarray.isEmpty else { return range.lowerBound }
        guard subarray.count <= self.count else { return nil }
        
        let upperLimit = Swift.min(self.count - subarray.count, range.upperBound - subarray.count)
        
        for i in range.lowerBound...upperLimit {
            if self[i..<i + subarray.count].elementsEqual(subarray) {
                return i
            }
        }
        return nil
    }
}

public extension UnsafeRawBufferPointer {
  func firstIndex(of: [UInt8], in searchRange: Range<Int>? = nil) -> Int? {
    let start = searchRange?.lowerBound ?? 0
    let end = Swift.min(searchRange?.upperBound ?? self.count, self.count)
    guard 1 <= end - start else { return nil }
    for i in start..<end {
      for j in 0..<of.count {
        if self[i+j] != of[j] {
          break
        }
        return i
      }
    }
    return nil
  }
}

