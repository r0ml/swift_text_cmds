// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation

public protocol Containable {
  func contains(_ c : Unicode.Scalar) -> Bool
  @discardableResult mutating func insert(_ c : Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: UnicodeScalar)
  mutating func invert()
  mutating func formUnion(_ other: Self)
}

extension CharacterSet : Containable {}

/** This is a CharacterSet, enhanced by also containing a list of "equivalence classes" -- i.e. characters which ignore diacritics ) */
public struct XCharacterSet : Containable {
  var cs : CharacterSet = CharacterSet()
  // This is an array of equivalence classes
  var eqc : Set<Unicode.Scalar> = []
  var cats : Set<Unicode.GeneralCategory> = []
  var union : [any Containable] = []
  var inverted : Bool = false
  
  public mutating func formUnion(_ other : Self) {
    union.append(other)
  }
  
  public mutating func invert() {
    inverted.toggle()
  }
  
  public func contains(_ c : Unicode.Scalar) -> Bool {
    if cs.contains(c) { return inverted != true }
    for i in eqc {
      if (String(i).compare( String(c), options: [.diacriticInsensitive] ) == .orderedSame) {
        return true != inverted
      }
    }

    if cats.contains(c.properties.generalCategory) {
        return true != inverted
    }
    
    for i in union {
      if i.contains(c) { return true != inverted }
    }
    
    return false != inverted
  }
  
  @discardableResult public mutating func insert(_ c: Unicode.Scalar) -> (inserted: Bool, memberAfterInsert: UnicodeScalar) {
    return cs.insert(c)
  }
  
  public static var print : XCharacterSet {
    return XCharacterSet(cats: nk, inverted: true)
  }
  
  public static var graph : XCharacterSet {
    return XCharacterSet(cats: Set(nk.union([.spaceSeparator])), inverted: true)
  }
}

fileprivate let nk = Set([Unicode.GeneralCategory.control, .format, .privateUse, .surrogate, .unassigned])

extension UnicodeScalar {
  var isPrintable : Bool {
    if nk.contains(self.properties.generalCategory) {
      return false
    }
    return true
  }
  
  var isGraphic : Bool {
    if nk.contains(self.properties.generalCategory) {
      return false
    }
    if self.properties.generalCategory == .spaceSeparator {
      return false
    }
    return true
  }
  
  
}
