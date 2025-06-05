
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
   * reverse -- display input in reverse order by line.
   *
   * There are six separate cases for this -- regular and non-regular
   * files by bytes, lines or the whole file.
   *
   * BYTES  display N bytes
   *  REG  mmap the file and display the lines
   *  NOREG  cyclically read characters into a wrap-around buffer
   *
   * LINES  display N lines
   *  REG  mmap the file and display the lines
   *  NOREG  cyclically read lines into a wrap-around array of buffers
   *
   * FILE    display the entire file
   *  REG  mmap the file and display the lines
   *  NOREG  cyclically read input into a linked list of buffers
   */
  func reverse(_ fp : FileDescriptor, _ fn : String, _ options : CommandOptions) async throws {
    if (options.style != .REVERSE && options.off == 0) {
      return;
    }

    if fp.isRegularFile {
      try r_reg(fp, fn, options)
    }  else {
      let off = options.off
      switch options.style {
        case .FBYTES, .RBYTES:
          try bytes(fp, fn, off);
        case .FLINES, .RLINES:
          try await lines(fp, fn, options)
        case .REVERSE:
          try await r_buf(fp, fn);
        default:
          break
      }
    }
  }
  
  struct mapinfo {
    var mapoff: off_t
    var maxoff : off_t
    var maplen : size_t
    var start : UnsafePointer<UInt8>?
    var fd : Int32
  };

  /*
   * r_reg -- display a regular file in reverse order by line.
   */
  func r_reg(_ fp : FileDescriptor, _ fn : String, _ options : CommandOptions) throws {

    let k = try mmapFileReadOnly(at: FilePath(fn))
    
    var curoff = k.endIndex-1
    var off = options.off
    
    while curoff >= k.startIndex {
      if let t = k.lastIndex(of: 10, before: curoff) {
        let l = k[t.advanced(by: 1)..<curoff]
        // try FileDescriptor.standardOutput.write(contentsOf: l)
        print( String(decoding: l, as: UTF8.self) )
        curoff = t
        
        if (options.style == .RLINES) {
          off-=1
        }
        
        if (off == 0 && options.style != .REVERSE) {
          /* Avoid printing anything below. */
          curoff = 0;
          break;
        }

        
        
      } else {
        let l = k[k.startIndex..<curoff]
        print( String(decoding: l, as: UTF8.self) )
        break
      }
    }
    
    let size = try fp.seek(offset: 0, from: .end)
    if 0 == size {
      return
    }

    /*
    
    let map = mapinfo(mapoff: off_t(size), maxoff: off_t(size), maplen: 0, start : nil, fd : fp.fileDescriptor)

    /*
     * Last char is special, ignore whether newline or not. Note that
     * size == 0 is dealt with above, and size == 1 sets curoff to -1.
     */
    var curoff = size - 2
    var lineend = size
    var off = options.off
    
    while (curoff >= 0) {
      if (curoff < map.mapoff ||
          curoff >= (map.mapoff + Int64(map.maplen))) {
        if (maparound(&map, curoff) != 0) {
          ierr(fn);
          return;
        }
      }
      var i = Int64(curoff) - map.mapoff
      while i >= 0 {
        if (options.style == .RBYTES && off == 0) {
          break;
        }
        off -= 1
        if (map.start![Int(i)] == "\n".first!.asciiValue!) {
          break;
        }
        i -= 1
      }
      /* `i' is either the map offset of a '\n', or -1. */
      curoff = UInt64(map.mapoff + i);
      if (i < 0) {
        continue;
      }

      /* Print the line and update offsets. */
      if (mapprint(&map, curoff + 1, lineend - curoff - 1) != 0) {
        ierr(fn);
        return;
      }
      lineend = curoff + 1;
      curoff -= 1

      if (options.style == .RLINES) {
        off-=1
      }

      if (off == 0 && options.style != .REVERSE) {
        /* Avoid printing anything below. */
        curoff = 0
        break
      }
    }
    if (curoff < 0 && mapprint(&map, 0, lineend) != 0) {
      ierr(fn);
      return;
    }
    if (map.start != nil && (munmap(UnsafeMutableRawPointer(mutating: map.start)!, map.maplen) != 0)) {
      ierr(fn);
    }
     */
  }
  
  
  
  
  
  
  
  /*
   * r_buf -- display a non-regular file in reverse order by line.
   *
   * This is the function that saves the entire input, storing the data in a
   * doubly linked list of buffers and then displays them in reverse order.
   * It has the usual nastiness of trying to find the newlines, as there's no
   * guarantee that a newline occurs anywhere in the file, let alone in any
   * particular buffer.  If we run out of memory, input is discarded (and the
   * user warned).
   */
  
  func r_buf(_ fp: FileDescriptor, _ filename: String) async throws {

    var lns : [String] = []
    for try await line in fp.bytes.lines {
      lns.append(line)
    }
    
     // Print the buffers in reverse order
    for line in lns.reversed() {
      print(line)
    }
  }
}

extension Array {
  func lastIndex(of byte: Element, before index: Index? = nil) -> Int? where Element: Equatable {
      let si = (index ?? self.endIndex)
      
    guard si > self.startIndex, si <= self.endIndex else {
          return nil
      }
      
      for i in stride(from: si-1, through: 0, by: -1) {
          if self[i] == byte {
              return i
          }
      }      
      return nil
  }
}

extension UnsafeRawBufferPointer {
  func lastIndex(of byte: UInt8, before index: Int? = nil) -> Int? {
      let si = (index ?? self.endIndex)
      
    guard si > self.startIndex, si <= self.endIndex else {
          return nil
      }
      
      for i in stride(from: si-1, through: 0, by: -1) {
          if self[i] == byte {
              return i
          }
      }
      return nil
  }
}

extension FileDescriptor {
  public var isRegularFile : Bool {
    var sbp = stat()
    if fstat(self.rawValue, &sbp) != 0 {
      return false
    }
    return (sbp.st_mode & S_IFMT) == S_IFREG
  }
}




/// Memory-maps a file read-only and returns its contents as an `UnsafeRawBufferPointer`.
public func mmapFileReadOnly(at path: FilePath) throws -> UnsafeRawBufferPointer {
    // Open file
    let fd = try FileDescriptor.open(path, .readOnly)

    // Get file size
    var statBuf = stat()
    let statResult = path.string.withCString { cPath in
        stat(cPath, &statBuf)
    }

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
    let addr = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd.rawValue, 0)
    try fd.close() // Safe to close after mmap

    guard addr != MAP_FAILED else {
        throw Errno(rawValue: errno)
    }

    return UnsafeRawBufferPointer(start: addr, count: size)
}
