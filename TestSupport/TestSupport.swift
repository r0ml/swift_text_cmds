
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

@_exported import Foundation
import Synchronization

public actor ShellProcess {
  //  var executable: String
  //  var args: [String]
  //  var env : [String:String]
  var process : Process = Process()
  var output : Pipe = Pipe()
  var stderrx : Pipe = Pipe()

  var writeok = true
//  var odat = Data()
  var edat : String? = nil
  
  let ooo = Mutex(Data())
  
  public func interrupt() {
    defer {
      cleanup()
    }
    process.interrupt()
  }
  
  public init(_ executable: String, _ args : String..., env: [String: String] = [:]) {
    self.init(executable, args, env: env)
  }
  
  public init(_ ex: String, _ args : [String], env: [String:String] = [:]) {
    //    self.executable = executable
    //    self.args = args
    var envx = ProcessInfo.processInfo.environment
    env.forEach { envx[$0] = $1 }

    var execu : URL? = nil
    if true { // let _ = envx["TEST_ORIGINAL"] {
      let path = envx["PATH"]!.split(separator: ":", omittingEmptySubsequences: true)
      let f = FileManager.default
      for d in path {
        if f.isExecutableFile(atPath: d+"/"+ex) {
          execu = URL(fileURLWithPath: ex, relativeTo: URL(filePath: String(d), directoryHint: .isDirectory))
          break
        }
      }
    } else {
      let d = Bundle(for: Self.self).bundleURL
      let x1 = d.deletingLastPathComponent()
      execu = x1.appending(path: ex, directoryHint: .notDirectory)
    }
    
    process.arguments = args
    process.environment = envx
    process.currentDirectoryURL = FileManager.default.temporaryDirectory
    process.executableURL = execu!
    process.standardOutput = output
  }
  
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func   captureStdoutLaunch(_ input : String) async throws -> (Int32, String?, String?) {
    return try await captureStdoutLaunch(input.data(using: .utf8)! )
  }
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func captureStdoutLaunch(_ input : [String]) async throws -> (Int32, String?, String?) {
    return try await captureStdoutLaunch(input.map { $0.data(using: .utf8)! } )
  }
  
  

  
  // ============================================================
  // passing in bytes instead of strings ....
  
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func captureStdoutLaunch( _ input : Data) async throws -> (Int32, String?, String?) {
    let asi = AsyncDataActor([input]).stream
    return try await captureStdoutLaunch(asi)
  }
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func captureStdoutAsData( _ input : Data) async throws -> (Int32, Data, String) {
    let asi = AsyncDataActor([input]).stream
    return try await captureStdoutAsData(asi)
  }
  
  

  // ==========================================================
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func captureStdoutLaunch(_ input : [Data]) async throws -> (Int32, String?, String?) {
    let asi = AsyncDataActor(input).stream
    return try await captureStdoutLaunch(asi)
  }
  
  
  // ==========================================================
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func captureStdoutLaunch(_ input : AsyncStream<Data>? = nil) async throws -> (Int32, String?, String?) {
    
    try theLaunch(input)
    return await theCapture()
  }

  @discardableResult
  public func captureStdoutAsData(_ input : AsyncStream<Data>? = nil) async throws -> (Int32, Data, String) {
    try theLaunch(input)
    return await theCaptureAsData()
  }

  
  @discardableResult
  public func captureStdoutLaunch(_ input : FileHandle) async throws -> (Int32, String?, String?) {
    
    try theLaunch(input)
    return await theCapture()
  }
    
  public func setOutput(_ o : FileHandle) {
    process.standardOutput = o
    try? output.fileHandleForWriting.close()
  }

  public func theLaunch(_ input : FileHandle) throws {

    process.standardInput = input
    process.standardError = stderrx
    
    output.fileHandleForReading.readabilityHandler = { x in
//        let xx = x.availableData
//        if xx.isEmpty { return }
      self.ooo.withLock { $0.append(x.availableData) }
//        self.append(xx)
    }
    
    process.terminationHandler = { x in
      Task {
        await self.doTermination()
      }
    }

    do {
      try process.run()
    } catch(let e) {
      print(e.localizedDescription)
      throw e
    }
  }
  
  
  
  
  public func theLaunch(_ input : AsyncStream<Data>? = nil) throws {

    let inputs : Pipe? = if input != nil { Pipe() } else { nil }

    process.standardInput = inputs


/*
    let p = self.process
    Task.detached {
      try await Task.sleep(nanoseconds: UInt64( Double(NSEC_PER_SEC) * 2 ) )
      //    print("gonna interrupt")
//      p.interrupt()
    }
 */
    process.standardError = stderrx
    
    output.fileHandleForReading.readabilityHandler = { x in
//      let xx = x.availableData
//      if xx.isEmpty { return }
//      Task.detached { await self.append(xx) }
      self.ooo.withLock { $0.append(x.availableData) }
    }
    
    process.terminationHandler = { x in
      Task {
        await self.doTermination()
      }
    }

    if let inputs, let input {
      Task.detached {
        for await d in input {
            if await self.writeok {
              do {
                try inputs.fileHandleForWriting.write(contentsOf: d )
              } catch(let e) {
                print("writing \(e.localizedDescription)")
                break
              }
            }
        }
        try? inputs.fileHandleForWriting.close()
        try? inputs.fileHandleForReading.close()
      }
    }
    
    do {
      try process.run()
    } catch(let e) {
      print(e.localizedDescription)
      throw e
    }
  }
  
  func doTermination() async {
    self.stopWriting()
    do {
      if let d = try self.stderrx.fileHandleForReading.readToEnd() {
        self.setError( String(data: d, encoding: .utf8) )
      }
      if let k3 = try self.output.fileHandleForReading.readToEnd() {
        self.append(k3)
      }
    } catch(let e) {
      print("doTermination: ",e.localizedDescription)
    }
    self.cleanup()
  }
  
  func stopWriting() {
    writeok = false
  }
  
  public func midCapture() -> Data {
 
//    let k = output.fileHandleForReading.availableData
//    if k.count > 0 {
//      append(k)
//    }

    return ooo.withLock { $0 }
//    return odat
  }

//  let ooo = Mutex(Data())
  
  public func append(_ x : Data) {
    // odat.append(x)
    ooo.withLock { $0.append(x) }
  }
  
  public func setError(_ x : String?) {
    edat = x
  }
  
  public func theCapture() async -> (Int32, String?, String?) {
    //    process.waitUntilExit()
    await process.waitUntilExitAsync()
//    let k1 = String(data: odat, encoding: .utf8)
    let k1 = String(data: ooo.withLock { $0 }, encoding: .utf8)
    return (process.terminationStatus, k1, edat)
  }
  
  public func theCaptureAsData() async -> (Int32, Data, String ) {
    //    process.waitUntilExit()
    await process.waitUntilExitAsync()
    let k1 = ooo.withLock { $0 }
    return (process.terminationStatus, k1, edat ?? "")
  }

  
  
  func cleanup() {
    try? output.fileHandleForWriting.close()
    try? output.fileHandleForReading.close()
    try? stderrx.fileHandleForReading.close()
    try? stderrx.fileHandleForWriting.close()
  }
}
  
  
  // ==========================================================
  
