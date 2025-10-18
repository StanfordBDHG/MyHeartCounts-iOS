//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import SpeziHealthKit
import SwiftUI


@propertyWrapper
struct TrackedEnvironmentObject<Value: AnyObject & Observable>: DynamicProperty {
    @Environment(Value.self) private var value: Value?
    private let file: StaticString
    private let line: UInt
    
    init(_: Value.Type, _ file: StaticString = #filePath, _ line: UInt = #line) {
        self.file = file
        self.line = line
    }
    
    var wrappedValue: Value {
        if let value {
            return value
        } else {
            fatalError("Missing '\(Value.self)' Environment object at \(file):\(line)")
        }
    }
}



@propertyWrapper
class _TrackedEnvironmentObjectBase<Value>: DynamicProperty {
    var wrappedValue: Value {
        fatalError("missing impl")
    }
    
    func update() {}
}


private class _TrackedEnvironmentObjectKeyPathImpl<Value>: _TrackedEnvironmentObjectBase<Value> {
    @SwiftUI.Environment<Value> var val: Value
    
    override var wrappedValue: Value {
        val
    }
    
    init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        _val = .init(keyPath)
    }
    
    override func update() {
        _val.update()
    }
}


private class _TrackedEnvironmentObjectOptionalImpl<Value>: _TrackedEnvironmentObjectBase<Value?> {
    @SwiftUI.Environment<Value?> var val: Value?
    
    override var wrappedValue: Value? {
        val
    }
    
    init(_ objectType: Value.Type) where Value: AnyObject & Observable {
        _val = .init(objectType)
    }
    
    override func update() {
        _val.update()
    }
}


private class _TrackedEnvironmentObjectNonOptionalImpl<Value>: _TrackedEnvironmentObjectBase<Value> {
    @SwiftUI.Environment<Value?> var val: Value?
    private let file: StaticString
    private let line: UInt
    
    override var wrappedValue: Value {
        if let val {
            return val
        } else {
            fatalError("Missing '\(Value.self)' Environment object at \(file):\(line)")
        }
    }
    
    init(_ objectType: Value.Type, file: StaticString, line: UInt) where Value: AnyObject & Observable {
        _val = .init(objectType)
        self.file = file
        self.line = line
    }
    
    override func update() {
        _val.update()
    }
}



@propertyWrapper
struct _TrackedEnvironmentObject<Value>: DynamicProperty { // swiftlint:disable:this type_name
    @_TrackedEnvironmentObjectBase<Value> private var impl
    
    var wrappedValue: Value {
        impl
    }
    
    init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        _impl = _TrackedEnvironmentObjectKeyPathImpl(keyPath)
    }
    
//    public init(_ objectType: Value.Type) where Value : AnyObject, Value : Observable
//    public init<T>(_ objectType: T.Type) where Value == T?, T : AnyObject, T : Observable
    
    init(_ objectType: Value.Type, _ file: StaticString = #filePath, _ line: UInt = #line) where Value: AnyObject & Observable {
        _impl = _TrackedEnvironmentObjectNonOptionalImpl(objectType, file: file, line: line)
    }
    
    init<T>(_ objectType: T.Type, _ file: StaticString = #filePath, _ line: UInt = #line) where Value == T?, T : AnyObject, T : Observable {
        _impl = _TrackedEnvironmentObjectOptionalImpl(objectType)
    }
    
    func update() {
        _impl.update()
    }
}


extension View {
    @available(*, unavailable, renamed: "TrackedEnvironmentObject", message: "Use the other API instead!")
    typealias Environment2 = _TrackedEnvironmentObject
}

extension DynamicProperty {
    @available(*, unavailable, renamed: "TrackedEnvironmentObject", message: "Use the other API instead!")
    typealias Environment2 = _TrackedEnvironmentObject
}
