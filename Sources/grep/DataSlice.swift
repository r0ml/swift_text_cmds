// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation

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
