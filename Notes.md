
- "\r\n" is a single Character.  All places where I compare to "\n" (e.g. s.last == "\n" ) might need to be updated to check for "\r\n" as well.  Discovered this while working on 'sed'

- look for MB_CUR_MAX and setlocale -- commands should pay attention to locale -- I've been assuming locale is always UTF-8

- make a list of libc or Darwin functions that are directly called by Swift to see if there are Swiftier alternatives, or to collect references to them in the CMigration library.

- if the environment variable `TEST_ORIGINAL` is set, then the tests will use the command in `/usr` shipped with macOS.  I have not found an easy way to do this from within XCode, so I run the tests using the swift package manager command line:  `TEST_ORIGINAL=1 swift test --filter command`
