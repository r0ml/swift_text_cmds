// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Foundation
import CMigration

import SwiftUI


@main final class banner : ShellCommand {
  
  struct CommandOptions : Sendable {
    var fontName : String = "Helvetica"
    var fontSize = 100
    var width : Int = 132
    var message : String = ""
  }
  
  nonisolated let usage: String = "banner message"
  
  
  func parseOptions() throws(CmdErr) -> CommandOptions {
    let supportedFlags = "w:s:f:"
    let go = BSDGetopt(supportedFlags)
    var args = CommandOptions()
    
    while let (k, v) = try go.getopt() {
      switch k {
        case "w":
          if let w = Int(v) {
            args.width = w
          }
        case "s":
          if let w = Int(v) {
            args.fontSize = w
          }
        case "f":
          args.fontName = v
          if nil == NSFont(name: args.fontName, size: 50) {
            throw CmdErr(1, "font not found: \(v)")
          }
          
        default:
          throw CmdErr(1)
      }
    }
      
    args.message = go.remaining.joined(separator: " ")
    return args
  }

  func runCommand(_ options : CommandOptions) async throws(CmdErr) {
    let m = options.message
    
    let f = Font.custom(options.fontName, fixedSize: CGFloat(options.fontSize))

    let kx = Text(m)
      .font(f)
      .foregroundStyle(Color.black)
      .backgroundStyle(Color.white)
      .padding([.leading, .trailing], 20)
    
    let t = Task {@MainActor in
      let j = ImageRenderer(content: kx.frame(height: CGFloat(options.width)) )
      let k = j.cgImage!
      let p = pixelValues(k)
      let w = k.width
      let h = k.height
      
      for i in stride(from: 0, to: w, by: 2) {

        let z = w*h-2
        let r1 = stride(from: i, to: z, by: w).map { p[$0]+p[$0+1] }
        
        let r2 = r1.reversed().map { $0 > 1 ? "X" : " " }
        let r3 = r2.joined()
        print(r3)
      }
      return true
    }
    
    let _ = await t.value
  }
  
}

// extension CGImage {
  func pixelValues(_ cgImage : CGImage) -> [Float] {
    
    let width = cgImage.width
    let height = cgImage.height
    
    let cs = CGColorSpaceCreateDeviceRGB()
    
    let bmi = CGImageAlphaInfo.premultipliedLast
    
    var intensities = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    
    guard let context = CGContext(data: &intensities, width: cgImage.width, height: cgImage.height,
                                  bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                                  space: cs, bitmapInfo: bmi.rawValue) else {
      fatalError("couldn't create CGContext")
    }
    
    context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    
    guard !(intensities.allSatisfy { $0 == 0} ) else {
      fatalError("it's all zero!!!")
    }
    
    var grayscale = [Float]()
    grayscale.reserveCapacity(width * height)
    
    for i in stride(from: 0, to: intensities.count, by: 4) {
      //  let r = Float(intensities[i]) / 255.0
      //  let g = Float(intensities[i + 1]) / 255.0
      //  let b = Float(intensities[i + 2]) / 255.0
      let a = Float(intensities[i+3]) / 255.0
      grayscale.append( a /* gray */ )
    }
    
    return grayscale
  }
// }
