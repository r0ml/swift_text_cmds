
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2024
// from a file with the following notice:

/* Copyright (c) 1997 Gareth McCaughan. All rights reserved.
 
  Redistribution and use of this code, in source or binary forms,
  with or without modification, are permitted subject to the following
  conditions:
 
   - Redistribution of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
 
   - If you distribute modified source code it must also include
     a notice saying that it has been modified, and giving a brief
     description of what changes have been made.
 
  Disclaimer: I am not responsible for the results of using this code.
              If it formats your hard disc, sends obscene messages to
              your boss and kills your children then that's your problem
              not mine. I give absolutely no warranty of any sort as to
              what the program will do, and absolutely refuse to be held
              liable for any consequences of your using it.
              Thank you. Have a nice day.
 */

/* Sensible version of fmt
 *
 * Syntax: fmt [ options ] [ goal [ max ] ] [ filename ... ]
 *
 * Since the documentation for the original fmt is so poor, here
 * is an accurate description of what this one does. It's usually
 * the same. The *mechanism* used may differ from that suggested
 * here. Note that we are *not* entirely compatible with fmt,
 * because fmt gets so many things wrong.
 *
 * 1. Tabs are expanded, assuming 8-space tab stops.
 *    If the `-t <n>' option is given, we assume <n>-space
 *    tab stops instead.
 *    Trailing blanks are removed from all lines.
 *    x\b == nothing, for any x other than \b.
 *    Other control characters are simply stripped. This
 *    includes \r.
 * 2. Each line is split into leading whitespace and
 *    everything else. Maximal consecutive sequences of
 *    lines with the same leading whitespace are considered
 *    to form paragraphs, except that a blank line is always
 *    a paragraph to itself.
 *    If the `-p' option is given then the first line of a
 *    paragraph is permitted to have indentation different
 *    from that of the other lines.
 *    If the `-m' option is given then a line that looks
 *    like a mail message header, if it is not immediately
 *    preceded by a non-blank non-message-header line, is
 *    taken to start a new paragraph, which also contains
 *    any subsequent lines with non-empty leading whitespace.
 *    Unless the `-n' option is given, lines beginning with
 *    a . (dot) are not formatted.
 * 3. The "everything else" is split into words; a word
 *    includes its trailing whitespace, and a word at the
 *    end of a line is deemed to be followed by a single
 *    space, or two spaces if it ends with a sentence-end
 *    character. (See the `-d' option for how to change that.)
 *    If the `-s' option has been given, then a word's trailing
 *    whitespace is replaced by what it would have had if it
 *    had occurred at end of line.
 * 4. Each paragraph is sent to standard output as follows.
 *    We output the leading whitespace, and then enough words
 *    to make the line length as near as possible to the goal
 *    without exceeding the maximum. (If a single word would
 *    exceed the maximum, we output that anyway.) Of course
 *    the trailing whitespace of the last word is ignored.
 *    We then emit a newline and start again if there are any
 *    words left.
 *    Note that for a blank line this translates as "We emit
 *    a newline".
 *    If the `-l <n>' option is given, then leading whitespace
 *    is modified slightly: <n> spaces are replaced by a tab.
 *    Indented paragraphs (see above under `-p') make matters
 *    more complicated than this suggests. Actually every paragraph
 *    has two `leading whitespace' values; the value for the first
 *    line, and the value for the most recent line. (While processing
 *    the first line, the two are equal. When `-p' has not been
 *    given, they are always equal.) The leading whitespace
 *    actually output is that of the first line (for the first
 *    line of *output*) or that of the most recent line (for
 *    all other lines of output).
 *    When `-m' has been given, message header paragraphs are
 *    taken as having first-leading-whitespace empty and
 *    subsequent-leading-whitespace two spaces.
 *
 * Multiple input files are formatted one at a time, so that a file
 * never ends in the middle of a line.
 *
 * There's an alternative mode of operation, invoked by giving
 * the `-c' option. In that case we just center every line,
 * and most of the other options are ignored. This should
 * really be in a separate program, but we must stay compatible
 * with old `fmt'.
 *
 * QUERY: Should `-m' also try to do the right thing with quoted text?
 * QUERY: `-b' to treat backslashed whitespace as old `fmt' does?
 * QUERY: Option meaning `never join lines'?
 * QUERY: Option meaning `split in mid-word to avoid overlong lines'?
 * (Those last two might not be useful, since we have `fold'.)
 *
 * Differences from old `fmt':
 *
 *   - We have many more options. Options that aren't understood
 *     generate a lengthy usage message, rather than being
 *     treated as filenames.
 *   - Even with `-m', our handling of message headers is
 *     significantly different. (And much better.)
 *   - We don't treat `\ ' as non-word-breaking.
 *   - Downward changes of indentation start new paragraphs
 *     for us, as well as upward. (I think old `fmt' behaves
 *     in the way it does in order to allow indented paragraphs,
 *     but this is a broken way of making indented paragraphs
 *     behave right.)
 *   - Given the choice of going over or under |goal_length|
 *     by the same amount, we go over; old `fmt' goes under.
 *   - We treat `?' as ending a sentence, and not `:'. Old `fmt'
 *     does the reverse.
 *   - We return approved return codes. Old `fmt' returns
 *     1 for some errors, and *the number of unopenable files*
 *     when that was all that went wrong.
 *   - We have fewer crashes and more helpful error messages.
 *   - We don't turn spaces into tabs at starts of lines unless
 *     specifically requested.
 *   - New `fmt' is somewhat smaller and slightly faster than
 *     old `fmt'.
 *
 * Bugs:
 *
 *   None known. There probably are some, though.
 *
 * Portability:
 *
 *   I believe this code to be pretty portable. It does require
 *   that you have `getopt'. If you need to include "getopt.h"
 *   for this (e.g., if your system didn't come with `getopt'
 *   and you installed it yourself) then you should arrange for
 *   NEED_getopt_h to be #defined.
 *
 *   Everything here should work OK even on nasty 16-bit
 *   machines and nice 64-bit ones. However, it's only really
 *   been tested on my FreeBSD machine. Your mileage may vary.
 */

import Foundation
import Shared

@main final class fmt : ShellCommand {

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
