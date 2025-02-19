
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025
// from a file with the following notice:

/*
Copyright (C) 2012 Oleg Moskalenko <mom040267@gmail.com>
Copyright (C) 2012 Gabor Kovesdan <gabor@FreeBSD.org>
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

 */
import Foundation

/*
 I see the task is to convert some C functions into Swift. The C code defines three functions, isdigit_clocale, isalpha_clocale, and isalnum_clocale, which are inline functions checking characters’ types. The fourth function is find_suffix, which uses two iterators and a length pointer. It involves operations like bws_get_iter_value and bws_iterator_inc, which I’ll need to adapt for Swift’s handling of iterators and other types. I’ll focus on converting these carefully while making sure they map well to Swift syntax and functionality.

 Alright, I’m working on converting several functions from C to Swift. The functions in C assume a bwstring_iterator, operating on wchar_t characters, but in Swift, we’ll work with Unicode scalars or characters (which are extended grapheme clusters). I’ll need to handle all the conversion logic carefully, including adapting iterators like bws_get_iter_value to Swift’s String manipulation tools.
 The key C functions to convert include isdigit_clocale, isalpha_clocale, and cmpversions. While some aspects of C can be directly translated, others like wide characters will require some adjustments to Swift’s types. The tricky part will be handling custom functions like find_suffix, cmp_chars, and vcmp, which access character-by-character logic.

 In Swift, I can represent Bwstring as a String and use the string’s indices as iterators. This way, rather than handling wchar_t values, I can work with Character and their Unicode scalars. For functions like isdigit_clocale and isalpha_clocale, I’ll convert characters to Unicode scalars and compare them using their values. Since Character isn’t directly comparable, I’ll handle it with something like .asciiValue from Swift 5. I’ll define the isalnum_clocale function similarly. This approach should map well to the original C code.

 I’m thinking of converting the find_suffix function into Swift by using string indices. I’ll iterate over a substring from a start index to an end index, checking characters using helper functions like isalpha_clocale and isalnum_clocale.
 For cmp_chars, I’ll compare characters by converting them to Unicode scalars, and handle special cases like ~ and digit checks. For cmpversions, I’ll iterate through numeric and non-numeric characters, considering leading zeros and comparing them gradually.
 Finally, vcmp will compare two strings, using comparison results from compare(), handling edge cases—and treating the string as substrings for meticulous checks.

 I’m working on converting the C-based logic into Swift, focusing on how suffixLen works and ensuring that comparisons are structured correctly. In Swift, I can use string indices to handle the ranges and lengths before the suffix. Each string comparison, like cmpversions, will use logical indexing and handle leading zeros or different string lengths.
 The function vcmp will also be defined, where I will explicitly check the comparison results and match the behavior of cmpversions according to the Swift way. I’ll need to make sure that all edge cases are handled—from string lengths to digits vs. non-digits—while maintaining accurate behavior during iteration.
 */


/*
 Explanation
   1.  Character Classification:
 The functions isdigit_clocale(_:), isalpha_clocale(_:), and isalnum_clocale(_:) mimic the C code by working on the ASCII value (using the Swift property asciiValue) of a character.
   2.  Finding the Suffix Boundary:
 The function findSuffix(in:start:end:len:) scans from a given start to end index in a string and sets the “length before suffix” (via the in–out parameter) according to the same rules as in the C code. In Swift we work with string indices and use str.index(after:) to “advance” the iterator.
   3.  Character and Version Comparison:
 The functions cmp_chars(_:_:) and cmpversions(_:_:) perform comparisons between individual characters and between version segments respectively. They follow the same logic as the original C routines, including special treatment for the tilde (~) and digit sequences.
   4.  Version Comparison Entry Point (vcmp)
 The vcmp(_:_:) function puts everything together. It first uses a simple “byte–wise” (literal) comparison as a fallback, then applies special-case handling for strings that start with a dot, and finally uses the non–suffix portions (determined by findSuffix) compared by cmpversions.

 */



// MARK: - Character Classification (CLocale)

