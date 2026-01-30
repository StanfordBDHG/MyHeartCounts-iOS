//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - API


extension Dictionary {
    /// How duplicate entries should be handled when merging dictionaries.
    public enum MergeStrategy {
        /// Keep the first key-value pair for a key, and drop any subsequent incoming entries with the same key
        case keepFirst
        /// If there are duplicate keys, later key-value pairs overide previous ones
        case override
        /// Uses the provided closure to merge values for duplicate entries
        case custom((_ key: Key, _ existingValue: Value, _ newValue: Value) -> Value)
        
        public static var expectNoDuplicatesElseFail: Self {
            .custom { _, _, _ in fatalError("Unexpectedly found duplicates.") }
        }
        
        fileprivate func callAsFunction(key: Key, existingValue: Value, newValue: Value) -> Value {
            switch self {
            case .keepFirst:
                existingValue
            case .override:
                newValue
            case .custom(let fn):
                fn(key, existingValue, newValue)
            }
        }
    }
    
    public mutating func merge(_ other: Self, using mergeStrategy: MergeStrategy) {
        for (key, newValue) in other {
            switch self[key] {
            case .none:
                self[key] = newValue
            case .some(let existingValue):
                self[key] = mergeStrategy(key: key, existingValue: existingValue, newValue: newValue)
            }
        }
    }
    
    public func merging(_ other: Dictionary<Key, Value>, using mergeStrategy: MergeStrategy) -> Self {
        var copy = self
        copy.merge(other, using: mergeStrategy)
        return copy
    }
}

extension Dictionary {
    /// Creates a dictionary based on its `Key` type's raw values
    @inlinable
    public init?(_ other: [Key.RawValue: Value]) where Key: RawRepresentable, Key.RawValue: Hashable {
        self.init()
        self.reserveCapacity(other.count)
        for (rawKey, value) in other {
            guard let key = Key(rawValue: rawKey) else {
                return nil
            }
            self[key] = value
        }
    }
    
    /// Creates a Dictionary by mapping a `RawRepresentable` `Key` type into its raw values
    @inlinable
    public init<K: RawRepresentable & Hashable>(_ other: [K: Value]) where Key == K.RawValue {
        self.init()
        self.reserveCapacity(other.count)
        for (key, value) in other {
            self[key.rawValue] = value
        }
    }
}