class Clem {}

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
  

public final actor AsyncDataActor {
  var d : [Data]
  var delay : Double
  var first = true
  
  public init(_ d : [Data], delay : Double = 0.5) {
    self.d = d
    self.delay = delay
  }
  
  func consumeD() -> Data? {
    if self.d.isEmpty { return nil }
    let d = self.d.removeFirst()
    return d
  }
  
  func notFirst() {
    self.first = false
  }
  
  public nonisolated var stream : AsyncStream<Data> {
    return AsyncStream(unfolding: {
      if await self.first {
        await self.notFirst()
      } else {
        try? await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC) * self.delay) )
      }
      let d = await self.consumeD()
      return d
    })
  }
}

public func tmpfile(_ s : String, _ data : Data? = nil) throws -> URL {
  let j = FileManager.default.temporaryDirectory.appending(path: s, directoryHint: .notDirectory)
  if let data { try data.write(to: j) }
  return j
}

public func tmpfile(_ s : String, _ data : String) throws -> URL {
  return try tmpfile(s, data.data(using: .utf8))
}

public func rm(_ s : URL) {
  try? FileManager.default.removeItem(at: s)
}

public func rm(_ s : [URL]) {
  s.forEach { rm($0) }
}

public func rm( _ s : URL...) {
  rm(s)
}

extension Process {
    func waitUntilExitAsync() async {
        await withCheckedContinuation { c in
          let t = self.terminationHandler
            self.terminationHandler = { _ in
              t?(self)
              c.resume()
            }
        }
    }
}


func numberStream() -> AsyncStream<Int> {
    return AsyncStream { continuation in
        for number in 1...100 {
            continuation.yield(number)
        }
        continuation.finish()
    }
}

