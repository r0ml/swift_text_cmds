
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

  // Structure to hold file information
  struct FileInfo {
    let name: String
    var descriptor: FileDescriptor?
    var inode: Int = 0
    var dev_t : Int = 0
    var nlink : Int = 0

    init(_ nm : String) {
      name = nm
      descriptor = try? FileDescriptor(forReading: name)
      if let descriptor {
        var st = stat()
        let n = fstat(descriptor.rawValue, &st)
        if n != 0 {
          try? descriptor.close()
          self.descriptor = nil
        }
        inode = Int(st.st_ino)
        dev_t = Int(st.st_dev)
        nlink = Int(st.st_nlink)
      }

    }

    init() {
      name = "stdin"
      descriptor = FileDescriptor.standardInput
    }
  }
    
  // Reads and prints file content based on the given style and offset
  func forward(_ fp : FileDescriptor, _ filename : String, _ options : CommandOptions) async throws {

    
    var offset = options.off
    
    switch options.style {
      case .FBYTES:
        fatalError("not yet implemented")
/*        if offset == 0 { break }
        if try FileWrapper.init(url: URL(filePath: filename)).isRegularFile {
          try fp.seek(toOffset: UInt64(offset))
        } else {
          while offset > 0 {
            let k = try fp.read(upToCount: Int(min(offset,Int64(65536))))
            if k == nil { break }
            offset -= Int64(k!.count)
          }
        }
  */
      case .FLINES:
        
        if offset == 0 { break }
        while offset > 0 {
          let ch = try fp.readUpToCount(1)
          guard ch.count > 0 else { break }
          if ch[0] == UnicodeScalar("\n").value {
            offset -= 1
          }
        }
        
      case .RBYTES:
        if fp.isRegularFile {
          let _ = try fp.seek(offset: -offset, from: .end)

          let k = try fp.readUpToCount(Int(offset))
          try FileDescriptor.standardOutput.write(k)
        } else {
          // Read the last `offset` bytes using a wrap-around buffer
          try bytes(fp, filename, offset)
        }

      case .RLINES:

        if fp.isRegularFile {
          if options.off == 0 {
            try fp.seek(offset: 0, from: .end)
          } else {
            try await rlines(fp, filename, options)
          }
        } else {
          try await lines(fp, filename, options)
        }
      default:
        break
    }
    
    // Print file contents from current position
/*    while (ch = getc(fp)) != EOF {
      if putchar(ch) == EOF {
        oerr()
      }
    }
  */
    fsync(FileDescriptor.standardOutput.rawValue)
  }
  
  // Reads and prints the last `offset` lines of the file
  func rlines(_ fp: FileDescriptor, _ filename: String, _ options : CommandOptions) async throws {
    /*
     * Using mmap on network filesystems can frequently lead
     * to distress, and even on local file systems other processes
     * truncating the file can also lead to upset.
     *
     * We scan the file from back to front, counting newlines until we
     * reach the desired number.  For our purposes, a newline marks
     * the beginning of the line it precedes, not the end of the line
     * it follows; we don't check the last character of the file.  If
     * we don't find the number of newline characters that we want, we
     * just print the whole file.
     */

    let size = try fp.seek(offset: 0, from: .end)
    guard size > 0 else { return }
    
    // FIXME: should it be LOCK_EX ?
    if 0 != flock(fp.rawValue, Darwin.LOCK_SH) {
      throw CmdErr(1, "failed to lock file \(filename)")
    }
    
    let blksize = 8192
    let wanted = options.off
    var found: off_t = 0
    var offset : off_t = roundup(Int64(size) - 1, blksize)

    try fp.seek(offset: -1, from: .end)
    let lastc = try fp.readUpToCount(1)

    // find the `\n` at the right distance from the end.
    while offset > 0 {
      offset -= off_t(blksize)
      try fp.seek(offset: offset, from: .start)

      let length = min(blksize, Int(size) - 1 - Int(offset))
      let buf = try fp.readUpToCount(length)
      guard buf.count > 0 else {
        ierr(filename)
        return
      }
      
      var n : Int?
      for i in stride(from: buf.count - 1, through: 0, by: -1) {
        if buf[i] == UInt8(ascii: "\n") {
          found += 1
          if found == wanted { n = i; break }
        }
      }
      
      if let n, found == wanted {
        offset += Int64(n + 1)
        break
      }
    }

    // seek to the right place to be, then read forward from there.
    try fp.seek(offset: offset, from: .start)

    var i = 0
    for try await line in fp.bytes.lines /* dropFirst(Int(offset)). */ {
      i += 1
      if (i >= found + (offset == 0 ? 1 : 0)) && lastc != [10] {
        print(line, terminator: "")
      } else {
        print(line)
      }
    }
/*
    while let line =  fgets(buffer, Int(fileStats.st_blksize), fp) {
      print(String(cString: line), terminator: "")
    }
  */

    // Annotating `flock` with `Darwin` refers to the struct, not the fn
    flock(fp.rawValue, Darwin.LOCK_UN)
  }
  
  
  func show(_ fp : FileDescriptor) async throws -> Bool {

    while true {
      let dd = try fp.readUpToCount(8192)
      // FIXME: put me back -- the filename changed
      /*      if (last != file) {
       if (vflag || (qflag == 0 && no_files > 1))
       printfn(file->file_name, 1);
       last = file;
       }
       */
      if dd.count == 0 { break }
      try FileDescriptor.standardOutput.write(dd)
    }
    // FIXME: if there is a file error, remove it from the list -- but keep the place in case it starts working again
    fsync(FileDescriptor.standardOutput.rawValue)
    return true
  }

  
  
  
  
  enum Action {
    case USE_SLEEP
    case USE_KQUEUE
    case ADD_EVENTS
  }
  
  func set_events(_ files : [FileInfo], _ options : CommandOptions) throws(CmdErr) -> (Int32, [kevent]) {
    var ts = timespec(tv_sec: 0, tv_nsec: 0)

    var evs : [kevent] = []
    
    action = Action.USE_KQUEUE
    for (n, fi) in files.enumerated() {
      guard let fp = fi.descriptor else { continue }
      var sf = statfs()
      if fstatfs(fp.rawValue, &sf) == 0 &&
          (sf.f_flags & UInt32(MNT_LOCAL)) == 0 {
        action = .USE_SLEEP;
        return (-1, [])
      }

      if (options.Fflag && fp != FileDescriptor.standardInput) {
        var ev = kevent(ident: UInt(fp.rawValue), filter: Int16(EVFILT_VNODE),
                        flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
                        fflags: UInt32(NOTE_DELETE | NOTE_RENAME),
                        data: 0,
                        udata: nil)
        evs.append(ev)
      }
      var ev = kevent(ident: UInt(fp.rawValue),
                      filter: Int16(EVFILT_READ),
                      flags: UInt16(EV_ADD | EV_ENABLE | EV_CLEAR),
                      fflags: 0,
                      data: 0,
                      udata: nil)
      evs.append(ev)
    }

    let kq = kqueue()
    guard kq >= 0 else { throw CmdErr(1, "kqueue error")  }

    if (kevent(kq, evs, Int32(evs.count), nil, 0, &ts) < 0) {
      action = .USE_SLEEP;
    }
    return (kq, evs)
  }
  
  
  // Displays the file content and handles event-driven following (`-f` flag)
  func follow(_ files: inout [FileInfo], _ options : CommandOptions) async throws {

    var active = false
    
    for fi in files {
      guard fi.descriptor != nil else { continue }
      active = true
      
      if options.vflag || (!options.qflag && files.count > 1) {
        print("==> \(fi.name) <==")
      }
      
      try await forward(fi.descriptor!, fi.name, options)
    }
    
    if (!options.Fflag && !active) { return }
    
    // Now we implement the "follow" event
    // This could be modernized in Swift by using DispatchSource
    // for now, will simply port the existing kqueue
    // implementation
    
    var lastFile = files.last
    
    var (kq, keventList) = try set_events(files, options)

    var ts = timespec(tv_sec: 1, tv_nsec: 0)
    
    var ev_change = false
    while true {
      ev_change = false
      if options.Fflag {

// FIXME: here is where I open the file if it was missing
        for (i, fi ) in files.enumerated() {
          if fi.descriptor == nil {
            let fo = FileInfo(fi.name)
            if fo.descriptor != nil {
              ev_change = true
              files[i] = fo
            }
              continue
            }
          if fi.descriptor == FileDescriptor.standardInput {
            continue
          }

          let ftmp = FileInfo(fi.name)

          /*
          // FIXME: check to see if the error was ENOENT
           // FIXME: there are also checks here to see if the file
           // is regular
          let ftmp = try? FileDescriptor(forReading: nam)
          var sb2 = stat()
          if let ftmp, fstat(ftmp.rawValue, &sb2) == -1 {
//            if (errno != ENOENT) {
//              ierr(file->file_name);
//            }
              show(file)
              if (file->fp != NULL) {
                fclose(file->fp);
                file->fp = NULL;
              }
              try? ftmp.close()

              ev_change = true
              continue
            }
*/
          if ftmp.inode != fi.inode ||
              ftmp.dev_t != fi.dev_t ||
              ftmp.nlink == 0 {
            if let fp = fi.descriptor {
              try? await show(fp)
            }
                try? fi.descriptor?.close()
                files[i] = ftmp
                ev_change = true
            } else {
              try? ftmp.descriptor?.close()
            }


        }
      }
      
      for fi in files {
        // here there is code which will detect when a file
        // gets created when it wasn't there at the beginning
        
        guard let fp = fi.descriptor else {continue}
        if try await !show(fp) {
          ev_change = true
        }
      }
      
      if (ev_change) {
        (kq, keventList) = try set_events(files, options)
      }
      
      switch action {
        case .USE_KQUEUE:
          ts.tv_sec = 1
          ts.tv_nsec = 0
          var n : Int32 = 0
          repeat {
            withUnsafeMutablePointer(to: &ts) {
              n = kevent(Int32(kq), nil, Int32(0), &keventList, 1, options.Fflag ? $0 : nil)
            }
          } while n < 0
          if n == 0 {
            break // timeout
          } else if keventList[0].filter == EVFILT_READ && keventList[0].data < 0 {
            // file shrank, reposition to end
            if lseek(Int32(keventList[0].ident), 0, SEEK_END) == -1 {
//              ierr(fn)
              // what file name to use here?
              print("what file name to use here?")
            }
          }
          
        case .USE_SLEEP:
          try await Task.sleep(for: .milliseconds(250))
        case .ADD_EVENTS:
          fatalError("action ADD_EVENTS not implemented")
      }
    }
  }
  
  // Helper function to round up to block size
  func roundup(_ num: off_t, _ multiple: Int) -> off_t {
    return (num + off_t(multiple) - 1) / off_t(multiple) * off_t(multiple)
  }
}
