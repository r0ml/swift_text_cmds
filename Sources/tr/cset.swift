
// Modernized by Robert "r0ml" Lefkowitz <code@liberally.net> in 2025 using ChatGPT
// from a file with the following notice:

/*
Copyright (c) 2004 Tim J. Robbins.
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

/// Represents a node in the character set binary search tree
class CSNode {
    var csnMin: UnicodeScalar
    var csnMax: UnicodeScalar
    var left: CSNode?
    var right: CSNode?

    init(min: UnicodeScalar, max: UnicodeScalar) {
        self.csnMin = min
        self.csnMax = max
        self.left = nil
        self.right = nil
    }
}

/// Represents a character class entry (like digit, letter, etc.)
class CSClass {
    var type: NSCharacterSet
    var invert: Bool
    var next: CSClass?

    init(type: NSCharacterSet, invert: Bool) {
        self.type = type
        self.invert = invert
    }
}

/// Represents a character set with tree-based storage and caching
class CSet {
    static let CS_CACHE_SIZE = 256
    var cache: [Bool] = Array(repeating: false, count: CS_CACHE_SIZE)
    var hasCache: Bool = false
    var classes: CSClass?
    var root: CSNode?
    var invert: Bool = false

    /// Determines if a character is in the set using caching.
    func contains(_ ch: UnicodeScalar) -> Bool {
        if ch.value < UInt32(CSet.CS_CACHE_SIZE) && hasCache {
            return cache[Int(ch.value)]
        }
        return containsWithoutCache(ch)
    }

    /// Allocates a new character set.
    static func allocate() -> CSet {
        return CSet()
    }

    /// Adds a character to the set.
    func add(_ ch: UnicodeScalar) -> Bool {
        hasCache = false

        // Insert into empty tree
        if root == nil {
            root = CSNode(min: ch, max: ch)
            return true
        }

        // Perform splay operation
        root = splay(root, ch)

        // Avoid duplicate entries
        if rangeCompare(root!, ch) == 0 {
            return true
        }

        // Create a new node
        let newNode = CSNode(min: ch, max: ch)
        if rangeCompare(root!, ch) < 0 {
            newNode.left = root?.left
            newNode.right = root
            root?.left = nil
        } else {
            newNode.right = root?.right
            newNode.left = root
            root?.right = nil
        }
        root = newNode

        // Merge with neighbors
        mergeNeighbors(root!)

        return true
    }

    /// Checks if a character is in the set without cache.
    private func containsWithoutCache(_ ch: UnicodeScalar) -> Bool {
        var currentClass = classes
        while let csc = currentClass {
            if csc.invert != csc.type.contains(ch) {
                return invert != true
            }
            currentClass = csc.next
        }
        if let root = root {
            self.root = splay(root, ch)
            return invert != (rangeCompare(self.root!, ch) == 0)
        }
        return invert != false
    }

    /// Updates the cache with character presence.
    func updateCache() {
        for i in 0..<CSet.CS_CACHE_SIZE {
            cache[i] = containsWithoutCache(UnicodeScalar(i)!)
        }
        hasCache = true
    }

    /// Inverts the character set.
    func invertSet() {
        invert.toggle()
        hasCache = false
    }

    /// Adds a character class to the set.
    func addClass(_ type: NSCharacterSet, invert: Bool) -> Bool {
        let newClass = CSClass(type: type, invert: invert)
        newClass.next = classes
        classes = newClass
        hasCache = false
        return true
    }

    /// Performs a splay operation on the binary search tree.
    private func splay(_ t: CSNode?, _ ch: UnicodeScalar) -> CSNode? {
        guard let root = t else { return nil }
        var leftTree = CSNode(min: "\0", max: "\0")
        var rightTree = CSNode(min: "\0", max: "\0")
        var left = leftTree, right = rightTree
        var current = root

        while true {
            if rangeCompare(current, ch) < 0 {
                if let leftChild = current.left, rangeCompare(leftChild, ch) < 0 {
                    let temp = leftChild
                    current.left = temp.right
                    temp.right = current
                    current = temp
                }
                if current.left == nil { break }
                right.left = current
                right = current
                current = current.left!
            } else if rangeCompare(current, ch) > 0 {
                if let rightChild = current.right, rangeCompare(rightChild, ch) > 0 {
                    let temp = rightChild
                    current.right = temp.left
                    temp.left = current
                    current = temp
                }
                if current.right == nil { break }
                left.right = current
                left = current
                current = current.right!
            } else {
                break
            }
        }

        left.right = current.left
        right.left = current.right
        current.left = leftTree.right
        current.right = rightTree.left
        return current
    }

    /// Deletes a character from the tree.
    private func delete(_ t: CSNode?, _ ch: UnicodeScalar) -> CSNode? {
        guard let root = t else { return nil }
        let newRoot = splay(root, ch)
        if rangeCompare(newRoot!, ch) != 0 {
            return root
        }

        var x: CSNode?
        if newRoot?.left == nil {
            x = newRoot?.right
        } else {
            x = splay(newRoot?.left, ch)
            x?.right = newRoot?.right
        }
        return x
    }

    /// Compares a character with a node's range.
    private func rangeCompare(_ node: CSNode, _ ch: UnicodeScalar) -> Int {
        if ch < node.csnMin { return -1 }
        if ch > node.csnMax { return 1 }
        return 0
    }

    /// Merges a node with its neighbors if possible.
    private func mergeNeighbors(_ node: CSNode) {
        if let left = node.left {
            let leftSplay = splay(left, UnicodeScalar(node.csnMin.value - 1)!)
            if leftSplay?.csnMax == UnicodeScalar(node.csnMin.value - 1) {
                node.left = delete(leftSplay, leftSplay!.csnMin)
                node.csnMin = leftSplay!.csnMin
            }
        }
        if let right = node.right {
            let rightSplay = splay(right, UnicodeScalar(node.csnMax.value + 1)!)
            if rightSplay?.csnMin == UnicodeScalar(node.csnMax.value + 1) {
                node.right = delete(rightSplay, rightSplay!.csnMin)
                node.csnMax = rightSplay!.csnMax
            }
        }
    }
}
