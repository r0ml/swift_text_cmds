// swift-tools-version: 6.0

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

import PackageDescription
import Foundation

let package = Package(
  name: "text_cmds",
  // Mutex is only available in v15 or newer
  platforms: [.macOS(.v15)],
//  products: [
//    .executable(name: "apply", targets: ["apply"])
//  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(name: "Shared",
            path: "Shared"),
    .target(name: "TestSupport",
            path: "TestSupport" )
    ]
    
    +
    
    generateTargets()
    
    /*
    .executableTarget(
      name: "apply",
      dependencies: [.target(name: "shared")]
    ),
    .executableTarget(
      name: "basename",
      dependencies: [.target(name: "shared")]
    ),
    */
    
    +
    
  /*
  [
    .testTarget(
      name: "applyTest",
      dependencies: [.target(name: "apply"), .target(name: "testSupport")],
      resources: [.copy("Resources")]
    ),
    .testTarget(
      name: "basenameTest",
      dependencies: [.target(name: "basename"), .target(name: "testSupport")]
    )

  ]
   */
  
  generateTestTargets()
)

func generateTargets() -> [Target] {
    var res = [Target]()
    let cd = try! FileManager.default.contentsOfDirectory(atPath: "Sources")
    print(cd)
    for i in cd {
        let t = Target.executableTarget(name: i, dependencies: [.target(name: "Shared")] )
        res.append(t)
    }
    return res
}
 

func generateTestTargets() -> [Target] {
    var res = [Target]()
    
    let cd = try! FileManager.default.contentsOfDirectory(atPath: "Tests")
    print(cd)
    for i in cd {
      if i == ".DS_Store" { continue }
        let r = try! FileManager.default.fileExists(atPath: "Tests/\(i)/Resources")
      let x = try! FileManager.default.contentsOfDirectory(atPath: "Tests/\(i)").filter { $0.hasSuffix(".xctestplan") }
        let rr = r ? [Resource.copy("Resources")] : []
        let t = Target.testTarget(name: i,
                                  dependencies: [.target(name: "TestSupport"),
                                                 .target(name: i.replacingOccurrences(of: "Test", with: ""))],
                                  path: nil,
                                  exclude: x
                                  , resources: rr
        )
        res.append(t)
    }
    return res
}
