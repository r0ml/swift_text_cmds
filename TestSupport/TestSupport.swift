
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
import Testing

public actor ShellProcess {
  var process : Process = Process()
  var output : Pipe = Pipe()
  var stderrx : Pipe = Pipe()
  
  var writeok = true
  var edat : String? = nil
  
  let odat = Mutex(Data())
  
  public func interrupt() {
    defer {
      cleanup()
    }
    process.interrupt()
  }
  
  public init(_ executable: String, _ args : Arguable..., env: [String: String] = [:], cd: URL? = nil) {
    self.init(executable, args, env: env, cd: cd)
  }
  
  public init(_ ex: String, _ args : [Arguable], env: [String:String] = [:], cd: URL? = nil) {
    var envx = ProcessInfo.processInfo.environment
    env.forEach { envx[$0] = $1 }
    
    var execu : URL? = nil
    // FIXME: test for TEST_ORIGINAL
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
      execu = URL(string: ex, relativeTo: x1)
    }
    

    let cur = cd ?? FileManager.default.temporaryDirectory

    let aargs = args.map {
      switch $0 {
        case is String: return $0 as! String
        case is URL: let u = $0 as! URL
          if u.baseURL == cur.absoluteURL {
            return u.relativePath
          } else {
            return u.path
          }
        default: fatalError( "not possible")
      }
    }
    
    process.arguments = aargs
    process.environment = envx
    process.currentDirectoryURL = cur
    process.executableURL = execu!
    process.standardOutput = output
  }
  
