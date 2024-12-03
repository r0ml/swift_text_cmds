
/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation

/// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
@discardableResult
public func captureStdoutLaunch(_ c : AnyClass?, _ executable: String, _ args: [String], _ input : String? = nil,
                                _ env : [String:String] = ProcessInfo.processInfo.environment) throws -> (Int32, String?, String?) {
  let process = Process()
  let output = Pipe()
  let stderr = Pipe()
  
  let inputs : Pipe? = if input != nil { Pipe() } else { nil }
  
  var execu : String
  if let c {
    let d = Bundle(for: c).bundleURL
    execu = d.deletingLastPathComponent().appending(component: executable).path(percentEncoded:false)
  } else {
    execu = executable
  }
  
//  print("launchPath \(execu)")
  
  process.launchPath = execu
  process.arguments = args
  process.standardOutput = output
  process.standardInput = inputs
  process.standardError = stderr
  process.environment = env
  
//  print(execu)
  
  process.launch()

//  print("launched \(args)")
  
  var writeok = true
  
  if let inputs, let input {
    Task.detached {
      if writeok {
//        print("writing \(args)")
        inputs.fileHandleForWriting.write( input.data(using: .utf8) ?? Data() )
        try? inputs.fileHandleForWriting.close()
      }
    }
  }
  
  Task.detached {
    try await Task.sleep(nanoseconds: UInt64( Double(NSEC_PER_SEC) * 2 ) )
//    print("gonna interrupt")
    process.interrupt()
  }
  
  process.waitUntilExit()
    writeok = false
//  print("finished waiting \(args)")
  
  let k1 = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
  let k2 = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
  return (process.terminationStatus, k1, k2)

}


public class Clem {}

/// getFile. Opens a file in the current bundle and return as data
/// - Parameters:
///   - name: fileName
///   - withExtension: extension name, i.e. "json"
/// - Returns: Data of the contents of the file on nil if not found
public func getFile(_ suite: String, _ name: String, withExtension: String) -> String? {
//  print("gf")
//  print(Bundle(for: Clem.self))
//  guard let url = Bundle(for: Clem.self).url(forResource: name, withExtension: withExtension) else { return nil }
//  print(url)

//  print(Bundle.allBundles)

  
//  let url = Bundle(for: Clem.self).bundleURL
//  print(Bundle(for: Clem.self).resourceURL)
//  print( Bundle(identifier: "software.tinker.applyTest")?.resourceURL )

  let url = geturl(suite, name, withExtension: withExtension)
  guard let data = try? Data(contentsOf: url) else { return nil }
//  print("gf3")
  return String(data: data, encoding: .utf8)
}

// returns the full name of a test resource file
public func inFile(_ suite : String, _ name : String, withExtension: String) -> String? {
  let url = geturl(suite, name, withExtension: withExtension)
  return url.path(percentEncoded: false)
}

func geturl(_ suite : String, _ name : String, withExtension : String) -> URL {
  var url : URL?
  if let _ = ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] {
//    print("xctest identifier")
    url = Bundle(for: Clem.self).url(forResource: name, withExtension: withExtension)
  } else {
    
    let b = Bundle(for: Clem.self)
//    print(b)
    //    let bi = b.bundleIdentifier!.split(separator: ".").last!
    //    print(bi)
    url = b.bundleURL.deletingLastPathComponent().appending(path: "text_cmds_\(suite).bundle").appending(path: "Resources")
      .appending(path: name).appendingPathExtension(withExtension)
  }
  return url!
  
}
