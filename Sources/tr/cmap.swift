
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

/// Represents a node in the character map splay tree
class CMapNode {
    var from: UnicodeScalar
    var to: UnicodeScalar
    var left: CMapNode?
    var right: CMapNode?

    init(from: UnicodeScalar, to: UnicodeScalar) {
        self.from = from
        self.to = to
        self.left = nil
        self.right = nil
    }
}

/// Represents a character mapping system using a splay tree
class CMap {
    static let CM_CACHE_SIZE = 128
    static let CM_DEF_SELF: UnicodeScalar = UnicodeScalar(-2)!

    private var cache: [UnicodeScalar] = Array(repeating: CMap.CM_DEF_SELF, count: CM_CACHE_SIZE)
    private var hasCache: Bool = false
    private var root: CMapNode?
    private var defaultMapping: UnicodeScalar = CMap.CM_DEF_SELF
    private var minChar: UnicodeScalar = UnicodeScalar(0)!
    private var maxChar: UnicodeScalar = UnicodeScalar(0)!

    /// Allocates a new character map.
    static func allocate() -> CMap {
        return CMap()
    }

    /// Adds a mapping from `from` to `to` in the map.
    func add(from: UnicodeScalar, to: UnicodeScalar) -> Bool {
        hasCache = false

        if root == nil {
            root = CMapNode(from: from, to: to)
            minChar = from
            maxChar = from
            return true
        }

        root = splay(root, from)

        if root!.from == from {
            root!.to = to
            return true
        }

        let newNode = CMapNode(from: from, to: to)
        if from < root!.from {
            newNode.left = root?.left
            newNode.right = root
            root?.left = nil
        } else {
            newNode.right = root?.right
            newNode.left = root
            root?.right = nil
        }

        if from < minChar { minChar = from }
        if from > maxChar { maxChar = from }
        root = newNode

        return true
    }

    /// Looks up the mapping for a character using cache if available.
    func lookup(_ ch: UnicodeScalar) -> UnicodeScalar {
        if ch.value < UInt32(CMap.CM_CACHE_SIZE) && hasCache {
            return cache[Int(ch.value)]
        }
        return lookupHard(ch)
    }

    /// Looks up the mapping for a character without using cache.
    private func lookupHard(_ ch: UnicodeScalar) -> UnicodeScalar {
        if let root = root {
            self.root = splay(root, ch)
            if self.root!.from == ch {
                return self.root!.to
            }
        }
        return defaultMapping == CMap.CM_DEF_SELF ? ch : defaultMapping
    }

    /// Updates the cache.
    func updateCache() {
        for i in 0..<CMap.CM_CACHE_SIZE {
            cache[i] = lookupHard(UnicodeScalar(i)!)
        }
        hasCache = true
    }

    /// Changes the default mapping for unmapped characters.
    func setDefaultMapping(_ def: UnicodeScalar) -> UnicodeScalar {
        let old = defaultMapping
        defaultMapping = def
        hasCache = false
        return old
    }

    /// Gets the minimum mapped character.
    func min() -> UnicodeScalar {
        return minChar
    }

    /// Gets the maximum mapped character.
    func max() -> UnicodeScalar {
        return maxChar
    }

    /// Performs a splay operation on the tree.
    private func splay(_ root: CMapNode?, _ ch: UnicodeScalar) -> CMapNode? {
        guard let root = root else { return nil }
        let tempRoot = CMapNode(from: "\0", to: "\0") // Temporary root node
        var leftTree = tempRoot
        var rightTree = tempRoot
        var current = root

        while true {
            if ch < current.from {
                if let leftChild = current.left, ch < leftChild.from {
                    let temp = leftChild
                    current.left = temp.right
                    temp.right = current
                    current = temp
                }
                if current.left == nil { break }
                rightTree.left = current
                rightTree = current
                current = current.left!
            } else if ch > current.from {
                if let rightChild = current.right, ch > rightChild.from {
                    let temp = rightChild
                    current.right = temp.left
                    temp.left = current
                    current = temp
                }
                if current.right == nil { break }
                leftTree.right = current
                leftTree = current
                current = current.right!
            } else {
                break
            }
        }

        leftTree.right = current.left
        rightTree.left = current.right
        current.left = tempRoot.right
        current.right = tempRoot.left
        return current
    }
}
