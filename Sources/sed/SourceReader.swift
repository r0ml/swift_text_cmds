// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation
import CMigration

extension SedProcess {

  /*
  var firstfile = FirstFile.initial
  
  enum FirstFile {
    case initial
    case yes
    case no
  }
  */
  
  func mf_fgets() async throws -> String? {
    
    /*
     var inFile = FileHandle.standardInput.bytes.lines.makeAsyncIterator()
     while let l = try await inFile.next() {
     
     }
     */
    
    while !quit {
      if let sti = self.inp {
        do {
          
          if let got = try await sti.next() {
            self.linenum += 1
            if self.linenum == 1 && got.hasPrefix("#n") {
              self.nflag = true
              //              options.nflag = true
            }
            return got
          }
          // reached EOF
          try mf_close_file()
          continue
        }
        // FIXME: handle the 'inplace' option
      } else {
        // This is where the next file is opened
        if self.filelist.isEmpty { return nil }
        if try !mf_next_file() {
          return nil
        }
/*        self.inp = try PeekableAsyncIterator( self.filelist.removeFirst() )
        if options.inplace != nil {
          if self.inp?.fh == FileHandle.standardInput {
            throw CmdErr(1, "-I or -i may not be used with stdin")
          }
        }
 */
/*
        if firstfile == .initial {
          firstfile = .yes
        } else {
          firstfile = .no
        }
 */
      }
    }
    try mf_close_file()
    return nil
  }
  
  func peek() async throws -> String? {
    while true {
      if let sti = self.inp {
        do {
          
          if let got = try await sti.peek() {
            return got
          }
          
          try sti.fh?.close()
          self.inp = nil
          continue
        }
        // FIXME: handle the 'inplace' option
      } else {
        if self.filelist.isEmpty { return nil }
        self.inp = try PeekableAsyncIterator( self.filelist.removeFirst() )
      }
    }
  }
  
  func mf_close_file() throws {
    if let sti = self.inp {
      if sti.fh != FileHandle.standardInput {
        try sti.fh?.close()
        // if there was a backup file, remove it
        if let oldfname {
          // make sure the backup name is available
          try? FileManager.default.removeItem(at: URL(filePath: oldfname))
          
          // FIXME: should oldfname be a URL?
          do {
            try FileManager.default.linkItem(at: URL(filePath: sti.fname), to: URL(filePath: oldfname))
          } catch {
            do {
              try posixRename(from: sti.fname, to: oldfname)
            } catch {
              if let tmpfname {
                try? FileManager.default.removeItem(at: tmpfname)
                throw CmdErr(1, "renaming \(sti.fname) to \(oldfname) failed: \(error.localizedDescription)")
              }
            }
          }
          self.oldfname = nil
        }
        
        if let tmpfname {
          if outfile != FileHandle.standardOutput {
            do {
              try outfile.close()
            } catch {
              try? FileManager.default.removeItem(at: tmpfname)
              throw CmdErr(1, "closing \(outfname): \(error.localizedDescription)")
            }
            
            do {
              try posixRename(from: tmpfname.path, to: inp!.fname)
            } catch {
              try? FileManager.default.removeItem(at: tmpfname)
              throw CmdErr(1, "rename \(tmpfname) to \(inp!.fname): \(error.localizedDescription)")
            }
            
          }
          self.tmpfname = nil
        }
        // outfname = NULL;
      }
      self.inp = nil
    }
  }
  
  func mf_next_file() throws(CmdErr) -> Bool {
    // script is a global list
    if self.filelist.isEmpty {
      return false
    }
    //    st.linenum = 0
    
    let fnam = self.filelist.removeFirst()
    // open file
    if fnam == "-"  || fnam == "/dev/stdin" {
      self.inp = PeekableAsyncIterator(FileHandle.standardInput, "stdin")
      
      if options.inplace != nil {
        throw CmdErr(1, "-I or -i may not be used with stdin")
      }
      
    } else {
      if let inplace = options.inplace {
        var v = false
        do {
          v = try FileWrapper(url: URL(filePath: fnam)).isRegularFile
        } catch {
          throw CmdErr(1, "checking \(fnam): \(error.localizedDescription)")
        }
        if v != true {
          throw CmdErr(1, "\(fnam): in-place editing only works for regular files")
        }
        if !inplace.isEmpty {
          oldfname = "\(fnam)\(inplace)"
        }
        let dirbuf = URL(filePath: fnam).absoluteURL.deletingLastPathComponent()
        let base = URL(filePath: fnam).lastPathComponent
        let pid = ProcessInfo.processInfo.processIdentifier
        let stmpfname = ".!\(pid)!\(base)"
        tmpfname = URL(filePath: stmpfname, relativeTo: dirbuf)
        try? FileManager.default.removeItem(at: tmpfname!)
        
        if outfile != FileHandle.standardOutput {
          try? outfile.close()
        }
        outfname = tmpfname!.relativePath
        if FileManager.default.createFile(atPath: tmpfname!.path, contents: nil, attributes: [:]) {
          do {
            
            outfile = try FileHandle(forWritingTo:  tmpfname!)
          } catch {
            throw CmdErr(1, "opening for writing: \(stmpfname): \(error.localizedDescription)")
          }
          outfname = tmpfname!.path
        } else {
          throw CmdErr(1, "creating \(stmpfname): failed")
        }
        // fchown
        // fchmod
        if !options.ispan {
          linenum = 0
          prog = resetstate(prog)
          // clear out the hold space
          HS = SPACE("")
        }
        
      } else {
        outfile = FileHandle.standardOutput
        outfname = "stdout"
      }
      
      
      do {
        self.inp = try PeekableAsyncIterator(fnam)
      } catch {
        throw CmdErr(1, "\(fnam): \(error.localizedDescription)")
      }
    }
    return true
  }

