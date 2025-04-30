//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SwiftUI


struct LocalPreferenceKey<Value>: Sendable {
    /// The full key for which this preference's values are stored.
    fileprivate let key: String
    fileprivate let read: @Sendable (UserDefaults) -> Value
    fileprivate let write: @Sendable (Value?, UserDefaults) throws -> Void
    fileprivate let makeDefault: @Sendable () -> Value
    
    private init(
        key: String,
        makeDefault: @escaping @Sendable () -> Value,
        read: @escaping @Sendable (String, UserDefaults) -> Value,
        write: @escaping @Sendable (String, Value?, UserDefaults) throws -> Void
    ) {
        // We want to be able to obvserve these entries via KVO, which doesn't work if they appear to be keyPaths,
        // therefore we replace all '.' with '_'.
        let key = "edu.stanford.MyHeartCounts.\(key)".replacingOccurrences(of: ".", with: "_")
        self.key = key
        self.read = { read(key, $0) }
        self.write = { try write(key, $0, $1) }
        self.makeDefault = makeDefault
    }
    
    static func make(
        _ key: String,
        default makeDefault: @autoclosure @escaping @Sendable () -> Value
    ) -> Self where Value: HasDirectUserDefaultsSupport {
        Self(key: key, makeDefault: makeDefault) { key, defaults in
            Value.load(from: defaults, forKey: key) ?? makeDefault()
        } write: { key, newValue, defaults in
            try newValue.store(to: defaults, forKey: key)
        }
    }
    
    static func make(
        _ key: String,
        default makeDefault: @autoclosure @escaping @Sendable () -> Value
    ) -> Self where Value: RawRepresentable, Value.RawValue: HasDirectUserDefaultsSupport {
        Self(key: key, makeDefault: makeDefault) { key, defaults in
            Value.RawValue.load(from: defaults, forKey: key).flatMap(Value.init(rawValue:)) ?? makeDefault()
        } write: { key, newValue, defaults in
            if let rawValue = newValue?.rawValue {
                try rawValue.store(to: defaults, forKey: key)
            } else {
                try Optional<Value.RawValue>.none.store(to: defaults, forKey: key)
            }
        }
    }
    
    @_disfavoredOverload
    static func make(
        _ key: String,
        default makeDefault: @autoclosure @escaping @Sendable () -> Value
    ) -> Self where Value: Codable {
        Self(key: key, makeDefault: makeDefault) { key, defaults in
            let decoder = JSONDecoder()
            if let data = defaults.data(forKey: key) {
                return (try? decoder.decode(Value.self, from: data)) ?? makeDefault()
            } else {
                return makeDefault()
            }
        } write: { key, newValue, defaults in
            let encoder = JSONEncoder()
            let data = try encoder.encode(newValue)
            defaults.set(data, forKey: key)
        }
    }
}


/// Types which can be directly put into a UserDefaults store (bc there is an official overload of the `set(_:forKey:)` function).
protocol HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Self?
    func store(to defaults: UserDefaults, forKey key: String) throws
}


