/*
  The MIT License (MIT)
  Copyright © 2024 Robert (r0ml) Lefkowitz

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
  and associated documentation files (the “Software”), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
  subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
  OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation


//  @Flag("m") var mflag = false
//  @FlagSet("j") var flagger : Flags = []
//  @GetOpt("amnoprsv") var opts : Opts

// var optx : Opts

// init?
/*    let k = Mirror(reflecting: self)
 let z = k.children
 let zz = z.compactMap { $0.value as? Flag}
 
 
 for i in zz {
 let l = i.
 let v = i.value
 print(i, l, v)
 }
 */
//    optx = try Opts(opts)



public struct CmdErr : Error {
  public var code : Int
  public var message : String
  
  public init(_ code : Int, _ message : String = "") {
    self.code = code
    self.message = message
  }
}

@propertyWrapper
public struct Flag {
  internal var _parsedValue: Bool
  internal var _key : String
  
  public init(wrappedValue v: Bool, _ k : String) {
    self._parsedValue = v
    self._key = k
  }
  
  /*
   public init(from _decoder: Decoder) throws {
   try self.init(_decoder: _decoder)
   }
   */
  
  /// This initializer works around a quirk of property wrappers, where the
  /// compiler will not see no-argument initializers in extensions. Explicitly
  /// marking this initializer unavailable means that when `Value` conforms to
  /// `ExpressibleByArgument`, that overload will be selected instead.
  ///
  /// ```swift
  /// @Argument() var foo: String // Syntax without this initializer
  /// @Argument var foo: String   // Syntax with this initializer
  /// ```
  @available(*, unavailable, message: "A default value must be provided unless the value type conforms to ExpressibleByArgument.")
  public init() {
    fatalError("unavailable")
  }
  
  /// The value presented by this property wrapper.
  public var wrappedValue: Bool {
    get {
      _parsedValue
    }
    set {
      _parsedValue = newValue
    }
  }
}


@propertyWrapper
public struct FlagSet<S> {
  internal var _parsedValue: S
  internal var key : String
  
  public init(wrappedValue v: S, _ s : String) {
    self._parsedValue = v
    key = s
  }
  
  /*
   public init(from _decoder: Decoder) throws {
   try self.init(_decoder: _decoder)
   }
   */
  
  /// This initializer works around a quirk of property wrappers, where the
  /// compiler will not see no-argument initializers in extensions. Explicitly
  /// marking this initializer unavailable means that when `Value` conforms to
  /// `ExpressibleByArgument`, that overload will be selected instead.
  ///
  /// ```swift
  /// @Argument() var foo: String // Syntax without this initializer
  /// @Argument var foo: String   // Syntax with this initializer
  /// ```
  @available(*, unavailable, message: "A default value must be provided unless the value type conforms to ExpressibleByArgument.")
  public init() {
    fatalError("unavailable")
  }
  
  /// The value presented by this property wrapper.
  public var wrappedValue: S {
    get {
      _parsedValue
    }
    set {
      _parsedValue = newValue
    }
  }
}

