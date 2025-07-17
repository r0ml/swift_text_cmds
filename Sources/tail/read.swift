
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


import CMigration

extension tail {
  
  /*
   * bytes -- read bytes to an offset from the end and display.
   *
   * This is the function that reads to a byte offset from the end of the input,
   * storing the data in a wrap-around buffer which is then displayed.  If the
   * rflag is set, the data is displayed in lines in reverse order, and this
   * routine has the usual nastiness of trying to find the newlines.  Otherwise,
   * it is displayed from the character closest to the beginning of the input to
   * the end.
   */
  func bytes(_ fp: FileDescriptor, _ filename: String, _ off : Int64) throws {
//    fatalError("not yet implemented")
    /*
    var wrap = false
    var index = 0
    
    var buffer = Data()
*/
    var prev = [UInt8]()
    while true {
      let k = try fp.readUpToCount(Int(off))
      if k.count + prev.count < off {
        prev = prev + k
      } else {
        prev = prev[(prev.count - (Int(off) - k.count))...] + k
      }
      if k.count == 0 { break }
    }

    // now prev has the last n bytes
    var kk = Array(prev.split(separator: 10, omittingEmptySubsequences: false).reversed())
    if kk.first?.isEmpty == true { kk.removeFirst() }
    for j in kk {
      if let m = String(validating: j, as: UTF8.self) {
        print(m)
      } else {
        print(String(decoding: j, as: ISOLatin1.self))
      }
    }

/*
    while true {
      guard let ch = try fp.read(upToCount: 1) else { break }
      
      buffer.append(ch)
      index += 1
      
      if index == options.off {
        wrap = true
        index = 0
      }
    }
    
    if options.rflag {
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
     */
  }
  
  /*
   * lines -- read lines to an offset from the end and display.
   *
   * This is the function that reads to a line offset from the end of the input,
   * storing the data in an array of buffers which is then displayed.  If the
   * rflag is set, the data is displayed in lines in reverse order, and this
   * routine has the usual nastiness of trying to find the newlines.  Otherwise,
   * it is displayed from the line closest to the beginning of the input to
   * the end.
   */
  func lines(_ fp : FileDescriptor, _ filename: String, _ options : CommandOptions) async throws {
    
//    fatalError("not yet implemented")
    
    var llines = [String]()
    for try await line in fp.bytes.lines {
      llines.append(line)
      if llines.count > Int(options.off) {
        llines.remove(at: 0)
      }
    }
    
    if options.rflag {
      for line in llines.reversed() {
         print(line)
      }
    } else {
      for line in llines {
        print(line)
      }
    }
  }
}
