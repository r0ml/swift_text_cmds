// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import CMigration

enum s_compunit {
  case CU_FILE(String)
  case CU_STRING(String)
}

class ScriptReader {
  //    var f: AsyncLineSequence<FileDescriptor.AsyncBytes>.AsyncIterator? = nil
  //    var s: String? = nil
  private var inp : inpSource = inpSource()
  var linenum : Int = 0
  private var fname : String = "?"
  private var script: [s_compunit]
  private var nflag : Bool = false
  
  init(_ script : [s_compunit]) {
    self.script = script
  }
  
  class inpSource {
    var type = inpSourceType.ST_EOF
    var fh : FileDescriptor?
    //    var ai  : FileDescriptor.AsyncBytes.AsyncLineIterator!
    var ai  : AsyncLineReader.AsyncIterator!
    var string : Substring!
  }
  
  
  //  var current_script : FileDescriptor = FileDescriptor.standardInput
  
  func next_file(_ options : sed.CommandOptions ) throws(CmdErr) -> Bool {
    // script is a global list
    if self.script.isEmpty {
      return false
    }
    self.linenum = 0
    
    switch self.script.removeFirst() {
      case .CU_FILE(let fnam):
        // open file
        if fnam == "-"  || fnam == "/dev/stdin" {
          self.inp.type = .ST_FILE
          self.inp.fh = FileDescriptor.standardInput
          self.inp.ai = FileDescriptor.standardInput.bytes.lines.makeAsyncIterator()
          self.fname = "stdin"
          
          if options.inplace != nil {
            throw CmdErr(1, "-I or -i may not be used with stdin")
          }
          
          
          
        } else {
          do {
            let fh = try FileDescriptor(forReading: fnam)
            //          st.inp =  .ST_FILE( fh.bytes.lines.makeAsyncIterator(), fh)
            self.inp.type = .ST_FILE
            self.inp.fh = fh
            self.inp.ai = fh.bytes.lines.makeAsyncIterator( )
          } catch {
            throw CmdErr(1, "\(fnam): \(error)")
          }
          self.fname = fnam
        }
        return true
      case .CU_STRING(let sref):
        if sref.count >= 27 {
          self.fname = "\"\(sref.prefix(24)) ...\""
        } else {
          self.fname = "\"\(sref)\""
        }
        //        st.inp = .ST_STRING(Substring(sref))
        self.inp.type = .ST_STRING
        self.inp.string = Substring(sref)
        // goto again
        return true
    }
    
  }
  
  
  
  /**
   * cu_fgets: like fgets, but reads from the chain of compilation units, ignoring empty strings/files.
   * Fills `buf` with up to `n` characters. If `more` is non-nil, it’s set to 1 if more data might be available, else 0.
   */
  func cu_fgets(_ options : inout sed.CommandOptions) async throws(CmdErr) -> String? {
    
    again: while true {
      switch self.inp.type {
        case .ST_EOF:
          if try next_file(options) { continue again }
          else { return nil}
          
        case .ST_FILE:
          do {
            // FIXME: this ai.next() prevents me being an actor, because it is a mutable method
            if let got = try await self.inp.ai.next() {
              self.linenum += 1
              if self.linenum == 1 && got.hasPrefix("#n") {
                self.nflag = true
                options.nflag = true
                continue
              }
              return got
            }
            
            try self.inp.fh?.close()
            self.inp.type = .ST_EOF
            continue again
          } catch {
            throw CmdErr(1, "reading \(self.fname): \(error)")
          }
        case .ST_STRING:
          if self.linenum == 0,
             self.inp.string.hasPrefix("#n") {
            self.nflag = true
            options.nflag = true
            continue
          }
          if self.inp.string.isEmpty {
            self.inp.type = .ST_EOF
            continue again
          }
          let sPtr = self.inp.string.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
          if sPtr.count == 2 {
            self.inp.string = sPtr[1]
            return String(sPtr[0])
          } else if sPtr.count == 1 {
            self.inp.string = ""
            self.inp.type = .ST_EOF
            return String(sPtr[0])
          } else {
            fatalError("not possible")
          }
      }
    }
  }
  
}
