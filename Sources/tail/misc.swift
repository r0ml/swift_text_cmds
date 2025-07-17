
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

  /// Logs an error with a file name.
  func ierr(_ filename: String) {
    print("Error: \(filename)")
    rval = 1
  }

  /*
  /// Logs an output error and exits.
  func oerr() {
    fatalError("Error: stdout")
  }
  */

  /*
  /// Structure representing memory-mapped file info
  struct MapInfo {
    var fd: Int32
    var start: UnsafeMutableRawPointer?
    // FIXME: are these always Int64 (originally off_t)
    var mapOffset: Int64
    var mapLength: Int64
    var maxOffset: Int64
  }
  */
  
  /// Prints `len` bytes from a file starting at `startOffset`, possibly adjusting the memory map.
/*  func mapprint(mip: inout MapInfo, startOffset: off_t, length: off_t) -> Int {
    var remainingLength = length
    var currentOffset = startOffset
    
    while remainingLength > 0 {
      if currentOffset < mip.mapOffset || currentOffset >= mip.mapOffset + mip.mapLength {
        if maparound(mip: &mip, offset: currentOffset) != 0 {
          return 1
        }
      }
      
      var bytesToPrint = (mip.mapOffset + mip.mapLength) - currentOffset
      if bytesToPrint > remainingLength {
        bytesToPrint = remainingLength
      }
      
      if let startPointer = mip.start {
        WR(startPointer.advanced(by: Int(currentOffset - mip.mapOffset)), Int(bytesToPrint))
      }
      
      currentOffset += bytesToPrint
      remainingLength -= bytesToPrint
    }
    
    return 0
  }
*/
  
  /// Moves the memory map window to contain the byte at `offset`.
/*  func maparound(mip: inout MapInfo, offset: off_t) -> Int {
    let TAILMAPLEN: off_t = 4096  // Example size for memory mapping
    
    if let start = mip.start {
      munmap(start, mip.mapLength)
    }
    
    mip.mapOffset = offset & ~(TAILMAPLEN - 1)
    mip.mapLength = TAILMAPLEN
    
    if mip.mapLength > (mip.maxOffset - mip.mapOffset) {
      mip.mapLength = mip.maxOffset - mip.mapOffset
    }
    
    if mip.mapLength <= 0 {
      fatalError("Invalid map length")
    }
    
    let mappedMemory = mmap(nil, Int(mip.mapLength), PROT_READ, MAP_SHARED, mip.fd, mip.mapOffset)
    
    if mappedMemory == MAP_FAILED {
      return 1
    }
    
    mip.start = mappedMemory
    return 0
  }
*/
  
  /// Prints a file name without stdio buffering.
/*  func printfn(_ filename: String, printNewline: Bool) {
    if printNewline {
      WR("\n", 1)
    }
    WR("==> ", 4)
    WR(filename, filename.utf8.count)
    WR(" <==\n", 5)
  }
  
  
    #define TAILMAPLEN (4<<20)
  */
}
