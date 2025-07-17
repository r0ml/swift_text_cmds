// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file containing the following notice:

/*-
  SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 
  Copyright (c) 1999 James Howard and Dag-Erling Coïdan Smørgrav
  Copyright (C) 2008-2010 Gabor Kovesdan <gabor@FreeBSD.org>
  Copyright (C) 2010 Dimitry Andric <dimitry@andric.com>
  All rights reserved.
 
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

import CMigration
import zlib
import Darwin

// import Compression

let MAXBUFSIZE = 32 * 1024

enum FILE {
  case STDIO
  case MMAP
  case GZIP
  case BZIP
  case XZ
  case LZMA
}

class file {
  var fd : FileDescriptor
  var binary : Bool = false
  
  var buffer = [UInt8]()
  var bbuffer : UnsafeRawBufferPointer?
  var bufrange : Range<Int> = 0..<0
  
  var name : String
  
  var behave : FILE = .STDIO

  var MAXBUFSIZ : Int { (32 * 1024) }
  var LNBUFBUMP : Int { 80 }
  
  var gzbufdesc : gzFile?
  
  private func grep_refill() -> Bool {
    // FIXME: refillbehave needs to live across calls to grep_refill
    let refillbehave = behave
    
    if (refillbehave == .MMAP) {
      return true
    }
    
    //   #ifdef __APPLE__
    /*
     * Fallback to plain old read() if BZ2_bzRead() tossed BZ_DATA_ERROR_MAGIC
     * below.  We can't change filebehave without losing pertinent information
     * for future files.
     */

    buffer = Array(buffer[bufrange])

    
    // FIXME: put me back
    //    if (refillbehave == .BZIP && bzbufdesc == NULL) {
    //      refillbehave = .STDIO;
    //    }
    //   #endif
    bufrange = 0..<0 // buffer.count
    
    switch (refillbehave) {
      case .GZIP:
          let z = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: MAXBUFSIZ)
          let nr = gzread(gzbufdesc, z.baseAddress!, UInt32(MAXBUFSIZ));
          if nr > 0 {
            let b = UnsafeBufferPointer(start: z.baseAddress!, count: Int(nr))
            buffer.append(contentsOf: b)
            bufrange = 0..<buffer.count
          } else if nr < 0 {
            let str = String(cString: strerror(errno))
            warn("read error \(name): \(str)")
            return false
          }
          return true

      case .BZIP:
        fatalError("BZIP2 not implemented yet")
        /*
         var bzerr = BZ_OK;
         nr = BZ2_bzRead(&bzerr, bzbufdesc, buffer, MAXBUFSIZ);
         switch (bzerr) {
         case BZ_OK, BZ_STREAM_END:
         /* No problem, nr will be okay */
         break;
         case BZ_DATA_ERROR_MAGIC:
         /*
          * As opposed to gzread(), which simply returns the
          * plain file data, if it is not in the correct
          * compressed format, BZ2_bzRead() instead aborts.
          *
          * So, just restart at the beginning of the file again,
          * and use plain reads from now on.
          */
         BZ2_bzReadClose(&bzerr, bzbufdesc);
         bzbufdesc = NULL;
         if (lseek(f->fd, 0, SEEK_SET) == -1)
         return (-1);
         nr = read(f->fd, buffer, MAXBUFSIZ);
         break;
         default:
         /* Make sure we exit with an error */
         nr = -1;
         break;
         }
         break;
         */
      case .XZ, .LZMA:
        fatalError("LZMA and XZ not implemented yet")
        /*
         var lzmaret : lzma_ret = 0
         lstrm.next_out = (uint8_t *)buffer;
         
         do {
         if (lstrm.avail_in == 0) {
         lstrm.next_in = lin_buf;
         nr = read(f->fd, lin_buf, MAXBUFSIZ);
         
         if (nr < 0) {
         return (-1);
         }
         else if (nr == 0) {
         laction = LZMA_FINISH;
         }
         
         lstrm.avail_in = nr;
         }
         
         lzmaret = lzma_code(&lstrm, laction);
         
         if (lzmaret != LZMA_OK && lzmaret != LZMA_STREAM_END)
         return (-1);
         
         if (lstrm.avail_out == 0 || lzmaret == LZMA_STREAM_END) {
         bufrem = MAXBUFSIZ - lstrm.avail_out;
         lstrm.next_out = (uint8_t *)buffer;
         lstrm.avail_out = MAXBUFSIZ;
         }
         } while (bufrem == 0 && lzmaret != LZMA_STREAM_END);
         
         return (0);
         */
      default:
        do {
          let b = try fd.readUpToCount(MAXBUFSIZ)
          buffer.append(contentsOf: b)
          bufrange = 0..<buffer.count
          return true
        } catch {
          return false
        }
    }
  }
   
  func grep_fgetln(_ pc : inout grepDoer.parsec, _ options : grep.CommandOptions) -> String? {
    
    // Fill the buffer, if necessary
    if (bufrange.count == 0 && !grep_refill() ) {
      pc.ln.dat = ""
      return nil
    }
    
    if (bufrange.count == 0) {
      // Return zero length to indicate EOF
      pc.ln.dat = ""
      return ""
    }
    
    // Look for a newline in the remaining part of the buffer
    let fileeold = [options.fileeol.asciiValue!]
    let str : ArraySlice<UInt8>
    
    if let bbuffer {
      if let tt = bbuffer.firstIndex(of: fileeold, in: bufrange) {
        str = ArraySlice(bbuffer[bufrange.startIndex...tt])
        bufrange = tt + fileeold.count ..< bufrange.upperBound
      }
      else {
        str = ArraySlice( bbuffer[bufrange.startIndex...] )
        bufrange = bufrange.upperBound..<bufrange.upperBound
      }
    } else {
      
      if let tt = buffer.firstIndex(of: fileeold, in: bufrange) {
        //      tx = Range(tt...(tt+fileeold.count-1))
        str = buffer[bufrange.startIndex...tt]
        bufrange = tt + fileeold.count ..< bufrange.upperBound
      } else {
        str = buffer[bufrange.startIndex...]
        bufrange = bufrange.upperBound..<bufrange.upperBound
      }
    }
    
    if String(validating: str, as: UTF8.self) == nil {
      binary = true
    }
    
    let ss =
    binary ? String(validating: str, as: ISOLatin1.self)! : String(validating: str, as: UTF8.self) ??
    String(validating: str, as: ISOLatin1.self)!
    pc.ln.dat = ss
    return ss
  }
  
  
  /// Opens a file for processing.
  init?(_ path : String?, _ behav : FILE, _ fileeol : Character, _ binbehav : grep.BINFILE) {
    self.behave = behav

    if let path {
      name = path
      do {
        fd = try FileDescriptor(forReading: path)
      } catch {
        return nil
      }
    } else {
      name = "stdin"
      // Processing stdin implies --line-buffered.
      // FIXME: is line buffering supported?
//      options.lbflag = true
      fd = FileDescriptor.standardInput
    }
    
    if (behave == FILE.MMAP) {
      var st = Darwin.stat()
      let fse = Darwin.fstat(fd.rawValue, &st)
      if fse == -1 || st.st_size > OFF_MAX ||
          !S_ISREG(st.st_mode) {
        behave = .STDIO
      }
      else {
        let fsiz = Int(st.st_size)
        do {
          bbuffer = try mmapFileReadOnly(fd)
          bufrange = 0..<fsiz
          madvise(UnsafeMutableRawPointer(mutating: bbuffer!.baseAddress), fsiz, MADV_SEQUENTIAL)
        } catch {
          behave = .STDIO
        }
      }
    }

    switch (behave) {
      case .GZIP:
        
        guard let gzbufdesc = gzdopen(fd.rawValue, "r") else { try? fd.close();
          let str = String(cString: strerror(errno))
          warn("read error \(name): \(str)")
          return nil }
        self.gzbufdesc = gzbufdesc
        
        /*
        do {
          inputFilter = try InputFilter(.decompress, using: .zlib) { (length: Int) -> Data? in
            if let ib = try self.fd.read(upToCount: length), !ib.isEmpty {
              return ib
            }
            return nil
          }

        } catch {
          warn("read error \(name): \(error.localizedDescription)")
          return nil
        }
         */
        
      case .BZIP:
        fatalError( "reading BZIP not yet implemented")
        /*
        if ((baaaaaazbufdesc = BZ2_bzdopen(f->fd, "r")) == NULL)
            goto error2;
        break;
         */
      case .XZ, .LZMA:
        
      fatalError("reading XZ or LZMA not yet implemented")
        /*
         {
        lzma_ret lzmaret;
        
        if (filebehave == FILE_XZ)
            lzmaret = lzma_stream_decoder(&lstrm, UINT64_MAX,
                                          LZMA_CONCATENATED);
        else
          lzmaret = lzma_alone_decoder(&lstrm, UINT64_MAX);
        
        if (lzmaret != LZMA_OK)
            goto error2;
        
        lstrm.avail_in = 0;
        lstrm.avail_out = MAXBUFSIZ;
        laction = LZMA_RUN;
        break;
      }
         */
      default:
        break;
    }
        
    /// Fill read buffer, also catches errors early
    if !grep_refill() {
      try? fd.close()
      return nil
    }

    /// Check for binary stuff, if necessary
    if binbehav != .TEXT && fileeol != "\0" && buffer.contains(0) {
      self.binary = true
    }
  }

   /// Closes a file
  func grep_close() {
    /* Reset read buffer and line buffer */
    buffer = [UInt8]()
    bufrange = 0..<0
    try? fd.close()
  }

  
}


