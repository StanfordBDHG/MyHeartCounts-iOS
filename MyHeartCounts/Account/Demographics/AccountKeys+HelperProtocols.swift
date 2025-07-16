//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


protocol RawRepresentableAccountKey: Codable where Self: RawRepresentable, Self: Hashable, Self: Sendable, Self.RawValue: Codable {}

extension RawRepresentableAccountKey {
    public init(from decoder: any Decoder) throws { // swiftlint:disable:this missing_docs
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(RawValue.self)
        if let value = Self(rawValue: rawValue) {
            self = value
        } else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unable to create '\(Self.self) instance from raw value '\(rawValue)'."
            ))
        }
    }
    
    public func encode(to encoder: any Encoder) throws { // swiftlint:disable:this missing_docs
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension RawRepresentable where Self: CaseIterable, RawValue: Equatable {
    init?(rawValue: RawValue) {
        if let value = Self.allCases.first(where: { $0.rawValue == rawValue }) {
            self = value
        } else {
            return nil
        }
    }
}