extension Bool: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Bool? { // swiftlint:disable:this discouraged_optional_boolean
        defaults.hasEntry(for: key) ? defaults.bool(forKey: key) : nil
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Int: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Int? {
        defaults.hasEntry(for: key) ? defaults.integer(forKey: key) : nil
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension String: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> String? {
        defaults.string(forKey: key)
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Double: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Double? {
        defaults.hasEntry(for: key) ? defaults.double(forKey: key) : nil
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Float: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Float? {
        defaults.hasEntry(for: key) ? defaults.float(forKey: key) : nil
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension Data: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

extension URL: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> URL? {
        defaults.url(forKey: key)
    }
    func store(to defaults: UserDefaults, forKey key: String) {
        defaults.set(self, forKey: key)
    }
}

//extension Array: HasDirectUserDefaultsSupport where Element: HasDirectUserDefaultsSupport {
//    static func load(from defaults: UserDefaults, forKey key: String) -> Array? {
//        defaults.array(forKey: key)
//    }
//    func store(to defaults: UserDefaults, forKey key: String) {
//        defaults.set(self, forKey: key)
//    }
//}

//extension Dictionary: HasDirectUserDefaultsSupport where Key == String, Value: HasDirectUserDefaultsSupport {
//    
//}

extension Optional: HasDirectUserDefaultsSupport where Wrapped: HasDirectUserDefaultsSupport {
    static func load(from defaults: UserDefaults, forKey key: String) -> Self? {
        if let value = Wrapped.load(from: defaults, forKey: key) {
            Self?.some(value)
        } else {
            Self?.none
        }
    }
    
    func store(to defaults: UserDefaults, forKey key: String) throws {
        if let self = self {
            try self.store(to: defaults, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}


/// Preferences which are stored at device-level, rather than database-package-level
struct LocalPreferencesStore: @unchecked Sendable {
    static let standard = LocalPreferencesStore(defaults: .standard)
    
    fileprivate let defaults: UserDefaults
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    subscript<T>(key: LocalPreferenceKey<T>) -> T {
        get { key.read(defaults) }
        nonmutating set {
            try? key.write(newValue, defaults)
        }
    }
    
    @_disfavoredOverload
    subscript<T>(key: LocalPreferenceKey<T>) -> T? { // we always return nonil values, but allow nil-resetting
        get { key.read(defaults) }
        nonmutating set {
            try? key.write(newValue, defaults)
        }
    }
}


/// `ObservableObject` that publishes a change whenever the specified key in the specified defaults store changes.
@Observable
private final class UserDefaultsKeyObserver: NSObject {
    private struct ObservationContext: Equatable {
        let defaults: UserDefaults
        let key: String
    }
    @ObservationIgnored private var context: ObservationContext?
    private(set) var viewUpdate = false
    
    func configure(for key: String, in userDefaults: UserDefaults) {
        let newContext = ObservationContext(defaults: userDefaults, key: key)
        guard newContext != context else {
            return
        }
        stop()
        userDefaults.addObserver(self, forKeyPath: key, options: [], context: nil)
        context = newContext
    }
    
    // swiftlint:disable:next block_based_kvo discouraged_optional_collection
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == self.context?.key {
            viewUpdate.toggle()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    private func stop() {
        if let context {
            context.defaults.removeObserver(self, forKeyPath: context.key)
            self.context = nil
        }
    }
    
    deinit {
        // ISSUE: it seems like this doesn't always get deallocated right when the view it's attached to gets dismissed.
        // Is there smth we can do about this? at least, to prevent unnecessary view reloads? (prob not...)
        stop()
    }
}


/// A type-safe alternative to SwiftUI's `AppStorage`.
@MainActor
@propertyWrapper
struct LocalPreference<T: Codable>: DynamicProperty {
    private let key: LocalPreferenceKey<T>
    private let store: LocalPreferencesStore
    @State private var kvoObserver = UserDefaultsKeyObserver()
    
    
    var wrappedValue: T {
        get {
            _ = kvoObserver.viewUpdate
            return store[key]
        }
        nonmutating set {
            store[key] = newValue
        }
    }
    
    var projectedValue: Binding<T> {
        _ = kvoObserver.viewUpdate
        return Binding<T> {
            store[key]
        } set: {
            store[key] = $0
        }
    }
    
    init(_ key: LocalPreferenceKey<T>, store: LocalPreferencesStore = .standard) {
        self.key = key
        self.store = store
    }
    
    nonisolated func update() {
        MainActor.assumeIsolated {
            kvoObserver.configure(for: key.key, in: store.defaults)
        }
    }
}


extension UserDefaults {
    fileprivate func hasEntry(for key: String) -> Bool {
        object(forKey: key) != nil
    }
}
