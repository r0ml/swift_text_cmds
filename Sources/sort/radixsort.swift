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
 I’m tasked with converting a huge C code snippet to Swift while keeping variable and function names intact. I’ll have to work line-by-line to maintain the structure — no changes to variable names!
 Also, some macros like #define DEFAULT_SORT_FUNC_RADIXSORT mergesort and others will need to be translated into constants or functions in Swift. All in all, this is going to be a lengthy process, but the goal is to get the Swift code as close as possible to the original C code. Let’s dive into it!

 I’m focusing on maintaining the variable and function names while translating the C code. Names like reverse_sort, slsz, g_ls need to stay exactly the same. I’ll handle details like structs and threads differently in Swift, as it doesn’t use macros and pointers the same way. For example, Swift uses constants instead of macros, so for #define DEFAULT_SORT_FUNC_RADIXSORT mergesort, I’ll translate it to let DEFAULT_SORT_FUNC_RADIXSORT = mergesort. I’ll need to handle some function pointers, too, which might be tricky since Swift is different in those areas.

 For macros like TINY_NODE and SMALL_NODE, I’ll translate them into Swift functions: TINY_NODE(_ sl: sort_level) and SMALL_NODE(_ sl: sort_level). For global variables like reverse_sort and slsz, I’ll define them in Swift appropriately.
 When translating structs like sort_level and level_stack, I’ll map them to Swift classes, keeping variable names intact.
 For multithreading code, I’ll substitute mutexes and semaphores with Swift alternatives, but still maintain the same variable names to stay true to the original C.

 For the function sort_left_dec, I’ll handle the locking and condition checking in Swift with NSCondition and NSLock. I also need to define global variables like nthreads and the sort_left logic. When translating macros like sort_malloc and sort_realloc, I’ll create Swift functions that allocate memory as needed, using Swift’s memory management and initialization methods.
 For other functions like push_ls and pop_ls_st, I can implement them as methods in Swift, turning pointer manipulations into class instances. I’ll keep translating functions and structures, staying close to the original while leveraging Swift’s object-oriented style. I’ll use stubs where necessary to maintain consistency.

 To handle macro and function conversions, I’m defining constants like DEFAULT_SORT_FUNC_RADIXSORT = mergesort, and macros like TINY_NODE and SMALL_NODE as Swift functions. I also define global variables like reverse_sort and slsz, then create classes for sort_level and level_stack to map their C structures into Swift.
 For multithreading (SORT_THREADS), I use NSCondition and NSLock for synchronization. I’ll need to handle pointer manipulation with Swift classes and arrays, ensuring memory management stays close to C behavior. Swift’s automatic memory management takes care of some tasks that the original C code handled manually. I’ll create a comprehensive conversion with stubs where necessary to maintain structure without modifying function names.
 */

/*
 Explanation
   1.  Preserved Names:
 All variable names (e.g. reverse_sort, slsz, g_ls) and function names (e.g. push_ls, pop_ls_st, run_sort_level_next, rxsort) are preserved exactly as in the original C code.
   2.  Conditional Code:
 Code guarded by #if defined(SORT_THREADS) in C is wrapped in Swift’s conditional compilation (using #if SORT_THREADS). For threading primitives a simple NSLock/NSCondition and DispatchSemaphore are used.
   3.  Memory Management and Arrays:
 Instead of manual allocation (using sort_malloc, sort_realloc, and sort_free), Swift’s ARC and dynamic arrays are used. In places where the original code explicitly reallocates memory, comments indicate that no explicit action is needed in Swift.
   4.  Stub Functions and Types:
 Many helper functions (such as mergesort, list_coll_offset, get_list_call_func, etc.) and types (such as sort_list_item, key_value, and bwstring) are provided as stubs. In a complete implementation these would be replaced by full Swift implementations.

 */

// -----------------------------------------------------------------------------
// MARK: - Macros and Global Variables
// -----------------------------------------------------------------------------

// In C: #define DEFAULT_SORT_FUNC_RADIXSORT mergesort
// In Swift we assume a function “mergesort” exists and use it as our default.
let DEFAULT_SORT_FUNC_RADIXSORT = mergesort

// In C:
/// #define TINY_NODE(sl) ((sl)->tosort_num < 65)
func TINY_NODE(_ sl: sort_level) -> Bool {
    return sl.tosort_num < 65
}

/// #define SMALL_NODE(sl) ((sl)->tosort_num < 5)
func SMALL_NODE(_ sl: sort_level) -> Bool {
    return sl.tosort_num < 5
}

