//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// periphery:ignore:all - API


/// A type that can be encoded into a binary representation.
public protocol BinaryEncodable {
    /// Encodes a value into a binary representation.
    func binaryEncode(to encoder: BinaryEncoder) throws
}


/// A type that can be decoded from a binary representation.
public protocol BinaryDecodable {
    /// Decodes a value from a binary representation.
    init(fromBinary decoder: BinaryDecoder) throws
}


/// A type that can be encoded into, and decoded from, a binary representation.
public typealias BinaryCodable = BinaryEncodable & BinaryDecodable
