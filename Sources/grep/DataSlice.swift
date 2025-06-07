// Created by ChatGPT
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import CMigration

/*
class DataSlice {
    private let originalData: Data
    private let range: Range<Int>
    
    /// Initialize with the original `Data` and a range
    init?(data: Data, range: Range<Int>) {
        guard range.lowerBound >= 0,
              range.upperBound <= data.count,
              range.lowerBound < range.upperBound else {
            return nil // Return nil if the range is invalid
        }
        self.originalData = data
        self.range = range
    }
  
  init(data: Data) {
    self.originalData = data
    self.range = 0..<data.count
  }
    
    /// Get the byte at a specific index within the slice
    func byte(at index: Int) -> UInt8? {
        let actualIndex = range.lowerBound + index
        guard range.contains(actualIndex) else { return nil }
        return originalData[actualIndex]
    }
    
    /// Get the size of the slice
    var count: Int {
        return range.count
    }
    
    /// Access the slice as a `Data`
    var data: Data {
        return originalData.subdata(in: range)
    }
    
    /// Access the bytes of the slice
    var bytes: [UInt8] {
        return Array(originalData[range])
    }
}
*/


public final class ByteBuffer: Collection {
    public typealias Index = Int
    public typealias Element = UInt8

    public enum Storage {
        case owned([UInt8])
        case mmaped(ptr: UnsafeRawPointer, count: Int)
        case slice(base: ByteBuffer, offset: Int, count: Int)
    }

    private let storage: Storage

    public var count: Int {
        switch storage {
        case .owned(let array): return array.count
        case .mmaped(_, let count): return count
        case .slice(_, _, let count): return count
        }
    }

    public var buffer: UnsafeRawBufferPointer {
        switch storage {
        case .owned(let array):
            return array.withUnsafeBytes { buffer in
                UnsafeRawBufferPointer(buffer)
            }
        case .mmaped(let ptr, let count):
            return UnsafeRawBufferPointer(start: ptr, count: count)
        case .slice(let base, let offset, let count):
            return UnsafeRawBufferPointer(
                start: base.buffer.baseAddress!.advanced(by: offset),
                count: count
            )
        }
    }

    /// MARK: - Collection conformance

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

  public func index(after i: Int) -> Int {
      i + 1
  }
  
    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < count, "Index out of bounds")
        return buffer[index]
    }

    /// Slice support: returns a ByteBuffer slice for a range
    public subscript(bounds: Range<Int>) -> ByteBuffer {
        slice(bounds)
    }

    /// Create from `[UInt8]` (copy)
    public init(copy bytes: [UInt8]) {
        self.storage = .owned(bytes)
    }

    /// Create from a memory-mapped file (read-only)
    public init(mmap path: FilePath) throws {
        let fd = try FileDescriptor.open(path, .readOnly)

        var sb = stat()
        let statResult = path.string.withCString { cStr in
            stat(cStr, &sb)
        }
        guard statResult == 0 else {
            try? fd.close()
            throw Errno(rawValue: errno)
        }

        let size = Int(sb.st_size)
        guard size > 0 else {
            try? fd.close()
            throw Errno.invalidArgument
        }

      if let addr = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd.rawValue, 0) {
        try fd.close()
        
        guard addr != MAP_FAILED else {
          throw Errno(rawValue: errno)
        }
        
        self.storage = .mmaped(ptr: UnsafeRawPointer(addr), count: size)
      } else {
        throw Errno(rawValue: errno)
      }
    }

    /// Create a view (slice) of the buffer
    public func slice(_ range: Range<Int>) -> ByteBuffer {
        precondition(range.lowerBound >= 0 && range.upperBound <= self.count, "Range out of bounds")
        return ByteBuffer(base: self, offset: range.lowerBound, count: range.count)
    }

    // Private initializer for slicing
    private init(base: ByteBuffer, offset: Int, count: Int) {
        self.storage = .slice(base: base, offset: offset, count: count)
    }

    deinit {
        if case let .mmaped(ptr, count) = storage {
            munmap(UnsafeMutableRawPointer(mutating: ptr), count)
        }
    }
}
