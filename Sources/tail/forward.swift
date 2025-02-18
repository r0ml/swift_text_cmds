
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
  enum Style {
    case fBytes, fLines, rBytes, rLines
  }
  
  // Global variables for event handling
  var useKqueue: Bool = false
  var lastFile: FileInfo?
  
  // Structure to hold file information
  struct FileInfo {
    let fileName: String
    var filePointer: UnsafeMutablePointer<FILE>?
    var fileStats: stat
  }
  
  // Function to handle errors when reading a file
  func ierr(_ filename: String) {
    print("Error: \(filename)", to: &stderr)
  }
  
  // Function to handle stdout errors
  func oerr() {
    fatalError("Error writing to stdout")
  }
  
  // Reads and prints file content based on the given style and offset
  func forward(fp: UnsafeMutablePointer<FILE>, filename: String, style: Style, offset: off_t, fileStats: inout stat) {
    var ch: Int32
    
    switch style {
      case .fBytes:
        if offset == 0 { break }
        if S_ISREG(fileStats.st_mode) {
          if fileStats.st_size < offset {
            fseeko(fp, fileStats.st_size, SEEK_SET)
          } else if fseeko(fp, offset, SEEK_SET) == -1 {
            ierr(filename)
            return
          }
        } else {
          var remaining = offset
          while remaining > 0, (ch = getc(fp)) != EOF {
            remaining -= 1
          }
        }
        
      case .fLines:
        if offset == 0 { break }
        var remaining = offset
        while (ch = getc(fp)) != EOF {
          if ch == Int32(UnicodeScalar("\n").value) {
            remaining -= 1
            if remaining == 0 { break }
          }
        }
        
      case .rBytes:
        if S_ISREG(fileStats.st_mode) {
          if fileStats.st_size >= offset, fseeko(fp, -offset, SEEK_END) == -1 {
            ierr(filename)
            return
          }
        } else {
          // Read the last `offset` bytes using a wrap-around buffer
          _ = bytes(fp: fp, filename: filename, offset: offset)
        }
        
      case .rLines:
        if S_ISREG(fileStats.st_mode) {
          if offset == 0 {
            if fseeko(fp, 0, SEEK_END) == -1 {
              ierr(filename)
              return
            }
          } else {
            rlines(fp: fp, filename: filename, offset: offset, fileStats: &fileStats)
          }
        } else {
          _ = lines(fp: fp, filename: filename, offset: offset)
        }
    }
    
    // Print file contents from current position
    while (ch = getc(fp)) != EOF {
      if putchar(ch) == EOF {
        oerr()
      }
    }
    
    fflush(stdout)
  }
  
  // Reads and prints the last `offset` lines of the file
  func rlines(fp: UnsafeMutablePointer<FILE>, filename: String, offset: off_t, fileStats: inout stat) {
    guard fileStats.st_size > 0 else { return }
    
    let bufferSize = Int(fileStats.st_blksize)
    guard let buffer = malloc(bufferSize)?.assumingMemoryBound(to: UInt8.self) else {
      ierr(filename)
      return
    }
    
    defer { free(buffer) }
    
    flockfile(fp)
    
    var wanted = offset
    var found: off_t = 0
    var currentOffset: off_t = roundup(fileStats.st_size - 1, bufferSize)
    
    while currentOffset > 0 {
      currentOffset -= off_t(bufferSize)
      fseeko(fp, currentOffset, SEEK_SET)
      
      let bytesRead = fread(buffer, 1, bufferSize, fp)
      if bytesRead == 0 {
        ierr(filename)
        return
      }
      
      for i in stride(from: bytesRead - 1, through: 0, by: -1) {
        if buffer[i] == UInt8(ascii: "\n") {
          found += 1
          if found == wanted { break }
        }
      }
      
      if found == wanted {
        fseeko(fp, currentOffset + off_t(bytesRead), SEEK_SET)
        break
      }
    }
    
    while let line = fgets(buffer, Int(fileStats.st_blksize), fp) {
      print(String(cString: line), terminator: "")
    }
    
    funlockfile(fp)
  }
  
  // Displays the file content and handles event-driven following (`-f` flag)
  func follow(files: inout [FileInfo], style: Style, offset: off_t) {
    var active = false
    
    for i in 0..<files.count {
      guard let fp = files[i].filePointer else { continue }
      active = true
      print("==> \(files[i].fileName) <==", terminator: "\n")
      forward(fp: fp, filename: files[i].fileName, style: style, offset: offset, fileStats: &files[i].fileStats)
    }
    
    if !active { return }
    
    lastFile = files.last
    
    let kq = kqueue()
    guard kq >= 0 else { fatalError("kqueue error") }
    
    var keventList = [kevent](repeating: kevent(), count: files.count * 2)
    
    for i in 0..<files.count {
      guard let fp = files[i].filePointer else { continue }
      
      let fd = fileno(fp)
      
      EV_SET(&keventList[i], UInt(fd), EVFILT_READ, EV_ADD | EV_ENABLE | EV_CLEAR, 0, 0, nil)
    }
    
    var ts = timespec(tv_sec: 1, tv_nsec: 0)
    
    while true {
      let n = kevent(kq, &keventList, keventList.count, &keventList, 1, &ts)
      
      if n < 0, errno != EINTR {
        fatalError("kevent error")
      }
      
      for i in 0..<files.count {
        guard let fp = files[i].filePointer else { continue }
        
        if let lastFile = lastFile, lastFile.fileName != files[i].fileName {
          print("==> \(files[i].fileName) <==", terminator: "\n")
        }
        
        forward(fp: fp, filename: files[i].fileName, style: style, offset: offset, fileStats: &files[i].fileStats)
      }
    }
  }
  
  // Helper function to print a file's name
  func printFilename(_ filename: String, newline: Bool = true) {
    if newline { print("\n", terminator: "") }
    print("==> \(filename) <==")
  }
  
  // Helper function to round up to block size
  func roundup(_ num: off_t, _ multiple: Int) -> off_t {
    return (num + off_t(multiple) - 1) / off_t(multiple) * off_t(multiple)
  }
}
