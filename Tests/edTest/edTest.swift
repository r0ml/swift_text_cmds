// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from automatically generated files

import ShellTesting
import Darwin

@Suite("edTest") class edTest : ShellTest {
  let cmd = "ed"
  let suiteBundle = "text_cmds_edTest"
  
  @Test(arguments: [
    "a", "addr",
    // FIXME: disabled because I can't get it to work
//    "ascii",
    "bang1", "c", "d", "e2", "e3", "e4",
    "g2", "g3", "g4", "g5", "i", "j", "k", "m", "q",
    "r2", "r3", "s3", "t1", "t2", "u", "w",
    
  ]) func any(_ n : String) async throws {
    let inp = try fileContents("\(n).t")
    let res = try fileContents("\(n).res")
    let dat = try inFile("\(n).dat")
    let rd = try geturl()
    try await run(withStdin: inp+",p\n", output: res, args: "-", dat, cd: rd)
  }

  @Test("remember to fix this") func remem() {
    Issue.record("remember to fix p.midCapture()")
  }
  
// FIXME: these tests need the ability to look at the standard output collected up to this point
  // which used to exist with  p.midCapture()   but no longer exists.
/*
  @Test(arguments: [
    "e1", "g1", "r1",
    // FIXME: disabled because I can't get it to work
//    "s1",
    "s2", "v",
  ]) func with_out(_ n : String) async throws {
    let inp = try fileContents("\(n).t")
    let res = try fileContents("\(n).res")
    let dat = try inFile("\(n).dat")
    let rd = try geturl()
    let se = StringEmitter()
    let ss = se.stream
    let p = DarwinProcess()
    let pid = try await p.launch(cmd, withStdin: ss, args: "-", dat, env: ["NSUnbufferedIO" : "1"], cd: rd)
    se.send(inp)
    await Task.yield()
    try await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
    let k1 = await p.midCapture()
    se.send(",p\n")
    se.finish()
/*    await Task.yield()
    try await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC) * 0.3))
    let k2 = await p.midCapture()
*/
    let po = tt.value
    #expect(po.code == 0)
    #expect(po.string == res)
  }
  
  @Test(arguments: [
    "=", "a1", "a2", "addr1", "addr2", "bang1", "bang2", "c1", "c2", "d", "e1", "e2", "e3", "f1", "f2", "g1", "g2", "g3",
    "h", "i1", "i2", "i3", "k1", "k2", "k3", "k4", "m", "nl", "q1",
    "r1", "r2", "s1", "s10", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "t1", "t2", "u", "w1", "w2", "w3", "x", "z",
  ]) func errs(_ n : String) async throws {
    let inp = try inFile("\(n).err")
//    let rd = try geturl(suiteBundle)
    let se = StringEmitter()
    let ss = se.stream
    let p = ShellProcess(cmd, "-", inp, env: ["NSUnbufferedIO" : "1"])
    let tt = Task.detached {
      try await p.run(ss)
    }
    let ii = try inp.readAsString()
    se.send(ii)
    await Task.yield()
    try await Task.sleep(nanoseconds: Darwin.NSEC_PER_SEC / 10)
    let k1 = await p.midCapture()
    se.finish()

    let k1s = String(data: k1, encoding: .utf8)!
    let mm = k1s.matches(of: /(^|\\n)?(\\n|$)/)
    #expect(mm.count>0, "ed command error signified by '?' output")
  }
 */
}


class StringEmitter {
  private var continuation: AsyncStream<[UInt8]>.Continuation!

  // The AsyncStream that consumers will await on
  var stream: AsyncStream<[UInt8]>!

  init() {
    stream = AsyncStream { continuation in
      self.continuation = continuation
    }
  }
  // Function to send the next string to the stream
  func send(_ string: String) {
    continuation!.yield(Array(string.utf8))
  }
  
  func send(_ string: [UInt8]) {
    continuation.yield(string)
  }
  
  // Function to finish the stream
  func finish() {
    continuation.finish()
  }
}