  // reset all in-range markers
  func resetstate(_ pro : [s_command]) -> [s_command] {
    var pr = pro
    for i in 0..<pr.count {
      if case let .c(v) = pr[i].u {
        pr[i].u = .c(resetstate(v))
      } else {
        if let _ = pr[i].a2 {
          pr[i].startline = 0
        }
      }
    }
    return pr
  }
  
  /**
   * mf_fgets: read next line from the list of files, storing in SPACE sp.
   * If spflag == REPLACE, we replace contents; if APPEND, we append.
   * Returns 1 if line read, 0 if no more lines.
   */
  /*
   * Like fgets, but go through the list of files chaining them together.
   * Set len to the length of the line.
   */
  
  // FIXME: mf_fgets is different than cu_fgets --
  // including resetstate
  
  
  
  // If we got here, we have an open inFile with data available. We'll read one line
  /*
   var len = getline_swift(linePtr, 1024, inFile)
   if len < 0 {
   err(1, "\(fname)")
   }
   // check newline
   if len != 0, linePtr[len-1] == CChar(UInt8(ascii: "\n")) {
   sp.append_newline = 1
   len -= 1
   } else if !lastline() {
   sp.append_newline = 1
   } else {
   sp.append_newline = 0
   }
   // cspace => store in sp
   cspace(&sp, linePtr, spflag)
   linenum += 1
   return 1
   }
   */
  
  /**
   * lastline(): check if the current file is at EOF and no next file has lines.
   */
  /*  func lastline() -> Bool {
   // The code in C checks feof(inFile), etc. Then it checks if next files have lines.
   // We'll do a partial approach:
   if feof(inFile) != 0 {
   return !((inplace == nil || ispan != 0) && next_files_have_lines() != 0)
   }
   // check next char
   if let c = fgetc(inFile) {
   ungetc(c, inFile)
   return false
   }
   // EOF
   return !((inplace == nil || ispan != 0) && next_files_have_lines() != 0)
   }
   
   // helper to check next files for lines
   private func next_files_have_lines() -> Int32 {
   var file = files
   while let fnode = file?.next {
   file = fnode
   if let file_fd = fopen(fnode.fname ?? "", "r") {
   if let ch = fgetc(file_fd) {
   ungetc(ch, file_fd)
   fclose(file_fd)
   return 1
   }
   fclose(file_fd)
   }
   }
   return 0
   }
   */
  
  
  
}

enum inpSourceType {
  case ST_EOF
  case ST_FILE
  case ST_STRING
}

class PeekableAsyncIterator {
//  var iter : AsyncLineSequence<FileHandle.AsyncBytes>.AsyncIterator

//  var iter : FileHandle.AsyncBytes.AsyncLineIterator
  var iter : AsyncLineSequenceX<FileHandle.AsyncBytes>.AsyncIterator
  
  var peeked : String? = nil
  var fh : FileHandle?
  var fname : String = "?"
  
  init(_ f : String) throws {
    self.fname = f
    let fh = try FileHandle(forReadingFrom: URL(filePath: f))
    self.fh = fh
    self.iter = fh.bytes.linesNLX.makeAsyncIterator()
  }
  
  init(_ fh : FileHandle, _ f : String) {
    self.fh = fh
    self.iter = fh.bytes.linesNLX.makeAsyncIterator()
    self.fname = f
  }
  
  func next() async throws -> String? {
    if peeked != nil {
      let t = peeked
      peeked = nil
      return t
    }
    
    return try await iter.next()
  }
  
  func peek() async throws -> String? {
    if peeked == nil {
      peeked = try await iter.next()
    }
    return peeked
  }
}