/// Returns true if the character is between '0' and '9'
func isdigit_clocale(_ c: Character) -> Bool {
    guard let ascii = c.asciiValue else { return false }
    return ascii >= 48 && ascii <= 57  // '0'... '9'
}

/// Returns true if the character is an ASCII letter.
func isalpha_clocale(_ c: Character) -> Bool {
    guard let ascii = c.asciiValue else { return false }
    return (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
}

/// Returns true if the character is alphanumeric.
func isalnum_clocale(_ c: Character) -> Bool {
    return isalpha_clocale(c) || isdigit_clocale(c)
}

// MARK: - Suffix Finding

/**
 Finds the “suffix” boundary in a version–string.
 
 The function iterates from `start` up to (but not including) `end` in the
 given string. It examines each character and when it finds a dot (`.`) followed
 by an alphabetic character (or a tilde, `~`), it marks that point as the beginning
 of the “suffix”. The parameter `len` (returned via an in–out parameter) is set to
 the number of characters (from the beginning of the string segment) before the suffix.
 
 - Parameters:
   - str: The string to scan.
   - start: The starting index.
   - end: The ending index.
   - len: On return, the count of characters preceding the suffix.
 */
func findSuffix(in str: String, start: String.Index, end: String.Index, len: inout Int) {
    var sfx = false
    var expectAlpha = false
    len = 0
    var clen = 0
    var i = start

    while i < end {
        let c = str[i]
        if expectAlpha {
            expectAlpha = false
            if !isalpha_clocale(c) && c != "~" {
                sfx = false
            }
        } else if c == "." {
            expectAlpha = true
            if !sfx {
                sfx = true
                len = clen
            }
        } else if !isalnum_clocale(c) && c != "~" {
            sfx = false
        }
        i = str.index(after: i)
        clen += 1
    }
    if !sfx {
        len = clen
    }
}

// MARK: - Character Comparison

/**
 Compares two characters using special rules.
 
 - If the two characters are equal, returns 0.
 - The tilde character (`~`) sorts before any other character.
 - If either character is a digit (or the null character, represented here as "\0"),
   special rules apply.
 - Otherwise, if one character is alphabetic and the other isn’t, the alphabetic one sorts lower.
 - If both are alphabetic (or both nonalphabetic), the numeric difference of their Unicode scalar values is returned.
 */
func cmp_chars(_ c1: Character, _ c2: Character) -> Int {
    if c1 == c2 {
        return 0
    }
    if c1 == "~" {
        return -1
    }
    if c2 == "~" {
        return 1
    }
    
    // In this translation, we represent the C “0” (null) as "\0".
    if isdigit_clocale(c1) || c1 == "\0" {
        return (isdigit_clocale(c2) || c2 == "\0") ? 0 : -1
    }
    if isdigit_clocale(c2) || c2 == "\0" {
        return 1
    }
    
    if isalpha_clocale(c1) {
        return isalpha_clocale(c2)
            ? Int(c1.unicodeScalars.first!.value) - Int(c2.unicodeScalars.first!.value)
            : -1
    }
    if isalpha_clocale(c2) {
        return 1
    }
    return Int(c1.unicodeScalars.first!.value) - Int(c2.unicodeScalars.first!.value)
}

// MARK: - Version Comparison

/**
 Compares two “version” substrings.
 
 This function expects two substrings (from a version string) and compares them
 piece–by–piece. It skips over non–digit parts using `cmp_chars` and then, when both
 substrings have digit sequences, it compares them numerically (ignoring leading zeros).
 
 - Parameters:
   - s1: A substring (part of a version string).
   - s2: Another substring.
 - Returns: An integer less than, equal to, or greater than zero if s1 is found,
            respectively, to be less than, to match, or be greater than s2.
 */
func cmpversions(_ s1: Substring, _ s2: Substring) -> Int {
    var si1 = s1.startIndex
    var si2 = s2.startIndex
    let se1 = s1.endIndex
    let se2 = s2.endIndex

    while si1 < se1 || si2 < se2 {
        var diff = 0

        while ((si1 < se1 && !isdigit_clocale(s1[si1])) ||
               (si2 < se2 && !isdigit_clocale(s2[si2]))) {
            let c1: Character = (si1 < se1) ? s1[si1] : "\0"
            let c2: Character = (si2 < se2) ? s2[si2] : "\0"
            let cmp = cmp_chars(c1, c2)
            if cmp != 0 {
                return cmp
            }
            if si1 < se1 { si1 = s1.index(after: si1) }
            if si2 < se2 { si2 = s2.index(after: si2) }
        }

        while si1 < se1 && s1[si1] == "0" {
            si1 = s1.index(after: si1)
        }
        while si2 < se2 && s2[si2] == "0" {
            si2 = s2.index(after: si2)
        }

        while si1 < se1 && si2 < se2 && isdigit_clocale(s1[si1]) && isdigit_clocale(s2[si2]) {
            if diff == 0 {
                diff = Int(s1[si1].unicodeScalars.first!.value) - Int(s2[si2].unicodeScalars.first!.value)
            }
            si1 = s1.index(after: si1)
            si2 = s2.index(after: si2)
        }

        if si1 < se1 && isdigit_clocale(s1[si1]) {
            return 1
        }
        if si2 < se2 && isdigit_clocale(s2[si2]) {
            return -1
        }
        if diff != 0 {
            return diff
        }
    }
    return 0
}

// MARK: - Main Version Comparison Function

/**
 Compares two version strings.
 
 The function first performs a byte–wise comparison as a fallback. It then looks for
 special “suffix” markers (such as a leading dot) and uses `findSuffix` to determine the
 part of the string to compare with `cmpversions`. If the non–suffix parts compare equal,
 the original byte–wise comparison result is returned.
 
 - Parameters:
   - s1: The first version string.
   - s2: The second version string.
 - Returns: An integer indicating the ordering of the two version strings.
 */
func vcmp(_ s1: String, _ s2: String) -> Int {
    if s1 == s2 {
        return 0
    }
    
    // Bytewise (literal) comparison fallback.
    let cmpBytesVal: Int = (s1 < s2) ? -1 : 1

    let slen1 = s1.count
    let slen2 = s2.count

    if slen1 < 1 { return -1 }
    if slen2 < 1 { return 1 }

    var si1 = s1.startIndex
    var si2 = s2.startIndex

    let c1 = s1[si1]
    let c2 = s2[si2]

    if c1 == "." && slen1 == 1 { return -1 }
    if c2 == "." && slen2 == 1 { return 1 }

    if slen1 == 2 {
        let nextIndex = s1.index(after: si1)
        if c1 == "." && s1[nextIndex] == "." {
            return -1
        }
    }
    if slen2 == 2 {
        let nextIndex = s2.index(after: si2)
        if c2 == "." && s2[nextIndex] == "." {
            return 1
        }
    }

    if c1 == "." && c2 != "." { return -1 }
    if c1 != "." && c2 == "." { return 1 }

    if c1 == "." && c2 == "." {
        si1 = s1.index(after: si1)
        si2 = s2.index(after: si2)
    }

    // Determine the boundary between the main part and the suffix.
    var len1 = findSuffix(in: s1, start: si1, end: s1.endIndex, len: &len1)
    var len2 = findSuffix(in: s2, start: si2, end: s2.endIndex, len: &len2)
    
    // Obtain the ranges corresponding to the “non–suffix” parts.
    let endIndex1 = s1.index(si1, offsetBy: len1, limitedBy: s1.endIndex) ?? s1.endIndex
    let endIndex2 = s2.index(si2, offsetBy: len2, limitedBy: s2.endIndex) ?? s2.endIndex

    // If the non–suffix parts are identical, use the bytewise result.
    if len1 == len2 && s1[si1..<endIndex1] == s2[si2..<endIndex2] {
        return cmpBytesVal
    }

    let cmpRes = cmpversions(s1[si1..<endIndex1], s2[si2..<endIndex2])
    return (cmpRes == 0) ? cmpBytesVal : cmpRes
}
