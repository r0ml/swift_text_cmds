#  Swift Text Commands

- if the environment variable `TEST_ORIGINAL` is set, then the tests will use the command in `/usr` shipped with macOS.  I have not found an easy way to do this from within XCode, so I run the tests using the swift package manager command line:  `TEST_ORIGINAL=1 swift test --filter command`



