//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//


/// Bare `CodingKey`.
public struct AnyCodingKey: Swift.CodingKey {
    public let stringValue: String
    public let intValue: Int?
    
    @inlinable
    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    @inlinable
    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
