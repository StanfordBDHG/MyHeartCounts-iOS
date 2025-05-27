////
//// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
////
//// SPDX-FileCopyrightText: 2025 Stanford University
////
//// SPDX-License-Identifier: MIT
////
//
//// swiftlint:disable static_operator
//
//import Foundation
//import os
//
//
///// Checks if two tuples of arbitrary length are equal.
//func == <each T: Equatable>(_ lhs: (repeat each T), _ rhs: (repeat each T)) -> Bool {
//    for (lhs, rhs) in repeat (each lhs, each rhs) {
//        guard lhs == rhs else {
//            return false
//        }
//    }
//    // The packs either were empty, or everything was equal.
//    return true
//}
//
//
//@_disfavoredOverload
//func == <each T: Equatable>(_ lhs: some Sequence<(repeat each T)>, _ rhs: some Sequence<(repeat each T)>) -> Bool {
//    lhs.elementsEqual(rhs) { (lhs: (repeat each T), rhs: (repeat each T)) -> Bool in
//        // NOTE writing `lhs == rhs` instead causes a compiler crash, rather than a diagnostic. maybe report?
//        (repeat each lhs) == (repeat each rhs)
//    }
//}
//
//
//// https://github.com/apple/swift/issues/73219
//private struct EmptyStruct: Hashable {}
//
//
///// Returns a memoized version of the function, i.e. a function which performs the same operation as `fn`,
///// but internally caches the returned values in order to avoid performing the operation multiple times.
///// - parameter fn: The function which should me memoized. Note that this should be a pure function, i.e. it should not have any side-effects.
//func memoize<each Input: Hashable, Output>(
//    _ fn: @escaping @Sendable (repeat each Input) -> Output // swiftlint:disable:this identifier_name
//) -> @Sendable (repeat each Input) -> Output {
//    let cache = OSAllocatedUnfairLock<[Tuple<repeat each Input>: Output]>(initialState: [:])
//    return { (input: repeat each Input) -> Output in
//        let key = Tuple(repeat each input, EmptyStruct())
//        cache.withLock { storage in
//            if let value = storage[key] {
//                return value
//            } else {
//                let 
//            }
//        }
//        if let value = cache.get(key: key) {
//            return value
//        } else {
//            let value = fn(repeat each input)
//            cache.set(key: key, value: value)
//            return value
//        }
//    }
//}
//
//
///// Returns a memoized version of the function, i.e. a function which performs the same operation as `fn`,
///// but internally caches the returned values in order to avoid performing the operation multiple times.
///// - parameter fn: The function which should me memoized. Note that this should be a pure function, i.e. it should not have any side-effects.
///// - Note: The returned function is **NOT** thread-safe (and also intentionally not `Sendable`).
/////         Use the `memoizeThreadSafe` function instead if you need to call the returned value from multiple threads/concurrency contexts.
/////         This function (`memoizeNonThreadSafe`) exists as an optimisation for situations where we know for a fact that there won't be any concurrent accesses.
//func memoizeNonThreadSafe<each Input: Hashable, Output>(
//    _ fn: @escaping (repeat each Input) -> Output // swiftlint:disable:this identifier_name
//) -> (repeat each Input) -> Output {
//    var cache: [Tuple<repeat each Input, EmptyStruct>: Output] = [:]
//    return { (input: repeat each Input) -> Output in
//        let key = Tuple(repeat each input, EmptyStruct())
//        if let value = cache[key] {
//            return value
//        } else {
//            let value = fn(repeat each input)
//            cache[key] = value
//            return value
//        }
//    }
//}
