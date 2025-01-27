
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*
  SPDX-License-Identifier: BSD-2-Clause
 
  Copyright (c) 2022 The FreeBSD Foundation
 
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
import CMigration

@main final class bintrans : ShellCommand {

  var usage : String = """
Usage:  base64 [-Ddh] [-b num] [-i in_file] [-o out_file]
  -b, --break       break encoded output up into lines of length num
  -D, -d, --decode  decode input
  -h, --help        display this message
  -i, --input       input file (default: \"-\" for stdin)
  -o, --output      output file (default: \"-\" for stdout)
"""

  
  struct CommandOptions {
    var progname : String = "?"
    var encode = false
    var iflag = false
    var sflag = false
    var oflag = false
    var rflag = false
    var pflag = false
    var cflag = false
    var columns : Int = 0
    var raw = false
    var base64 = false
    var coder : coders = .base64
    var outFile : String?
    var inFile : String?
    var w : String?
    var decode = false
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    //    let supportedFlags = "belnstuv"
    //    let go = BSDGetopt(supportedFlags)
    
    var bintflag = false
    options.progname = String(cString: getprogname())
    if options.progname == "bintrans" && CommandLine.arguments.count > 1 {
      options.progname = CommandLine.arguments[1]
      bintflag = true
    }
    if let coder = search(options.progname) {
      options.coder = coder
      switch coder {
        case .uuencode, .b64encode:
          try parseOptions_encode(&options, bintflag)
        case.uudecode, .b64decode:
          try parseOptions_decode(&options, bintflag)
        case .base64:
          try parseOptions_base64_encode_or_decode(&options, bintflag)
        case .qp:
          try parseOptions_quotedprintable(&options, bintflag)
      }
    } else {
      throw CmdErr(1, """
usage: [bintrans] <uuencode | uudecode> ...
   [bintrans] <b64encode | b64decode> ...
   [bintrans] <base64> ...
   [bintrans] <qp> ...
""")

    }
    return options
  }
    
  func parseOptions_base64_encode_or_decode(_ options : inout CommandOptions, _ bintflag : Bool) throws(CmdErr) {

    let oo : [CMigration.option] = [
      .init("decode", .no_argument),
      .init("break", .required_argument),
      .init("breaks", .required_argument),
      .init("input", .required_argument),
      .init("output", .required_argument),
      .init("wrap", .required_argument),
      .init("help", .no_argument),
      .init("version", .no_argument),
    ]
    
    let go = BSDGetopt_long("b:Ddhi:o:w:", oo, Array(CommandLine.arguments.dropFirst(bintflag ? 2 : 1)))

    
    while let (k, v) = try go.getopt_long() {
      switch k {
        case "D", "d", "decode":
          options.decode = true
        case "b", "w", "break", "breaks", "wrap":
          options.w = v
        case "i", "input":
          options.inFile = v
        case "o", "output":
          options.outFile = v
        case "version":
          FileHandle.standardError.write("FreeBSD base64\n")
          exit(0)
        case "h", "help":
          print(usage)
          exit(0)
        case "?":
          throw CmdErr(1)
        default:
          print(usage)
          exit(0)
      }
    }
    options.args = go.remaining
    if !options.args.isEmpty {
      warnx("invalid argument \(options.args[0])")
      throw CmdErr(1)
    }
  }
  
  func runCommand(_ options: CommandOptions) async throws(CmdErr) {
    var xoptions = options
    switch options.coder {
      case .base64:
        if options.decode {
          try await main_base64_decode(options.inFile, options.outFile, &xoptions)
        } else {
          try main_base64_encode(options.inFile, options.outFile, options.w, &xoptions)
        }
//        throw CmdErr(1, usage)
      case .uuencode, .b64encode:
        try main_encode(options)
      case .uudecode, .b64decode:
        try await main_decode(options)
      case .qp:
        try await main_quotedprintable(options)
    }
  }
  
  enum coders : String, CaseIterable {
    case uuencode
    case uudecode
    case b64encode
    case b64decode
    case base64
    case qp
    
    init?(_ name : String) {
      switch name {
        case "uuencode":  self = .uuencode
          case "uudecode":  self = .uudecode
          case "b64encode":  self = .b64encode
          case "b64decode":  self = .b64decode
        case "base64":  self = .base64
        case "qp":  self = .qp
        default:
          return nil
      }
    }
  }
  
  func search(_ progname : String) -> coders? {
    return coders(progname)
  }

}