// Global variable: are we sorting in reverse order?
var reverse_sort: Bool = false

// sort sub-levels array size
let slsz: Int = 256 * MemoryLayout<sort_level?>.size

// -----------------------------------------------------------------------------
// MARK: - Type Definitions
// -----------------------------------------------------------------------------

// Stub definition for sort_list_item.
// In a full port, this would contain the key array and any other fields.
class sort_list_item {
    // Stub property representing key array.
    var ka: Int = 0
}

// Stub definition for key_value and bwstring.
class key_value {
    var k: bwstring
    init(k: bwstring) {
        self.k = k
    }
}

class bwstring {
    var length: Int = 0
    // Stub: return a wchar_t value at the given index.
    func get(_ index: Int) -> UInt32 {
        return 0
    }
}

// Stub: get_key_from_keys_array – returns a key_value? from an array given an index.
func get_key_from_keys_array(_ ka: Int, _ index: Int) -> key_value? {
    return nil
}

// Stub definitions for MB_CUR_MAX and wchar_t.
let MB_CUR_MAX: Int = 1
typealias wchar_t = UInt32

// Stub: list_coll_offset returns an Int comparison offset.
func list_coll_offset(_ a: sort_list_item, _ b: sort_list_item, _ offset: Int) -> Int {
    return 0
}

// Stub: get_list_call_func returns a comparison function pointer.
typealias listcoll_t = @convention(c) (UnsafeRawPointer, UnsafeRawPointer) -> Int
func get_list_call_func(_ offset: Int) -> listcoll_t {
    return { _, _ in return 0 }
}

