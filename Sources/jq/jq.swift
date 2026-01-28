
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

import CMigration

@main final class jq : ShellCommand {

  var usage : String = "Not yet implemented"

  struct CommandOptions {
    var args : [String] = CommandLine.arguments
  }

  var options : CommandOptions!

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
  
  func runCommand() throws(CmdErr) {
    throw CmdErr(1, usage)
  }
}
