// Copyright (c) 1868 Charles Babbage
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025

import Testing
import TestSupport
import Foundation

@Suite(.serialized) class columnTest : ShellTest {
  
  let cmd = "column"
  let suite = "columnTest"
  
  @Test func basic01() async throws {
    let input = """
Name  Age  Location
Alice  30  New York
Bob  25  California
Charlie  35  Texas

"""
    let expected = """
Name     Age  Location
Alice    30   New         York
Bob      25   California
Charlie  35   Texas

"""
    
    try await run(withStdin: input, output: expected, args: "-t")
  }
  
  
  @Test func basic02() async throws {
    let input = """
Name,Age,Location
Alice,30,New York
Bob,25,California
Charlie,35,Texas

"""
    let expected = """
Name     Age  Location
Alice    30   New York
Bob      25   California
Charlie  35   Texas

"""
    
    try await run(withStdin: input, output: expected, args: "-t", "-s", ",")
  }
  
  
  @Test func basic03() async throws {
    let input = "A\tB\tC\n1\t2\t3\n4\t5\t6\n"
    let expected = """
A  B  C
1  2  3
4  5  6

"""
    
    try await run(withStdin: input, output: expected, args: "-t")
  }
  
  @Test func basic04() async throws {
    let input = """
Name  Age
Alice  30
Bob  25
Charlie

"""
    
    let expected = """
Name     Age
Alice    30
Bob      25
Charlie

"""
    
    try await run(withStdin: input, output: expected, args: "-t")
  }
  
  @Test func basic07() async throws {
    let input = """
名前  年齢  場所
アリス  30  ニューヨーク
ボブ  25  カリフォルニア

"""
    
    let expected = """
名前    年齢  場所
アリス  30    ニューヨーク
ボブ    25    カリフォルニア

"""
    
    try await run(withStdin: input, output: expected, args: "-t")
  }
  


  @Test func columns() async throws {
    let input = "Abcdefg\nBhijk\nlmnopq\nrstuvwxyz\nD\nE\nF\nG\nH\n"
    let expected = """
Abcdefg\t\tE
Bhijk\t\tF
lmnopq\t\tG
rstuvwxyz\tH
D

"""
    
    try await run(withStdin: input, output: expected, args: "-c", "40")
  }
  

  @Test(arguments: [10, 20]) func columns02(_ i : Int) async throws {
    let input = "Abcdefg\nBhijk\nlmnopq\nrstuvwxyz\nD\nE\nF\nG\nH\n"
    let expected = """
Abcdefg
Bhijk
lmnopq
rstuvwxyz
D
E
F
G
H

"""
    
    try await run(withStdin: input, output: expected, args: "-c", String(i))
  }
  

  @Test func xflag() async throws {
    let input = "Abcdefg\nBhijk\nlmnopq\nrstuvwxyz\nD\nE\nF\nG\nH\n"
    let expected = """
Abcdefg\t\tBhijk
lmnopq\t\trstuvwxyz
D\t\tE
F\t\tG
H

"""
    
    try await run(withStdin: input, output: expected, args: "-x", "-c", "40")
  }
  
  

  
  
  
}