/*  public func setDirectory(_ dir : URL) {
    process.currentDirectoryURL = dir
  }
  */
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func   run(_ input : String?) async throws -> (Int32, String?, String?) {
    return try await run( input?.data(using: .utf8)! )
  }
  
  // ============================================================
  // passing in bytes instead of strings ....
  
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func run( _ input : Data?) async throws -> (Int32, String?, String?) {
    let asi = if let input { AsyncDataActor([input]).stream }
    else { nil as AsyncStream<Data>?}
    return try await run(asi)
  }
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  @discardableResult
  public func runBinary( _ input : Data) async throws -> (Int32, Data, String) {
    let asi = AsyncDataActor([input]).stream
    return try await runBinary(asi)
  }
  
  // ==========================================================
  
  /// Returns the output of running `executable` with `args`. Throws an error if the process exits indicating failure.
  ///  The easiest way to generate the required AsyncStream is with:
  ///      AsyncDataActor(input).stream // where input : [Data]
  @discardableResult
  public func run(_ input : AsyncStream<Data>? = nil) async throws -> (Int32, String?, String?) {
    try theLaunch(input)
    return await theCapture()
  }
  
  @discardableResult
  public func runBinary(_ input : AsyncStream<Data>? = nil) async throws -> (Int32, Data, String) {
    try theLaunch(input)
    return await theCaptureAsData()
  }
  
  
  @discardableResult
  public func run(_ input : FileHandle) async throws -> (Int32, String?, String?) {
    
    try theLaunch(input)
    return await theCapture()
  }

  /*
  public func setOutput(_ o : FileHandle) {
    process.standardOutput = o
    try? output.fileHandleForWriting.close()
  }
  */
  
  public func theLaunch(_ input : FileHandle) throws {
    
    process.standardInput = input
    process.standardError = stderrx
    
    output.fileHandleForReading.readabilityHandler = { x in
      self.odat.withLock { $0.append(x.availableData) }
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
    process.standardError = stderrx
    
    output.fileHandleForReading.readabilityHandler = { x in
      self.odat.withLock { $0.append(x.availableData) }
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
    return odat.withLock { let r = $0; $0.removeAll(); return r }
  }
  
  public func append(_ x : Data) {
    odat.withLock { $0.append(x) }
  }
  
  public func setError(_ x : String?) {
    edat = x
  }
  
  public func theCapture() async -> (Int32, String?, String?) {
    await process.waitUntilExitAsync()
    let k1 = String(data: odat.withLock { $0 }, encoding: .utf8)
    return (process.terminationStatus, k1, edat)
  }
  
  public func theCaptureAsData() async -> (Int32, Data, String ) {
    await process.waitUntilExitAsync()
    let k1 = odat.withLock { $0 }
    return (process.terminationStatus, k1, edat ?? "")
  }
  
  func cleanup() {
    try? output.fileHandleForWriting.close()
    try? output.fileHandleForReading.close()
    try? stderrx.fileHandleForReading.close()
    try? stderrx.fileHandleForWriting.close()
  }
  
  static public func run(_ ex : String, withStdin: Stdinable? = nil, status: Int = 0,  output: String? = nil, error: String? = nil, args: Arguable...) async throws {
    try await run(ex, withStdin: withStdin, output: output, args: args)
  }
  
  static public func run(_ ex : String, withStdin: Stdinable? = nil, status: Int = 0, output: String? = nil, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: URL? = nil) async throws {
    let p = ShellProcess(ex, args, env: env, cd: cd)
    let (r, j, e) = switch withStdin {
    case is String:
      try await p.run(withStdin as? String)
    case is Data:
      try await p.run(withStdin as? Data)
    case is FileHandle:
      try await p.run(withStdin as! FileHandle)
    case is AsyncStream<Data>:
      try await p.run(withStdin as? AsyncStream<Data>)
    case .none:
      try await p.run()
    default:
      fatalError("not possible")
    }
    #expect(r == Int32(status), Comment(rawValue: e ?? ""))
    if let output { #expect(j == output) }
    if let error {
      if let e {
        switch error {
          case is String:
            #expect(e == error as? String)
          case is Regex<String>:
            let ee = error as! Regex<String>
            #expect( e.matches(of: ee).count > 0, Comment(rawValue: "\(e) does not match expected error"))
          case is Regex<Substring>:
            let ee = error as! Regex<Substring>
            #expect( e.matches(of: ee).count > 0, Comment(rawValue: "\(e) does not match expected error"))
          default: fatalError("not possible")
        }
      }
    }
  }
  
  
  static public func run(_ ex : String, withStdin: Stdinable? = nil, status: Int = 0, output: Data, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: URL? = nil) async throws {
    let p = ShellProcess(ex, args, env: env, cd: cd)
    let (r, j, e) = switch withStdin {
//    case is String:
//      try await p.runBinary(withStdin as? String)
    case is Data:
      try await p.runBinary(withStdin as! Data)
//    case is FileHandle:
//      try await p.runBinary(withStdin as! FileHandle)
    case is AsyncStream<Data>:
      try await p.runBinary(withStdin as? AsyncStream<Data>)
    case .none:
      try await p.runBinary()
    default:
      fatalError("not possible")
    }
    #expect(r == Int32(status), Comment(rawValue: e ?? ""))
    #expect(j == output)
    if let error {
        switch error {
          case is String:
            #expect(e == error as? String)
          case is Regex<String>:
            let ee = error as! Regex<String>
            #expect( e.matches(of: ee).count > 0, Comment(rawValue: "\(e) does not match expected error"))
          case is Regex<Substring>:
            let ee = error as! Regex<Substring>
            #expect( e.matches(of: ee).count > 0, Comment(rawValue: "\(e) does not match expected error"))
          default: fatalError("not possible")
      }
    }
  }

  
  
}
  
public protocol Stdinable {}
extension String : Stdinable {}
extension Data : Stdinable {}
extension FileHandle : Stdinable {}
extension AsyncStream : Stdinable {}

public protocol Arguable : Sendable {}
extension String : Arguable {}
extension URL : Arguable {}

public protocol Matchable {}
extension String : Matchable {}
extension Regex : Matchable {}

  // ==========================================================
  
public enum StringEncodingError: Error {
    case only(String.Encoding)
}

public enum FileError: Error {
  case notFound(String)
}

class Clem {}

  /// try fileContents. Opens a file in the current bundle and return as data
  /// - Parameters:
  ///   - name: fileName
  /// - Returns: Data of the contents of the file on nil if not found
  public func fileContents(_ suite: String, _ name: String) throws -> String {
    let url = try geturl(suite, name)
    let data = try Data(contentsOf: url)
    guard let res = String(data: data, encoding: .utf8) else {
      throw StringEncodingError.only(.utf8)
    }
    return res
  }

public func fileData(_ suite: String, _ name: String) throws -> Data {
  let url = try geturl(suite, name)
  let data = try Data(contentsOf: url)
  return data
}

  // returns the full name of a test resource file
  public func inFile(_ suite : String, _ name : String) throws -> URL {
    return try geturl(suite, name)
  }
  
  public func geturl(_ suite : String, _ name : String? = nil) throws -> URL {
    var url : URL?
    if let _ = ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] {
      let ru = Bundle(for: Clem.self).resourceURL
      if let name {
        url = URL(fileURLWithPath: name, relativeTo: ru)
      } else {
        url = ru
      }
    } else {
      let b = Bundle(for: Clem.self)
      url = b.bundleURL.deletingLastPathComponent().appending(path: "text_cmds_\(suite).bundle").appending(path: "Resources")
      if let name {
        url = url?.appending(path: name)
      }
    }
    if let url { return url }
    throw FileError.notFound(name ?? "")
    
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
  let j = URL(string: s, relativeTo: FileManager.default.temporaryDirectory)!

  try FileManager.default.createDirectory(at: j.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
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

public protocol ShellTest {
  var cmd : String { get }
  var suite : String { get }
}

extension ShellTest {
  
  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: String? = nil, error: Matchable? = nil, args: Arguable..., env: [String:String] = [:], cd: URL? = nil) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd)
  }

  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: String? = nil, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: URL? = nil) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd)
  }


  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: Data, error: Matchable? = nil, args: Arguable..., env: [String:String] = [:], cd: URL? = nil) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd)
  }

  public func run(withStdin: Stdinable? = nil, status: Int = 0, output: Data, error: Matchable? = nil, args: [Arguable], env: [String:String] = [:], cd: URL? = nil) async throws {
    try await ShellProcess.run(cmd, withStdin: withStdin, status: status, output: output, error: error, args: args, env: env, cd: cd)
  }


  
  
  
  
  public func fileContents(_ name : String) throws -> String {
    return try TestSupport.fileContents(suite, name)
  }
  
  public func inFile(_ name : String) throws -> URL {
    return try TestSupport.inFile(suite, name)
  }

}
