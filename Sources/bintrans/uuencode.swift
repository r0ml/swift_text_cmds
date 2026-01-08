
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-3-Clause
 
  Copyright (c) 1983, 1993
   The Regents of the University of California.  All rights reserved.
 
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

extension bintrans {
  func main_base64_encode(_ inp : String?, _ outp : String?,  _ w : String?, _ options : inout CommandOptions) throws(CmdErr) {
    options.raw = true
    
    var infp = FileDescriptor.standardInput
    var name = "stdin"
    
    if let inp, inp != "-" {
      name = inp
        //      let u = URL(filePath: inp)
      do {
        let xinfp = try FileDescriptor(forReading: inp)
        infp = xinfp
      } catch(let e) {
        throw CmdErr(1, "\(inp): Permission denied \(e))")
      }
    }

    var outfp = FileDescriptor.standardOutput
    if let outp, outp != "-"  {
//      let u = URL(filePath: outp)
      do {
        
        // FIXME: does it work both ways?
        let xoutfp = try FileDescriptor.open(outp, .writeOnly, options: [.create], permissions: [.ownerReadWrite])
        outfp = xoutfp
      } catch(let e) {
        throw CmdErr(1, "\(outp): Permission denied (\(e))")
      }
    }
    
    if let w {
      options.columns = try arg_to_col(w)
    }
    
    var d = Decoder(options: options)
    if inp == nil {
      d.inHandle = FileDescriptor.standardInput
      d.inFile = "stdin"
    } else {
      d.inHandle = infp
      d.inFile = inp!
    }
    if outp == nil {
      d.outFile = "stdout"
      d.outHandle = FileDescriptor.standardOutput
    } else {
      d.outHandle = outfp
      d.outFile = outp!
    }
    
    
    // FIXME: why no mode here?
    try base64_encode(d, mode: [.ownerReadWrite, .groupRead, .otherRead], name: name)
    do {
      try outfp.close()
    } catch(let e) {
      throw CmdErr(1, "closing output: \(e)")
    }
  }
  
