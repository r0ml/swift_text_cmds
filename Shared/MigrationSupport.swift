/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation

public protocol ShellCommand {
  associatedtype CommandOptions
  func parseOptions() throws(CmdErr) -> CommandOptions
  func runCommand(_ options : CommandOptions) async throws(CmdErr)
  var usage : String { get }
  init()
}

extension ShellCommand {

  public static func main() async {
    let z = await Self().main()
    exit(z)
  }
  
  public func main() async -> Int32 {
    var options : CommandOptions
    do {
      options = try parseOptions()
    } catch(let e) {
      var fh = FileHandle.standardError
      if (!e.message.isEmpty) { print("\(e.message)", to: &fh) }
      print(usage, to: &fh)
      return Int32(e.code)
    }
    
    do {
      try await runCommand(options)
      return 0
    } catch(let e) {
      var fh = FileHandle.standardError
      if (!e.message.isEmpty) { print("\(String(cString: getprogname()!)): \(e.message)", to: &fh) }
      return Int32(e.code)
    }
  }

}

// this is a bug for ARM, but works on Intel
/*
func err_s(_ a : Int, b : String, c : String) {
  fputs(b, stderr)
  c.withCString { m in
    withVaList([m]) {
      verr(Int32(a), b, $0)
    }
  }
}
*/

public func errx(_ a : Int, _ b : String) {
  fputs(basename(CommandLine.unsafeArgv[0]), stderr)
  fputs(": \(b)\n", stderr)
  exit(Int32(a))
}

public func err(_ a : Int, _ b : String?) {
  let e = String(cString: strerror(errno))
  if let b {
    fputs("\(b): \(e)\n", stderr)
  } else {
    fputs("\(e)\n", stderr)
  }
  exit(Int32(a))
}

public func warnx(_ b : String) {
  fputs(basename(CommandLine.unsafeArgv[0]), stderr)
  fputs(": \(b)\n", stderr)
}

public func warn(_ b : String) {
  let e = String(cString: strerror(errno))
  fputs(basename(CommandLine.unsafeArgv[0]), stderr)
  fputs(": \(b): \(e)\n", stderr)
}

public func warnc(_ cod : Int32, _ b : String) {
  let e = String(cString: strerror(cod))
  fputs(basename(CommandLine.unsafeArgv[0]), stderr)
  fputs(": \(b): \(e)\n", stderr)
}

extension Character {
  public static func from(_ c : Int8?) -> Character? {
    guard let c else { return nil }
    return Character(UnicodeScalar(UInt8(c)))
  }

  public static func from(_ c : UInt8?) -> Character? {
    guard let c else { return nil }
    return Character(UnicodeScalar(c))
  }

  
}


#if swift(>=6.0)

 extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
      let data = Data(string.utf8)
      self.write(data)
    }
  }
#else
  extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
      let data = Data(string.utf8)
      self.write(data)
    }
  }
#endif


public func WEXITSTATUS(_ x : Int32) -> Int32 { return (x >> 8) & 0x0ff }
public func WIFEXITED(_ x : Int32) -> Bool { return (x & 0x7f) == 0 }
public func WIFSIGNALED(_ x : Int32) -> Bool {
  let y = x & 0x7f
  return y != _WSTOPPED && y != 0
}

// ============================

// Find the executable in the path

public func S_ISREG(_ m : mode_t) -> Bool {
  return (m & S_IFMT) == S_IFREG
}
public func S_ISDIR(_ m : mode_t) -> Bool {
  return (m & S_IFMT) == S_IFDIR     /* directory */
}

public func S_ISCHR(_ m : mode_t) -> Bool {
  return (m & S_IFMT) == S_IFCHR     /* char special */
}


public func isThere(candidate: String) -> Bool {
  var fin = stat()
  
  return access(candidate, X_OK) == 0 && stat(candidate, &fin) == 0 && S_ISREG(fin.st_mode) && (getuid() != 0 || (fin.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH)) != 0)
}

public func searchPath(for filename: String) -> String? {
  var candidate = ""
  
  let path = ProcessInfo.processInfo.environment["PATH"] ?? _PATH_DEFPATH //   "/usr/bin:/bin"
  
  if filename.contains("/") {
    return filename
  }
  
  for dx in path.split(separator: ":") {
    let d = dx.isEmpty ? "." : dx
    candidate = "\(d)/\(filename)"
    if candidate.count >= PATH_MAX {
      continue
    }
    if isThere(candidate: candidate) {
      return candidate
    }
  }
  return nil
}


extension UnsafeMutablePointer<stat> {
 public var st_ctime : Int { pointee.st_ctimespec.tv_sec }
 public var st_mtime : Int { pointee.st_mtimespec.tv_sec }
 public var st_atime : Int { pointee.st_atimespec.tv_sec }
 public var st_birthtime : Int { pointee.st_birthtimespec.tv_sec }
    
 public var st_ctim : timespec { pointee.st_ctimespec }
 public var st_mtim : timespec { pointee.st_mtimespec }
 public var st_atim : timespec { pointee.st_atimespec }
 public var st_birthtim : timespec { pointee.st_birthtimespec }
}

extension stat {
  public var st_ctime : Int { st_ctimespec.tv_sec }
  public var st_mtime : Int { st_mtimespec.tv_sec }
  public var st_atime : Int { st_atimespec.tv_sec }
  public var st_birthtime : Int { st_birthtimespec.tv_sec }
  
 public var st_ctim : timespec { st_ctimespec }
 public var st_mtim : timespec { st_mtimespec }
 public var st_atim : timespec { st_atimespec }
 public var st_birthtim : timespec { st_birthtimespec }
}


extension FileHandle.AsyncBytes {
    /// Asynchronously reads lines from the `AsyncBytes` stream.
  public var linesNL : AsyncLineSequence {
        return AsyncLineSequence(asyncBytes: self)
    }

    public struct AsyncLineSequence: AsyncSequence {
        public typealias Element = String
        public typealias AsyncIterator = AsyncLineIterator
        
        private let asyncBytes: FileHandle.AsyncBytes
        
        init(asyncBytes: FileHandle.AsyncBytes) {
            self.asyncBytes = asyncBytes
        }
        
      public func makeAsyncIterator() -> AsyncLineIterator {
            return AsyncLineIterator(asyncBytes: asyncBytes.makeAsyncIterator())
        }
    }

    public struct AsyncLineIterator: AsyncIteratorProtocol {
        public typealias Element = String
        
        private var asyncBytes: FileHandle.AsyncBytes.Iterator
        private var buffer: Data = Data()
        
        init(asyncBytes: FileHandle.AsyncBytes.Iterator) {
            self.asyncBytes = asyncBytes
        }
        
      mutating public func next() async throws -> String? {
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

enum StringEncodingError : Error {
  case invalidCharacter
}

extension StringProtocol {
  public func wcwidth() -> Int {
    let s = self.unicodeScalars
    return s.reduce(0) { sum, scal in
      let t = Darwin.wcwidth(Int32(scal.value))
      if t > 0 { return sum + Int(t) }
      else { return sum }
    }
  }
}
