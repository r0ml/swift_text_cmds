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

import Foundation
import CMigration
import zlib
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
  var fd : FileHandle
  var binary : Bool = false
  
  var buffer : Data = Data()
  var bufrange : Range<Int> = 0..<0
  
//  var inputFilter : InputFilter<Data>?
  var name : String
  
  // var bufrem : Int = 0
// var bufpos : Int = 0
  
  var behave : FILE = .STDIO
//  var lbflag = false
  
  var MAXBUFSIZ : Int { (32 * 1024) }
  var LNBUFBUMP : Int { 80 }
  
  var gzbufdesc : gzFile?
  /*
  func createFilter() {
    let inputFilter: InputFilter<Data>
    do {
        var index = 0
        let bufferSize = compressedData.count
        
        inputFilter = try InputFilter(.decompress,
                                      using: .lzfse) { (length: Int) -> Data? in
            let rangeLength = min(length, bufferSize - index)
          // FIXME: compressedData is read from source
            let subdata = compressedData.subdata(in: index ..< index + rangeLength)
            index += rangeLength
            
            return subdata
        }
    } catch {
        fatalError("Error occurred creating input filter: \(error.localizedDescription).")
    }
  }
  
  func decompress() {
    do {
        while let page = try inputFilter.readData(ofLength: pageSize) {
            decompressedData.append(page)
        }
    } catch {
        fatalError("Error occurred during decoding: \(error.localizedDescription).")
    }
  }
  */
  
  private func grep_refill() -> Bool {
    //   ssize_t nr;
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

    buffer = buffer.subdata(in: bufrange)

    
    // FIXME: put me back
    //    if (refillbehave == .BZIP && bzbufdesc == NULL) {
    //      refillbehave = .STDIO;
    //    }
    //   #endif
    bufrange = 0..<0 // buffer.count
    
    switch (refillbehave) {
        //   #ifdef __APPLE__
      case .GZIP:
        
//        do {
          let z = UnsafeMutableBufferPointer<CChar>.allocate(capacity: MAXBUFSIZ)
          let nr = gzread(gzbufdesc, z.baseAddress!, UInt32(MAXBUFSIZ));
          if nr > 0 {
            let b = Data(bytesNoCopy: z.baseAddress!, count: Int(nr), deallocator: .free)
            buffer.append(b)
            bufrange = 0..<buffer.count
          } else if nr < 0 {
            let str = String(cString: strerror(errno))
            warn("read error \(name): \(str)")
            return false
          }
          return true
        
 /*         if let b = try inputFilter?.readData(ofLength: MAXBUFSIZE) {
            buffer.append(b)
          }
          bufrange = 0..<buffer.count
          return true
        } catch {
          warn("read error \(name): \(error.localizedDescription)")
          return false
        }
  */
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
        //   #endif /* __APPLE__ */
      default:
        do {
          if let b = try fd.read(upToCount: MAXBUFSIZ) {
            buffer.append(b)
          }
          bufrange = 0..<buffer.count
          return true
        } catch {
          return false
        }
    }
  }
   
  /*
   static inline int
   grep_lnbufgrow(size_t newlen)
   {
   
   if (lnbuflen < newlen) {
   lnbuf = grep_realloc(lnbuf, newlen);
   lnbuflen = newlen;
   }
   
   return (0);
   }
   */
  
  func grep_fgetln(_ pc : inout grepDoer.parsec, _ options : grep.CommandOptions) -> String? {
    /*   char *p;
     size_t len;
     size_t off;
     ptrdiff_t diff;
     */
    
    /* Fill the buffer, if necessary */
    if (bufrange.count == 0 && !grep_refill() ) {
      pc.ln.dat = ""
      return nil
    }
    
    if (bufrange.count == 0) {
      /* Return zero length to indicate EOF */
      pc.ln.dat = ""
      return ""
    }
    
    /* Look for a newline in the remaining part of the buffer */
    let fileeold = Data([options.fileeol.asciiValue!])
    let t = buffer.range(of: fileeold, in: bufrange) ?? bufrange
    let str = buffer.subdata(in: bufrange.startIndex..<t.upperBound)
    bufrange = t.upperBound ..< bufrange.upperBound
    
    if String(data: str, encoding: .utf8) == nil {
      binary = true
    }
    
    let ss =
    binary ? String(data: str, encoding: .isoLatin1)! : String(data: str, encoding: .utf8) ??
    String(data: str, encoding: .isoLatin1)!
    pc.ln.dat = ss
    return ss
    
      /* Fetch more to try and find EOL/EOF */
  }
  
  
  /*
   * Opens a file for processing.
   */
  init?(_ path : String?, _ behav : FILE, _ fileeol : Character, _ binbehav : grep.BINFILE) {
    self.behave = behav
    
    var url : URL?
    if let path {
      name = path
      url = URL(fileURLWithPath: path)
      do {
        fd = try FileHandle(forReadingFrom: url!)
      } catch {
        return nil
      }
    } else {
      name = "stdin"
      /* Processing stdin implies --line-buffered. */
//      options.lbflag = true
      fd = FileHandle.standardInput
    }
    
    if (behave == FILE.MMAP) {
      var st = stat()
      let fse = fstat(fd.fileDescriptor, &st)
      if fse == -1 || st.st_size > OFF_MAX ||
          !S_ISREG(st.st_mode) {
        behave = .STDIO
      }
      else {
//        #ifdef __APPLE__
        let flags = MAP_PRIVATE | MAP_NOCACHE
//#else
//        int flags = MAP_PRIVATE | MAP_NOCORE | MAP_NOSYNC;
//        #ifdef MAP_PREFAULT_READ
//        flags |= MAP_PREFAULT_READ;
//#endif
//#endif /* __APPLE__ */
        let fsiz = Int(st.st_size)
        let bbuffer = mmap(nil, fsiz, PROT_READ, flags,
                      fd.fileDescriptor, 0);
  
        // FIXME: there is no way to determine if the data will be memory mapped or read in
        // The work-around is to manually memory-map
//        buffer = try! Data.init(contentsOf: url!, options: .mappedIfSafe)
        if (bbuffer == MAP_FAILED) {
          behave = .STDIO
        }
        else {
          buffer = Data.init(bytesNoCopy: bbuffer!, count: fsiz, deallocator: .unmap)
          bufrange = 0..<fsiz
          madvise(bbuffer, fsiz, MADV_SEQUENTIAL)
        }
      }
    }
    
/*    if ((buffer == nil) || (bbuffer == MAP_FAILED)) {
      buffer = UnsafeMutableRawPointer.allocate(byteCount: MAXBUFSIZ, alignment: 8)
    }
  */
    
    switch (behave) {
//        #ifdef __APPLE__
      case .GZIP:
        
        guard let gzbufdesc = gzdopen(fd.fileDescriptor, "r") else { try? fd.close();
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
        fatalError( "not yet implemented")
        /*
        if ((baaaaaazbufdesc = BZ2_bzdopen(f->fd, "r")) == NULL)
            goto error2;
        break;
         */
      case .XZ, .LZMA:
        
      fatalError("not yet implemented")
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
// #endif /* __APPLE__ */
      default:
        break;
    }
        
    /* Fill read buffer, also catches errors early */
    if !grep_refill() {
      try? fd.close()
      return nil
    }
//    if (bufrem == 0 && grep_refill(f) != 0) {
//      try? fd.close()
//      return nil
//    }
    
    /* Check for binary stuff, if necessary */
//    #ifdef __APPLE__

    // FIXME: put me back ?
    if // binbehav != .TEXT &&
      fileeol != "\0" &&
        buffer.contains(0) {
//        memchr(bufpos, "\0", bufrem) != NULL) {
      
      //        #else
      //        if (binbehave != BINFILE_TEXT && fileeol != '\0' &&
      //            memchr(bufpos, '\0', bufrem) != NULL)
      //        #endif
      self.binary = true
    }
    
 //
//  error2:
//    close(f->fd);
//  error1:
//    free(f);
//    return (NULL);
  }
  

   /*
    * Closes a file.
    */
  func grep_close() {
    /* Reset read buffer and line buffer */
    buffer = Data()
    bufrange = 0..<0
    try? fd.close()
  }

  
}
