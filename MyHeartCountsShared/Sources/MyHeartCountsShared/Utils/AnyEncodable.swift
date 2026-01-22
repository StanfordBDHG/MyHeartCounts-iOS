//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


public struct AnyEncodable: Encodable {
    var value: any Encodable
    
    public init(_ value: any Encodable) {
        self.value = value
    }
    
    public func encode(to encoder: any Encoder) throws {
        try value.encode(to: encoder)
    }
}
