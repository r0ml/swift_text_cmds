
// Generated by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file containing the following notice:

/*
 
  Copyright 2017 Shivansh
  All rights reserved.
 
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
  ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.
 */

import ShellTesting

struct rsTest : ShellTest {
  var cmd = "rs"
  var suiteBundle = "rsTest"

  @Test("Verify the usage of option 'c'") func c_flag() async throws {
    try await run(output: "", args: "-c")
  }

  @Test("Verify the usage of option 's'") func s_flag() async throws {
    try await run(output: "", args: "-s")
  }

  @Test("Verify the usage of option 'C'") func C_flag() async throws {
    try await run(output: "", args: "-C")
  }

  @Test("Verify the usage of option 'S'") func S_flag() async throws {
    try await run(output: "", args: "-S")
  }

  @Test("Verify the usage of option 't'") func t_flag() async throws {
    try await run(output: "", args: "-t")
  }

  @Test("Verify the usage of option 'T'") func T_flag() async throws {
    try await run(output: "", args: "-T")
  }

  @Test("Verify the usage of option 'k'") func k_flag() async throws {
    try await run(output: "", args: "-k")
  }

  @Test("Verify the usage of option 'K'") func K_flag() async throws {
    try await run(output: "", args: "-K")
  }

  @Test("Verify the usage of option 'g'") func g_flag() async throws {
    try await run(output: "", args: "-g")
  }

  @Test("Verify the usage of option 'G'") func G_flag() async throws {
    try await run(output: "", args: "-G")
  }

  @Test("Verify the usage of option 'e'") func e_flag() async throws {
    try await run(output: "\n", args: "-e")
  }

  @Test("Verify the usage of option 'n'") func n_flag() async throws {
    try await run(output: "", args: "-n")
  }

  @Test("Verify the usage of option 'y'") func y_flag() async throws {
    try await run(output: "", args: "-y")
  }

  @Test("Verify the usage of option 'h'") func h_flag() async throws {
    try await run(output: "1 0\n", args: "-h")
  }

  @Test("Verify the usage of option 'H'") func H_flag() async throws {
    try await run(output: " 0 line 1\n1 0\n", args: "-H")
  }

  @Test("Verify the usage of option 'j'") func j_flag() async throws {
    try await run(output: "", args: "-j")
  }

  @Test("Verify the usage of option 'm'") func m_flag() async throws {
    try await run(output: "", args: "-m")
  }

  @Test("Verify the usage of option 'z'") func z_flag() async throws {
    try await run(output: "", args: "-z")
  }

  @Test("Verify that an invalid usage with a supported option produces a valid error message", .disabled("error message for swift version is 'option requires an argument' -- which should be the case here; the 'must be a positive integer' should happen if there is an invalid argument")) func invalid_usage() async throws {
    try await run(status: 1, error: "width must be a positive integer", args: "-w")
  }

  @Test("Verify that rs(1) executes successfully and produces a valid output when invoked without any arguments") func no_arguments() async throws {
    try await run(output: "\n")
  }



}
