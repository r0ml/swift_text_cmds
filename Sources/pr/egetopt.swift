// Modern Swift version of egetopt

import CMigration

class Egetopt {
  var nargv : ArraySlice<String>
  var ostr : String
  
  var savec: Character? = nil
  var place: String = "" // option letter processing
  
  init(_ ostr : String, args: ArraySlice<String> = CommandLine.arguments.dropFirst()) {
    self.ostr = ostr
    self.nargv = args
  }
  
  func egetopt() throws(CmdErr) -> (String, String)? {
    
    var eoptopt: Character? // character checked for validity
    var eoptarg: String    // argument associated with option
    
    var delim: String = "-" // which option delimiter
    
    if let saved = savec {
      place = String(saved) + place
      savec = nil
    }
    
    if place.isEmpty {
      if nargv.isEmpty || (nargv.first!.first != "-" && nargv.first!.first != "+") {
        return nil
      }
      place = nargv.first!
      delim = String(place.removeFirst() )
      if place == "-" {
        nargv.removeFirst()
        return nil
      }
    }
    
    guard !place.isEmpty else {
      return nil
    }
    
    eoptopt = place.removeFirst()
    guard let opt = eoptopt, opt != ":", opt != "?",  ostr.contains(opt) else {
      // # option: +/- with a number is ok
      if ostr.contains("#") && (eoptopt?.isWholeNumber ?? false || ((eoptopt == "-" || eoptopt == "+") && (!place.isEmpty && place.first!.isWholeNumber))) {
        // Skip over number
        eoptarg = (eoptopt == nil ? "" : String(eoptopt!)) + String(place.prefix(while: {$0.isWholeNumber}))
        place.removeFirst(eoptarg.count - (eoptopt != nil ? 1 : 0) )
        if place.isEmpty {
          nargv.removeFirst()
        } else {
          savec = place.first
        }
        return (delim, eoptarg)
      }
      if place.isEmpty { nargv.removeFirst() }
      // Error reporting omitted (no Foundation)
      throw CmdErr(1, "illegal option: \(eoptopt ?? "?")")
    }
    if delim == "+" {
      if place.isEmpty { nargv.removeFirst() }
      // Error reporting omitted (no Foundation)
      throw CmdErr(1, "illegal '+' delimiter with option -- \(eoptopt ?? "?")")
    }
    
    var oliChar : Character? = nil
    if let oliIndex = ostr.firstIndex(of: opt) {
      let nextIndex = ostr.index(after: oliIndex)
      oliChar = nextIndex < ostr.endIndex ? ostr[nextIndex] : nil
    }
    if oliChar != ":" && oliChar != "?" {
      eoptarg = ""
      if place.isEmpty { nargv.removeFirst() }
      return ( String(opt), "")
    }
    nargv.removeFirst()
    if !place.isEmpty {
      eoptarg = place
    } else if oliChar == "?" {
      eoptarg = ""
    } else if nargv.isEmpty {
      place = ""
      // Error reporting omitted (no Founda(tion)
      throw CmdErr(1, "option requires an argument -- \(eoptopt ?? "?")")
    } else {
      eoptarg = nargv.removeFirst()
    }
    place = ""
    return ( String(opt), eoptarg)
  }
  
  var remaining : [String] { return Array(nargv) }
}
