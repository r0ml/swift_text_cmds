
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-2-Clause
 
  Copyright (c) 2020 Baptiste Daroussin <bapt@FreeBSD.org>
 
  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
 
  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */

import Foundation
import Shared

extension bintrans {
  
  func hexval(_ c : Character) -> Int {
    let x = Array("0123456789ABCDEF")
    return x.firstIndex(of: c.uppercased().first!)!
  }
  
  func decode_char(_ s : Substring) -> UInt8 {
    let a = s.prefix(2).uppercased()
    return UInt8(16 * hexval(a.first!) + hexval(a.last!))
  }
  
  
  func decode_quoted_printable(_ bodyx : String, _ fpo : FileHandle) {
    var body = Substring(bodyx)
    while !body.isEmpty {
      let c = body.removeFirst()
      switch c {
        case "=":
          if body.count < 1 {
            fpo.write(String(c) )
          } else
          if body.prefix(2) == "\r\n" {
            body = body.dropFirst(2)
            break
          } else if body.first == "\n" {
            body = body.dropFirst()
            break;
          } else if body.first == "\r" {
            body = body.dropFirst()
            fpo.write("=\r\n")
//          } else if body.first == "\r" {
//            fpo.write("=\r\n")
//            body = body.dropFirst()
//          } else if body.isEmpty {
//            fpo.write("=")
          } else if !"0123456789ABCDEFabcdef".contains(body.first!) {
            fpo.write(String(c))
          } else if !"0123456789ABCDEFabcdef".contains(body.dropFirst().first!) {
            fpo.write(String(c))
          } else {
            let d = decode_char(body)
            body = body.dropFirst(2)
            fpo.write(Data([d]))
          }
        default:
          fpo.write(String(c))
      }
    }
 //   fpo.write("\n")
  }
  
  func hexstring( _ c : UInt8) -> String {
    let x = Array("0123456789ABCDEF")
    let a = x[ Int(c >> 4) ]
    let b = x[ Int(c & 0x0f) ]
    return String([a,b])
  }
                  
  func encode_quoted_printable(_ bodyx : String, _ fpo : FileHandle) {

    var prev = "\0".first!
    var linelen = 0
    var body = Substring(bodyx)
    while !body.isEmpty {
      let c = body.removeFirst()
      if linelen == 75 {
        fpo.write("=\r\n")
        linelen = 0
      }
      let cc = c.unicodeScalars.first!.value
      if (cc >= 128 ||
          c == "=" ||
          (c == "." && (body.first == "\n" || body.first == "\r"))) {
        let uu = c.utf8
        for u in uu {
          let k = hexstring(u.magnitude)
          fpo.write("="+k)
          linelen += 3
        }
        linelen -= 1
        prev = c
      } else if (cc < 33 && c != "\n") {
        if ((c == " " || c == "\t") &&
            body.count > 0 &&
            (body.first != "\n" && body.first !=
             "\r")) {
          fpo.write(String(c))
          prev = c
        } else {
          let uu = c.utf8
          for u in uu {
            let k = hexstring(u.magnitude)
            fpo.write( "=" + k)
            linelen += 2
          }
          linelen -= 1
          prev = "_"
        }
      } else if c == "\n" {
        if prev == " " || prev == "\t" {
          fpo.write("=")
        }
        fpo.write("\n")
        linelen = 0
        prev = "\0".first!
      } else {
        fpo.write(String(c))
        prev = c
      }
      linelen += 1
    }
  }
  
  func qp(_ fp : FileHandle, _ fpo : FileHandle, _ encode : Bool) async throws(CmdErr)   {
    let codec = encode ? encode_quoted_printable : decode_quoted_printable
    
    do {
      for try await line in fp.bytes.linesNL() {
        // (getline(&line, &linecap, fp) > 0)
        codec(line, fpo);
      }
    } catch(let e) {
      throw CmdErr(1, "\(e.localizedDescription)")
    }
  }
  
  var qp_usage : String {
    "usage: bintrans qp [-u] [-o outputfile] [file name]"
  }
  
  func parseOptions_quotedprintable(_ options : inout CommandOptions, _ bintflag : Bool) throws(CmdErr) {
  
    let go = BSDGetopt("o:u", args: CommandLine.arguments.dropFirst(bintflag ? 2 : 1))
    
    options.encode = true
    
    while let (k,v) = try go.getopt() {
      switch k {
        case "o":
          options.outFile = v
        case "u":
          options.encode = false
        default:
          throw CmdErr(1, qp_usage)
      }
    }
    
    options.args = go.remaining
    options.inFile = options.args.last
  }
  
  func main_quotedprintable(_ options : CommandOptions) async throws(CmdErr) {
    var fp = FileHandle.standardInput
    if let inf = options.inFile {
      do {
        fp = try FileHandle(forReadingFrom: URL(filePath: inf, directoryHint: .notDirectory))
      } catch(let e) {
        throw CmdErr(1, "unable to open \(inf) for input: \(e.localizedDescription)")
      }
    }
    
    var fpo = FileHandle.standardOutput
    if let outf = options.outFile {
      do {
        fpo = try FileHandle(forWritingTo: URL(filePath: outf, directoryHint: .notDirectory))
      } catch(let e) {
        throw CmdErr(1,"unable to open \(outf) for output: \(e.localizedDescription)")
      }
    }
    
    try await qp(fp, fpo, options.encode);
  }
}


extension FileHandle.AsyncBytes {
    /// Asynchronously reads lines from the `AsyncBytes` stream.
    func linesNL() -> AsyncLineSequence {
        return AsyncLineSequence(asyncBytes: self)
    }

    struct AsyncLineSequence: AsyncSequence {
        typealias Element = String
        typealias AsyncIterator = AsyncLineIterator
        
        private let asyncBytes: FileHandle.AsyncBytes
        
        init(asyncBytes: FileHandle.AsyncBytes) {
            self.asyncBytes = asyncBytes
        }
        
        func makeAsyncIterator() -> AsyncLineIterator {
            return AsyncLineIterator(asyncBytes: asyncBytes.makeAsyncIterator())
        }
    }

    struct AsyncLineIterator: AsyncIteratorProtocol {
        typealias Element = String
        
        private var asyncBytes: FileHandle.AsyncBytes.Iterator
        private var buffer: Data = Data()
        
        init(asyncBytes: FileHandle.AsyncBytes.Iterator) {
            self.asyncBytes = asyncBytes
        }
        
        mutating func next() async throws -> String? {
            while let byte = try await asyncBytes.next() {
                buffer.append(byte)
                
                // Check for newline (\n)
                if let range = buffer.range(of: Data([0x0A])) { // '\n'
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.endIndex)
                    buffer.removeSubrange(buffer.startIndex..<range.endIndex)
                    return String(data: lineData, encoding: .utf8)
                }
              /*else if let range = buffer.range(of: Data([0x0D, 0x0A])) { // '\r\n'
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.startIndex)
                    buffer.removeSubrange(buffer.startIndex...range.endIndex - 1)
                    return String(data: lineData, encoding: .utf8)
                }
               */
            }
            
            // If we reach the end of the stream and still have data in the buffer
            if !buffer.isEmpty {
                let line = String(data: buffer, encoding: .utf8)
                buffer.removeAll()
                return line
            }
            
            // End of stream
            return nil
        }
    }
}
