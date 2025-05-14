#  Swift Text Cmds

## Generally...
This is one repository of a series to convert as much C code as possible to a modern safe language.  In this case, the modern safe language is Swift.
Towards this end, the various open source projects written in C and derived from the BSDs and GNU which go into Darwin will be translated into Swift.

In the first pass, the translations will be close to transliterations.  The first objective is to establish a working base of commands written in Swift.  After that, it will
be possible to improve these translations by refactoring them to be more idiomatically Swift-ish.

These translations are also implemented using the Swift Package Manager rather then XCode projects -- in this way the results will be portable to Linux and Windows environments.
I have not yet validated these ports for non-Mac environments.
An XCode project is included which will install the built commands and man pages into `/opt/local`.  There is no way to use Swift Pacakge Manager to install packages in a system standard location, so a shell script to copy the built products is included in the repository.

In addition to the source code for the commands, the test suites have also been converted to run as Swift Package Manager tests.

At some point, in addition to updating the source code and tests, the documentation (man pages) may be modernized.

The commands transliterate the handling of command line options from the C.  Attempts to use the SPM package for command line arguments added around 1.5 megabytes of weight to each executable.
The transliterated C -> Swift version of these commands weigh in at around 100kB, so the penalty for using the Swift-y command line argument package is prohibitive.

This repository uses two dependencies:

  1) the repository [CMigration](https://github.com/r0ml/CMigration.git) which contains various Swift reimplementations or wrappers for common
  C functions which are used by the various commands.  The most consequential of these is `getopt` -- which is used by most commands.
  
  2) the repository [ShellTesting](https://github.com/r0ml/ShellTesting.git) which provides a library to simplify the conversion of the existing
  legacy tests into the SwiftTesting framework.
  
As the repository contains numerous shell commands, I will be using the associated [github wiki](https://github.com/r0ml/swift_text_cmds/wiki) to provide a page to discuss each command.

# Specifically...

This repo translates most of the commands in Apple's [text_cmds](https://github.com/apple-oss-distributions/text_cmds.git) from C to Swift.

# Building...
Once the repository is checked out, it can be built, tests can be run, and command installed to `/opt/local` using the XCode project.  The target all_commands will build and run the tests for all commands.

Alternatively, one can use   `swift build` or `swift test` from the command line.  In this case, the commands are built into the directory .build.  One can then run the shell script `doInstall.sh` to copy the commands and man pages to `/opt/local`.