  func parseOptions_encode(_ options : inout CommandOptions, _ bintflag : Bool) throws(CmdErr) {

    options.base64 = false;
    options.columns = 76
    
//    if (strcmp(basename(argv[0]), "b64encode") == 0) {
    if options.progname == "b64encode" {
      options.base64 = true
    }
    
    let go = BSDGetopt("mo:rw:", args: CommandLine.arguments.dropFirst(bintflag ? 2 : 1))
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "m":
          options.base64 = true
        case "o":
          options.outFile = v
        case "r":
          options.raw = true
        case "w":
          options.columns = try arg_to_col(v)
        case "?":
          fallthrough
        default:
          throw CmdErr(1, encode_usage)
      }
    }
    options.args = go.remaining
  }
  
  func main_encode() throws(CmdErr) {
    var fh = FileDescriptor.standardInput
    var mode : FilePermissions = [.ownerReadWrite, .groupRead, .otherRead]
    var name : String = "stdin"
    var d = Decoder(options: options)
    switch options.args.count {
      case 2:      // optional first argument is input file
        do {
          name = options.args[0]
          fh = try FileDescriptor(forReading: options.args[0])
        } catch(let e) {
          throw CmdErr(1, "opening input file \(options.args[0]): \(e)")
        }
//        var sb = Darwin.stat()
//        fstat(fh.rawValue, &sb)


        if let sb = try? FileMetadata(for: fh) {

          //        let RWX = S_IRWXU|S_IRWXG|S_IRWXO
          mode = sb.permissions
        }

      case 1:
//        let RW = S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH
//        RW & ~umask(RW)
        mode = [.ownerReadWrite, .groupRead, .otherRead]
        name = options.args[0]
      default:
        throw CmdErr(1, encode_usage)
    }
    
    d.inHandle = fh
    d.inFile = name
    
    var ofh = FileDescriptor.standardOutput
    
    if let oof = options.outFile {
      d.outFile = oof
      do {
        ofh = try FileDescriptor(forWriting: oof)
      } catch(let e) {
        throw CmdErr(1, "unable to open \(oof) for output: \(e)")
      }
    }
    d.outHandle = ofh

    if (options.base64) {
      try base64_encode(d, mode: mode, name: name)
    }
    else {
      try encode(d, mode: mode, name: name)
    }
    do {
      try ofh.close()
    } catch(let e) {
      throw CmdErr(1, "write error: \(e)")
    }
  }
  
  /* ENC is the basic 1 character encoding function to make a char printing */
  func ENC(_ c : UInt8) -> Character {
    return c == 0 ? "`" : Character(UnicodeScalar( c & 0x3f + 0x20 ))
  }
  
  /*
   * Copy from in to out, encoding in base64 as you go along.
   */
  func base64_encode(_ d : Decoder, mode : FilePermissions, name av : String) throws(CmdErr) {
    /*
     * This buffer's length should be a multiple of 24 bits to avoid "="
     * padding. Once it reached ~1 KB, further expansion didn't improve
     * performance for me.
     */
//    unsigned char buf[1023];
//    char buf2[sizeof(buf) * 2 + 1];
//    size_t n;
 //    var written = 0
    
    //    size_t rv, written;
    
    if (!d.options.raw) {
      d.outHandle.write("begin-base64 \(cFormat("%lo", mode.rawValue)) \(av)\n");
    }
    
    var carry = 0
    do {
      while true {
        
        var buf = try d.inHandle.readUpToCount(1023)
        if buf.isEmpty { break }
        let buf2 = apple_b64_ntop(&buf)
        
        //      if (rv == -1) {
        //        errx(1, "b64_ntop: error encoding base64");
        //      }
        if (d.options.columns == 0) {
          d.outHandle.write(buf2)
          continue;
        }
        
        var i = 0
        let cols = d.options.columns
        while i < buf2.count {
          let buf3 = buf2.dropFirst(i).prefix(cols-carry)
          d.outHandle.write(String(buf3))
          
          carry = (carry + buf3.count) % cols
          if (carry == 0) {
            d.outHandle.write("\n")
          }
          i += buf3.count
        }
      }
    } catch(let e) {
      // FIXME: include file name in error message
      throw CmdErr(1, "read error: \(e)")
    }
    if (d.options.columns == 0 || carry != 0) {
      d.outHandle.write("\n")
    }
    if (!d.options.raw) {
      d.outHandle.write("====\n")
    }
  }
  
  /*
   * Copy from in to out, encoding as you go along.
   */
  func encode(_ d : Decoder, mode: FilePermissions, name av: String) throws(CmdErr) {
//    ssize_t n;
//    int ch;
    
//    char *p;
//    char buf[80];
    
    if (!d.options.raw) {
      d.outHandle.write("begin \(cFormat("%lo", mode.rawValue)) \(av)\n")
    }
    do {
      while true {
        
      var buf = try d.inHandle.readUpToCount(45)
        if buf.isEmpty { break }
      var ch = ENC( UInt8(buf.count))
        d.outHandle.write(String(ch))
      while !buf.isEmpty {
        /* Pad with nulls if not a multiple of 3. */
        var p = buf.prefix(3)
        buf.removeFirst(p.count)
        while p.count < 3 { p.append(0) }

        var chx = p[0] >> 2;
        ch = ENC(chx);
        d.outHandle.write(String(ch))
        chx = ((p[0] << 4) & 0x30) | ((p[1] >> 4) & 0x0f);
        ch = ENC(chx);
        d.outHandle.write(String(ch))
        chx = ((p[1] << 2) & 0x3c) | ((p[2] >> 0x06) & 0x03);
        ch = ENC(chx);
        d.outHandle.write(String(ch))
        chx = p[2] & 0x3f
        ch = ENC(chx);
        d.outHandle.write(String(ch))
      }
        d.outHandle.write("\n")
    }
      try d.inHandle.close()
    } catch(let e) {
      throw CmdErr(1, "read error: \(e)")
    }
    if (!d.options.raw) {
      print("\(ENC(0))\nend")
    }
  }
  
  func arg_to_col(_ w : String) throws(CmdErr) -> Int {
 //   char *ep;
//    long option;
    
//    errno = 0;
    var option : Int
    if let x = Int(w) {
      option = x
    } else {
      throw CmdErr(2, "invalid integer: \(w)")
    }
    if (option < 0) {
      throw CmdErr(2, "columns argument must be non-negative")
    }
    
    return option
  }
  
  var encode_usage : String { "usage: uuencode [-m] [-o outfile] [inFile] remotefile" }
}
