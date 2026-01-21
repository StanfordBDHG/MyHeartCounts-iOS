//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import Testing


@Suite
struct BinaryCodingTests {
    private func roundtrip<T: BinaryCodable>(value: T) throws -> T {
        let encoded = try BinaryEncoder.encode(value)
        return try BinaryDecoder.decode(T.self, from: encoded)
    }
    
    @Test
    func simpleTypes() throws {
        #expect(try roundtrip(value: 12) == 12)
        #expect(try roundtrip(value: 12.7) == 12.7)
        #expect(try roundtrip(value: Optional(12)) == 12)
        #expect(try roundtrip(value: Optional(12.7)) == 12.7)
        #expect(try roundtrip(value: "Hello World") == "Hello World")
    }
    
    @Test
    func arrays() throws {
        #expect(try roundtrip(value: [1, 2, 3, 4]) == [1, 2, 3, 4])
        #expect(try roundtrip(value: ["Welcome", "to", "Spezi"]) == ["Welcome", "to", "Spezi"])
    }
}
