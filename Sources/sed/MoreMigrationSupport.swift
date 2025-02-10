// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation


extension FileHandle.AsyncBytes {
  /// Asynchronously reads lines from the `AsyncBytes` stream.
  public var linesNLX : AsyncLineSequenceX<FileHandle.AsyncBytes> {
    return AsyncLineSequenceX(self)
  }
  
}
/// A reimplementation of Swifts AsyncLineSequence in order to support legacy C command semantics.
/// These include:
///     - including the newline character as part of the result (to distinguish end-of-file-with-no-eol situations
///     - supporting different encodings (other than UTF-8)
///     - supporting different line endings
public struct AsyncLineSequenceX<Base>: AsyncSequence
where Base: AsyncSequence, Base.Element == UInt8 {
  
  /// The type of element produced by this asynchronous sequence.
  public typealias Element = String
  
  /// The type of asynchronous iterator that produces elements of this
  /// asynchronous sequence.
  public struct AsyncIterator: AsyncIteratorProtocol {
    public typealias Element = String
    
    var _base: Base.AsyncIterator
    var _peek: UInt8?
    var encoding : String.Encoding = .utf8
    
    public init(_ base : Base.AsyncIterator, encoding : String.Encoding = .utf8) {
      self._base = base
      self._peek = nil
    }
    
    /// Asynchronously advances to the next element and returns it, or ends
    /// the sequence if there is no next element.
    ///
    /// - Returns: The next element, if it exists, or `nil` to signal the
    ///            end of the sequence.
    public mutating func next() async rethrows -> Element? {
      var _buffer = [UInt8]()
      
      func nextByte() async throws -> UInt8? {
        if let peek = self._peek {
          self._peek = nil
          return peek
        }
        return try await self._base.next()
      }
      
      loop: while let first = try await nextByte() {
        switch first {
          case 0x0A:
            _buffer.append(first)
            break loop
          default:
            _buffer.append(first)
        }
      }
      // Don't return an empty line when at end of file
      if !_buffer.isEmpty {
        return String(bytes: _buffer, encoding: self.encoding)
        //              return _buffer
      } else {
        return nil
      }
    }
    
  }
  
  let base: Base
  let encoding : String.Encoding
  
  public init(_ base: Base, encoding: String.Encoding = .utf8) {
    self.base = base
    self.encoding = encoding
  }
  
  /// Creates the asynchronous iterator that produces elements of this
  /// asynchronous sequence.
  ///
  /// - Returns: An instance of the `AsyncIterator` type used to produce
  ///            elements of the asynchronous sequence.
  public func makeAsyncIterator() -> AsyncIterator {
    return AsyncIterator(self.base.makeAsyncIterator(), encoding: encoding)
  }
}

func regerror(_ n : Int32, _ regx : regex_t )  -> String {
  var re = regx
  let s = withUnsafeMutablePointer(to: &re) { rr in
     regerror(n, rr, nil, 0)
  }
  
  var p = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: s) { b in
    withUnsafeMutablePointer(to: &re) {rr in
      let j = regerror(n, rr, b.baseAddress!, s)
      return String(cString: b.baseAddress!)
    }
  }
  return p
}
