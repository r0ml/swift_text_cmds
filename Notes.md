
- "\r\n" is a single Character.  All places where I compare to "\n" (e.g. s.last == "\n" ) might need to be updated to check for "\r\n" as well.  Discovered this while working on 'sed'
