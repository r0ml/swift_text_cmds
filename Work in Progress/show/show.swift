// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025



// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

import Foundation
import CMigration
import Compression

final class show : ShellCommand {
  
  var usage : String = "Not yet implemented"
  
  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    var options = CommandOptions()
    let supportedFlags = "belnstuv"
    let go = BSDGetopt(supportedFlags)
    
    while let (k, _) = try go.getopt() {
      switch k {
        default: throw CmdErr(1)
      }
    }
    options.args = go.remaining
    return options
  }
  
  func runCommand(_ options: CommandOptions) throws(CmdErr) {
    for i in options.args {
      do {
        let fh = try FileHandle(forReadingFrom: URL(fileURLWithPath: i))
        let ff = try fh.read(upToCount: 6)
        let ft = detectCompressionAlgorithm(from: ff!)
        try fh.seek(toOffset: 0)
        let fl = try InputFilter(.decompress,
                                 using: ft!) { (length: Int) -> Data? in
          try fh.read(upToCount: length)
        }
        let pageSize = 1024 * 1024
        while let page = try fl.readData(ofLength: pageSize) {
          FileHandle.standardOutput.write(page)
        }
        
      } catch {
        throw CmdErr(1, "reading \(i): \(error.localizedDescription)")
      }
    }
  }
  
  func detectCompressionAlgorithm(from data: Data) -> Algorithm? {
    //        guard data.count >= 6 else { return .unknown }
    
    // Check bzip2 (magic number: BZ)
    //        if data.starts(with: [0x42, 0x5A]) { // ASCII "BZ"
    //            return .bzip2
    //        }
    
    // Check gzip (magic number: 1F 8B)
    if data.starts(with: [0x1F, 0x8B]) {
      return .zlib
    }
    
    // Check lzma (magic number: 5D 00 00 80)
    if data.starts(with: [0x5D, 0x00, 0x00, 0x80]) {
      return .lzma
    }
    
    // Check xz (magic number: FD 37 7A 58 5A 00)
    if data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
      return .lzma
    }
    
    // Check lzfse (magic number: bvx2)
    if data.starts(with: [0x62, 0x76, 0x78, 0x32]) { // ASCII "bvx2"
      return .lzfse
    }
    
    // Check lz4 (magic number: 04 22 4D 18)
    if data.starts(with: [0x04, 0x22, 0x4D, 0x18]) {
      return .lz4
    }
    
    // Check brotli (magic number: CE B2 CF 81)
    if data.starts(with: [0xCE, 0xB2, 0xCF, 0x81]) {
      return .brotli
    }
    
    // Check lzbitmap (magic number: LZI)
    if data.starts(with: [0x4C, 0x5A, 0x49]) { // ASCII "LZI"
      return .lzbitmap
    }
    
    fatalError("unknown format")
    // Unknown format
    return nil
  }
  
}

