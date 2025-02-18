
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025 using ChatGPT
// from a file with the following notice:

/*
Copyright (c) 1991, 1993
The Regents of the University of California.  All rights reserved.

This code is derived from software contributed to Berkeley by
Edward Sze-Tyan Wang.

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

extension tail {
  // Buffer size constant (adjust based on system needs)
  let BSZ = 8192
  
  // Struct representing an element in the buffer list
  class BufferElement {
    var data: [UInt8]
    var length: Int
    var next: BufferElement?
    var prev: BufferElement?
    
    init(size: Int) {
      self.data = [UInt8](repeating: 0, count: size)
      self.length = 0
    }
  }
  
  // Function to read a file into memory and print it in reverse order
  func r_buf(fp: UnsafeMutablePointer<FILE>, filename: String) {
    var head: BufferElement? = nil
    var tail: BufferElement? = nil
    var enomem: Int64 = 0
    
    // Read data into linked list buffers
    while !feof(fp) {
      // Try to allocate a new buffer block
      var newElement: BufferElement? = BufferElement(size: BSZ)
      
      // If out of memory, remove the oldest (least recently used) block
      if newElement == nil {
        if let first = head {
          enomem += Int64(first.length)
          head = first.next
          head?.prev = nil
        }
      }
      
      guard let buffer = newElement else {
        fatalError("Failed to allocate memory")
      }
      
      // Insert the new element at the end of the linked list
      if tail == nil {
        head = buffer
      } else {
        tail?.next = buffer
        buffer.prev = tail
      }
      tail = buffer
      
      // Read data into the buffer
      var bytesRead: Int = 0
      while (feof(fp) == 0) && bytesRead < BSZ {
        let count = fread(&buffer.data + bytesRead, 1, BSZ - bytesRead, fp)
        bytesRead += count
        
        if ferror(fp) != 0 {
          perror("Error reading file: \(filename)")
          return
        }
      }
      
      buffer.length = bytesRead
    }
    
    // If memory was discarded, show a warning
    if enomem > 0 {
      print("Warning: \(enomem) bytes discarded")
    }
    
    // Print the buffers in reverse order
    var current = tail
    
    while let element = current {
      var lineLength = 0
      var dataPointer = element.data[0..<element.length]
      
      for index in stride(from: element.length - 1, through: 0, by: -1) {
        let isStart = (element === head && index == 0)
        
        if dataPointer[index] == UInt8(ascii: "\n") || isStart {
          let startIdx = isStart ? index : index + 1
          let chunk = dataPointer[startIdx..<(startIdx + lineLength)]
          
          if lineLength > 0 {
            if let line = String(bytes: chunk, encoding: .utf8) {
              print(line, terminator: "")
            }
            if isStart && dataPointer[index] == UInt8(ascii: "\n") {
              print("\n", terminator: "")
            }
          }
          
          var temp = element.next
          while let nextElement = temp {
            if nextElement.length > 0 {
              let chunk = nextElement.data[0..<nextElement.length]
              if let line = String(bytes: chunk, encoding: .utf8) {
                print(line, terminator: "")
              }
            }
            temp = nextElement.next
          }
          lineLength = 0
        } else {
          lineLength += 1
        }
      }
      element.length = lineLength
      current = element.prev
    }
  }
}
