//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import SFSafeSymbols
public import SpeziStudyDefinition


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


extension TimedWalkingTestConfiguration.Kind {
    /// A SFSymbol suitable for the test
    @inlinable public var symbol: SFSymbol {
        switch self {
        case .walking: .figureWalk
        case .running: .figureRun
        }
    }
}
