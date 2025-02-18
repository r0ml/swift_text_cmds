
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
  var rflag = false // Reverse flag, to be set based on user input
  
  /// Reads `off` bytes from the end of the file and displays them.
  func bytes(fp: UnsafeMutablePointer<FILE>, filename: String, offset: Int) -> Int {
    var buffer = [UInt8](repeating: 0, count: offset)
    var wrap = false
    var index = 0
    
    while true {
      let ch = fgetc(fp)
      if ch == EOF { break }
      
      buffer[index] = UInt8(ch)
      index += 1
      
      if index == offset {
        wrap = true
        index = 0
      }
    }
    
    if ferror(fp) != 0 {
      perror("Error reading file: \(filename)")
      return 1
    }
    
    if rflag {
      var length = 0
      var tlen = 0
      
      for i in stride(from: index - 1, through: 0, by: -1) {
        if buffer[i] == UInt8(ascii: "\n"), length > 0 {
          print(String(bytes: buffer[i+1..<i+1+length], encoding: .utf8) ?? "", terminator: "")
          length = 0
        } else {
          length += 1
        }
      }
      
      if wrap {
        tlen = length
        for i in stride(from: offset - 1, through: index, by: -1) {
          if buffer[i] == UInt8(ascii: "\n") {
            if length > 0 {
              print(String(bytes: buffer[i+1..<i+1+length], encoding: .utf8) ?? "", terminator: "")
              length = 0
            }
            if tlen > 0 {
              print(String(bytes: buffer[0..<tlen], encoding: .utf8) ?? "", terminator: "")
              tlen = 0
            }
          } else {
            length += 1
          }
        }
        if length > 0 {
          print(String(bytes: buffer[index..<index+length], encoding: .utf8) ?? "", terminator: "")
        }
        if tlen > 0 {
          print(String(bytes: buffer[0..<tlen], encoding: .utf8) ?? "", terminator: "")
        }
      }
    } else {
      if wrap, index < offset {
        print(String(bytes: buffer[index..<offset], encoding: .utf8) ?? "", terminator: "")
      }
      if index > 0 {
        print(String(bytes: buffer[0..<index], encoding: .utf8) ?? "", terminator: "")
      }
    }
    
    return 0
  }
  
  /// Reads `off` lines from the end of the file and displays them.
  func lines(fp: UnsafeMutablePointer<FILE>, filename: String, offset: Int) -> Int {
    var lines = [(data: [UInt8], length: Int)](repeating: ([], 0), count: offset)
    var buffer = [UInt8]()
    var wrap = false
    var recno = 0
    var charCount = 0
    
    while true {
      let ch = fgetc(fp)
      if ch == EOF { break }
      
      buffer.append(UInt8(ch))
      charCount += 1
      
      if ch == Int32(UnicodeScalar("\n").value) {
        if lines[recno].length < charCount {
          lines[recno] = (buffer, charCount)
        }
        buffer.removeAll()
        charCount = 0
        
        recno += 1
        if recno == offset {
          wrap = true
          recno = 0
        }
      }
    }
    
    if ferror(fp) != 0 {
      perror("Error reading file: \(filename)")
      return 1
    }
    
    if charCount > 0 {
      lines[recno] = (buffer, charCount)
      recno += 1
      if recno == offset {
        wrap = true
        recno = 0
      }
    }
    
    if rflag {
      for i in stride(from: recno - 1, through: 0, by: -1) {
        if lines[i].length > 0 {
          print(String(bytes: lines[i].data, encoding: .utf8) ?? "", terminator: "")
        }
      }
      if wrap {
        for i in stride(from: offset - 1, through: recno, by: -1) {
          if lines[i].length > 0 {
            print(String(bytes: lines[i].data, encoding: .utf8) ?? "", terminator: "")
          }
        }
      }
    } else {
      if wrap {
        for i in recno..<offset {
          if lines[i].length > 0 {
            print(String(bytes: lines[i].data, encoding: .utf8) ?? "", terminator: "")
          }
        }
      }
      for i in 0..<recno {
        if lines[i].length > 0 {
          print(String(bytes: lines[i].data, encoding: .utf8) ?? "", terminator: "")
        }
      }
    }
    
    return 0
  }
}
