
- "\r\n" is a single Character.  All places where I compare to "\n" (e.g. s.last == "\n" ) might need to be updated to check for "\r\n" as well.  Discovered this while working on 'sed'

- look for MB_CUR_MAX and setlocale -- commands should pay attention to locale -- I've been assuming locale is always UTF-8

- make a list of libc or Darwin functions that are directly called by Swift to see if there are Swiftier alternatives, or to collect references to them in the CMigration library.