// Stub: list_coll and list_coll_by_str_only comparison functions.
func list_coll(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Int { return 0 }
func list_coll_by_str_only(_ a: UnsafeRawPointer, _ b: UnsafeRawPointer) -> Int { return 0 }

// Stub: mergesort implementation.
// (In a full port, this would call an actual mergesort routine.)
func mergesort(_ base: inout [sort_list_item?], _ nmemb: Int, _ size: Int, _ compar: listcoll_t) -> Int {
    // For demonstration, simply call Swift’s sort (this is only a stub)
    base = base.sorted { (a, b) -> Bool in
        // Use the compar function on the two items (casting pointers appropriately)
        // Here we always return false.
        return false
    }
    return 0
}

// Stub: sort options and related globals.
struct sort_opts {
    var sflag: Bool = false
    var kflag: Bool = false
    var complex_sort: Bool = false
}
var sort_opts_vals = sort_opts()

// Stub: keys array and default_sort_mods.
struct sort_mod {
    var rflag: Bool = false
    // other members…
}
var keys: [sort_mod] = [sort_mod()]
var default_sort_mods: sort_mod = sort_mod()

// Stub: number of keys.
var keys_num: Int = 1

// Stub: nthreads and MT_SORT_THRESHOLD.
var nthreads: Int = 1
let MT_SORT_THRESHOLD: Int = 10000

// -----------------------------------------------------------------------------
// MARK: - Structures Represented as Classes
// -----------------------------------------------------------------------------

// C struct sort_level
class sort_level {
    var sublevels: [sort_level?]? = nil
    var leaves: [sort_list_item]? = nil
    var sorted: [sort_list_item]? = nil
    var tosort: [sort_list_item]? = nil
    var leaves_num: Int = 0
    var leaves_sz: Int = 0
    var level: Int = 0
    var real_sln: Int = 0
    var start_position: Int = 0
    var sln: Int = 0
    var tosort_num: Int = 0
    var tosort_sz: Int = 0
}

// C struct level_stack
class level_stack {
    var next: level_stack? = nil
    var sl: sort_level?
}

// Global stack pointer
var g_ls: level_stack? = nil

// -----------------------------------------------------------------------------
// MARK: - (SORT_THREADS) Conditional Definitions
// -----------------------------------------------------------------------------

#if SORT_THREADS
// In C:
/// static pthread_cond_t g_ls_cond;
var g_ls_cond = NSCondition()

/// static pthread_mutex_t g_ls_mutex;
var g_ls_mutex = NSLock()

/// static size_t sort_left;
var sort_left: Int = 0

// For semaphore, we use DispatchSemaphore (Apple platforms)
var mtsem = DispatchSemaphore(value: 0)

/// Decrement items counter.
func sort_left_dec(_ n: Int) {
    g_ls_mutex.lock()
    sort_left -= n
    if sort_left == 0 && nthreads > 1 {
        g_ls_cond.broadcast()
    }
    g_ls_mutex.unlock()
}

/// Do we have something to sort?
func have_sort_left() -> Bool {
    return sort_left > 0
}
#else
func sort_left_dec(_ n: Int) { }
#endif

// -----------------------------------------------------------------------------
// MARK: - Level Stack Operations
// -----------------------------------------------------------------------------

func _push_ls(_ ls: level_stack) {
    ls.next = g_ls
    g_ls = ls
}

/// Push sort level to the stack.
func push_ls(_ sl: sort_level) {
    let new_ls = level_stack()
    new_ls.sl = sl
    #if SORT_THREADS
    if nthreads > 1 {
        g_ls_mutex.lock()
        _push_ls(new_ls)
        g_ls_cond.signal()
        g_ls_mutex.unlock()
    } else {
        _push_ls(new_ls)
    }
    #else
    _push_ls(new_ls)
    #endif
}

/// Pop sort level from the stack (single-threaded style).
func pop_ls_st() -> sort_level? {
    var sl: sort_level? = nil
    if let current = g_ls {
        sl = current.sl
        g_ls = current.next
        // In Swift, memory is managed automatically.
    }
    return sl
}

#if SORT_THREADS
/// Pop sort level from the stack (multi-threaded style).
func pop_ls_mt() -> sort_level? {
    var saved_ls: level_stack? = nil
    var sl: sort_level? = nil
    g_ls_mutex.lock()
    while true {
        if let current = g_ls {
            sl = current.sl
            saved_ls = current
            g_ls = current.next
            break
        }
        sl = nil
        saved_ls = nil
        if !have_sort_left() {
            break
        }
        g_ls_cond.wait()
    }
    g_ls_mutex.unlock()
    // In Swift, no need to explicitly free saved_ls.
    return sl
}
#endif

// -----------------------------------------------------------------------------
// MARK: - Sorting Routines
// -----------------------------------------------------------------------------

/// Add an item to a sublevel.
func add_to_sublevel(_ sl: sort_level, _ item: sort_list_item, _ indx: Int) {
    var ssl = sl.sublevels?[indx]
    if ssl == nil {
        ssl = sort_level()
        memset(&ssl, 0, MemoryLayout<sort_level>.size)
        ssl!.level = sl.level + 1
        if sl.sublevels == nil {
            // Allocate an array of 256 (sln is 256 in many cases)
            sl.sublevels = Array(repeating: nil, count: 256)
        }
        sl.sublevels![indx] = ssl
        sl.real_sln += 1
    }
    if let ssl = sl.sublevels?[indx] {
        ssl.tosort_num += 1
        if ssl.tosort_num > ssl.tosort_sz {
            ssl.tosort_sz = ssl.tosort_num + 128
            // In Swift, arrays grow dynamically so no explicit realloc is needed.
        }
        if ssl.tosort == nil {
            ssl.tosort = []
        }
        if ssl.tosort!.count < ssl.tosort_num {
            ssl.tosort!.append(item)
        } else {
            ssl.tosort![ssl.tosort_num - 1] = item
        }
    }
}

/// Add an item as a leaf.
func add_leaf(_ sl: sort_level, _ item: sort_list_item) {
    sl.leaves_num += 1
    if sl.leaves_num > sl.leaves_sz {
        sl.leaves_sz = sl.leaves_num + 128
        // In Swift, arrays grow dynamically.
        if sl.leaves == nil { sl.leaves = [] }
    }
    if sl.leaves == nil || sl.leaves!.count < sl.leaves_num {
        sl.leaves?.append(item)
    } else {
        sl.leaves![sl.leaves_num - 1] = item
    }
}

/// Get wc index from a sort list item.
func get_wc_index(_ sli: sort_list_item, _ level: Int) -> Int {
    let wcfact: Int = (MB_CUR_MAX == 1) ? 1 : MemoryLayout<wchar_t>.size
    guard let kv = get_key_from_keys_array(sli.ka, 0) else { return -1 }
    let bws = kv.k
    if (bws.length * wcfact > level) {
        var res: wchar_t = bws.get(level / wcfact)
        if (level % wcfact < wcfact - 1) {
            res = res >> (8 * (wcfact - 1 - (level % wcfact)))
        }
        return Int(res & 0xff)
    }
    return -1
}

/// Place an item into the correct bucket.
func place_item(_ sl: sort_level, _ item: Int) {
    guard let sli = sl.tosort?[item] else { return }
    let c = get_wc_index(sli, sl.level)
    if c == -1 {
        add_leaf(sl, sli)
    } else {
        add_to_sublevel(sl, sli, c)
    }
}

/// Free a sort level.
func free_sort_level(_ sl: sort_level?) {
    if let sl = sl {
        if sl.leaves != nil {
            sl.leaves = nil
        }
        if sl.level > 0 {
            sl.tosort = nil
        }
        if let subs = sl.sublevels {
            let sln = sl.sln
            for i in 0..<sln {
                if let slc = subs[i] {
                    free_sort_level(slc)
                }
            }
            sl.sublevels = nil
        }
        // In Swift, ARC frees the object automatically.
    }
}

/// Process the next sort level.
func run_sort_level_next(_ sl: sort_level) {
    let wcfact: Int = (MB_CUR_MAX == 1) ? 1 : MemoryLayout<wchar_t>.size
    var slc: sort_level?
    var i: Int = 0
    let sln = sl.sln
    let tosort_num = sl.tosort_num

    if sl.sublevels != nil {
        sl.sublevels = nil
    }

    switch sl.tosort_num {
    case 0:
        free_sort_level(sl)
        return
    case 1:
        sl.sorted?[sl.start_position] = sl.tosort![0]
        sort_left_dec(1)
        free_sort_level(sl)
        return
    case 2:
        if list_coll_offset(sl.tosort![0], sl.tosort![1], sl.level / wcfact) > 0 {
            sl.sorted?[sl.start_position] = sl.tosort![1]
            sl.start_position += 1
            sl.sorted?[sl.start_position] = sl.tosort![0]
        } else {
            sl.sorted?[sl.start_position] = sl.tosort![0]
            sl.start_position += 1
            sl.sorted?[sl.start_position] = sl.tosort![1]
        }
        sort_left_dec(2)
        free_sort_level(sl)
        return
    default:
        if TINY_NODE(sl) || (sl.level > 15) {
            let func_ptr = get_list_call_func(sl.level / wcfact)
            sl.leaves = sl.tosort
            sl.leaves_num = sl.tosort_num
            sl.leaves_sz = sl.leaves_num
            // In Swift, arrays grow dynamically.
            sl.tosort = nil
            sl.tosort_num = 0
            sl.tosort_sz = 0
            sl.sln = 0
            sl.real_sln = 0
            if sort_opts_vals.sflag {
                if mergesort(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, func_ptr) == -1 {
                    fatalError("Radix sort error 3")
                }
            } else {
                DEFAULT_SORT_FUNC_RADIXSORT(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, func_ptr)
            }
            if let leaves = sl.leaves {
                for j in 0..<sl.leaves_num {
                    sl.sorted?[sl.start_position + j] = leaves[j]
                }
            }
            sort_left_dec(sl.leaves_num)
            free_sort_level(sl)
            return
        } else {
            sl.tosort_sz = sl.tosort_num
            // No explicit realloc needed in Swift.
        }
    }

    sl.sln = 256
    sl.sublevels = Array(repeating: nil, count: 256)
    sl.real_sln = 0

    for i in 0..<tosort_num {
        place_item(sl, i)
    }
    sl.tosort = nil
    sl.tosort_num = 0
    sl.tosort_sz = 0

    if sl.leaves_num > 1 {
        if keys_num > 1 {
            if sort_opts_vals.sflag {
                mergesort(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll)
            } else {
                DEFAULT_SORT_FUNC_RADIXSORT(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll)
            }
        } else if (!sort_opts_vals.sflag && sort_opts_vals.complex_sort) {
            DEFAULT_SORT_FUNC_RADIXSORT(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll_by_str_only)
        }
    }

    sl.leaves_sz = sl.leaves_num
    // Adjust leaves array if needed.

    if !reverse_sort {
        if let leaves = sl.leaves, var sorted = sl.sorted {
            for j in 0..<sl.leaves_num {
                sorted[sl.start_position + j] = leaves[j]
            }
        }
        sl.start_position += sl.leaves_num
        sort_left_dec(sl.leaves_num)
        for i in 0..<sl.sln {
            if let slc = sl.sublevels?[i] {
                slc.sorted = sl.sorted
                slc.start_position = sl.start_position
                sl.start_position += slc.tosort_num
                if SMALL_NODE(slc) {
                    run_sort_level_next(slc)
                } else {
                    push_ls(slc)
                }
                sl.sublevels?[i] = nil
            }
        }
    } else {
        for i in 0..<sl.sln {
            let n = sl.sln - i - 1
            if let slc = sl.sublevels?[n] {
                slc.sorted = sl.sorted
                slc.start_position = sl.start_position
                sl.start_position += slc.tosort_num
                if SMALL_NODE(slc) {
                    run_sort_level_next(slc)
                } else {
                    push_ls(slc)
                }
                sl.sublevels?[n] = nil
            }
        }
        if let leaves = sl.leaves, var sorted = sl.sorted {
            for j in 0..<sl.leaves_num {
                sorted[sl.start_position + j] = leaves[j]
            }
        }
        sort_left_dec(sl.leaves_num)
    }
    free_sort_level(sl)
}

/// Single-threaded sort cycle.
func run_sort_cycle_st() {
    while true {
        guard let slc = pop_ls_st() else { break }
        run_sort_level_next(slc)
    }
}

#if SORT_THREADS
/// Multi-threaded sort cycle.
func run_sort_cycle_mt() {
    while true {
        guard let slc = pop_ls_mt() else { break }
        run_sort_level_next(slc)
    }
}

/// Sort cycle thread (in multi-threaded mode).
func sort_thread(_ arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    run_sort_cycle_mt()
    mtsem.signal()
    return arg
}
#endif

/// Run the top sort level.
func run_top_sort_level(_ sl: sort_level) {
    var slc: sort_level?
    reverse_sort = sort_opts_vals.kflag ? keys[0].rflag : default_sort_mods.rflag
    sl.start_position = 0
    sl.sln = 256
    sl.sublevels = Array(repeating: nil, count: 256)
    for i in 0..<sl.tosort_num {
        place_item(sl, i)
    }
    if sl.leaves_num > 1 {
        if keys_num > 1 {
            if sort_opts_vals.sflag {
                mergesort(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll)
            } else {
                DEFAULT_SORT_FUNC_RADIXSORT(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll)
            }
        } else if (!sort_opts_vals.sflag && sort_opts_vals.complex_sort) {
            DEFAULT_SORT_FUNC_RADIXSORT(&sl.leaves!, sl.leaves_num, MemoryLayout<sort_list_item>.size, list_coll_by_str_only)
        }
    }
    if !reverse_sort {
        if let leaves = sl.leaves, var tosort = sl.tosort {
            for j in 0..<sl.leaves_num {
                tosort[sl.start_position + j] = leaves[j]
            }
        }
        sl.start_position += sl.leaves_num
        sort_left_dec(sl.leaves_num)
        for i in 0..<sl.sln {
            if let slc = sl.sublevels?[i] {
                slc.sorted = sl.tosort
                slc.start_position = sl.start_position
                sl.start_position += slc.tosort_num
                push_ls(slc)
                sl.sublevels?[i] = nil
            }
        }
    } else {
        for i in 0..<sl.sln {
            let n = sl.sln - i - 1
            if let slc = sl.sublevels?[n] {
                slc.sorted = sl.tosort
                slc.start_position = sl.start_position
                sl.start_position += slc.tosort_num
                push_ls(slc)
                sl.sublevels?[n] = nil
            }
        }
        if let leaves = sl.leaves, var tosort = sl.tosort {
            for j in 0..<sl.leaves_num {
                tosort[sl.start_position + j] = leaves[j]
            }
        }
        sort_left_dec(sl.leaves_num)
    }
    #if SORT_THREADS
    if nthreads < 2 {
    #endif
        run_sort_cycle_st()
    #if SORT_THREADS
    } else {
        for _ in 0..<nthreads {
            let thread = Thread {
                _ = sort_thread(nil)
            }
            thread.start()
        }
        for _ in 0..<nthreads {
            mtsem.wait()
        }
    }
    #endif
}

/// Run the sort.
func run_sort(_ base: inout [sort_list_item?], _ nmemb: Int) {
    #if SORT_THREADS
    let nthreads_save = nthreads
    if nmemb < MT_SORT_THRESHOLD {
        nthreads = 1
    }
    if nthreads > 1 {
        // Initialize mutex, condition, and semaphore.
        g_ls_mutex = NSLock()
        g_ls_cond = NSCondition()
        mtsem = DispatchSemaphore(value: 0)
    }
    #endif
    
    let sl = sort_level()
    // Initialize sl.
    sl.tosort = base.compactMap { $0 }
    sl.tosort_num = nmemb
    sl.tosort_sz = nmemb
    
    #if SORT_THREADS
    sort_left = nmemb
    #endif
    
    run_top_sort_level(sl)
    free_sort_level(sl)
    
    #if SORT_THREADS
    if nthreads > 1 {
        // Clean up semaphore and mutex if needed.
    }
    nthreads = nthreads_save
    #endif
}

/// The exported sort function.
func rxsort(_ base: inout [sort_list_item?], _ nmemb: Int) {
    run_sort(&base, nmemb)
}
