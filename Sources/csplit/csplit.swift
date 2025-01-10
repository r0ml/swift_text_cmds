
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/*-
  SPDX-License-Identifier: BSD-2-Clause-FreeBSD
 
  Copyright (c) 2002 Tim J. Robbins.
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


/*
 * csplit -- split files based on context
 *
 * This utility splits its input into numbered output files by line number
 * or by a regular expression. Regular expression matches have an optional
 * offset with them, allowing the split to occur a specified number of
 * lines before or after the match.
 *
 * To handle negative offsets, we stop reading when the match occurs and
 * store the offset that the file should have been split at, then use
 * this output file as input until all the "overflowed" lines have been read.
 * The file is then closed and truncated to the correct length.
 *
 * We assume that the output files can be seeked upon (ie. they cannot be
 * symlinks to named pipes or character devices), but make no such
 * assumption about the input.
 */

import Foundation
import Shared

@main final class csplit : ShellCommand {

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
    throw CmdErr(1, usage)
  }
}
