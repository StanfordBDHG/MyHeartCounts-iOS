//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


/// Utility property wrapper that simplifies the "use the `.task` modifier and an `AsyncStream` to propagate a value
/// (from e.g. an `onPreferenceChange` callback) back into a `View`.
@propertyWrapper
struct AsyncStreamTracked<Value>: DynamicProperty {
    @State private(set) var stream: AsyncStream<Value>
    @State private(set) var continuation: AsyncStream<Value>.Continuation
    @State private var currentValue: Value
    
    var wrappedValue: Value {
        currentValue
    }
    
    var projectedValue: Self {
        self
    }
    
    init(wrappedValue: Value) {
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self)
        _stream = .init(wrappedValue: stream)
        _continuation = .init(wrappedValue: continuation)
        _currentValue = .init(wrappedValue: wrappedValue)
    }
    
    init() where Value: ExpressibleByNilLiteral {
        self.init(wrappedValue: nil)
    }
    
    func startTracking() async {
        for await value in stream {
            currentValue = value
        }
        (stream, continuation) = AsyncStream.makeStream()
    }
    
    func yield(_ value: sending Value) {
        continuation.yield(value)
    }
}

extension AsyncStreamTracked: Sendable where Value: Sendable {}
