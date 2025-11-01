//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


protocol BinaryEncodable {
    /// Encodes a value into a binary representation.
    func binaryEncode(to encoder: BinaryEncoder) throws
}

protocol BinaryDecodable {
    /// Decodes a value from a binary representation.
    init(fromBinary decoder: BinaryDecoder) throws
}

typealias BinaryCodable = BinaryEncodable & BinaryDecodable
