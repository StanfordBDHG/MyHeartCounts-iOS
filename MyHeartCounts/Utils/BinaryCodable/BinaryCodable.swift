//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import NIOCore


protocol BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws
}

protocol BinaryDecodable {
    init(fromBinary decoder: BinaryDecoder) throws
}


typealias BinaryCodable = BinaryEncodable & BinaryDecodable


extension RawRepresentable where RawValue: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(self.rawValue)
    }
}


extension RawRepresentable where RawValue: BinaryDecodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        let rawValue = try decoder.decode(RawValue.self)
        guard let value = Self(rawValue: rawValue) else {
            throw BinaryDecodingError.other("Unable to create '\(Self.self)' from raw value")
        }
        self = value
    }
}


// MARK: Primitive Types

extension Bool: BinaryCodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        let byte = try decoder.decodeFullWidthInt(UInt8.self)
        switch byte {
        case 0:
            self = false
        case 1:
            self = true
        default:
            throw BinaryDecodingError.invalidBoolValue(byte)
        }
    }
    
    func binaryEncode(to encoder: BinaryEncoder) throws {
        encoder.encodeFullWidthInt(self ? 1 : 0 as UInt8)
    }
}


extension FixedWidthInteger {
    init(fromBinary decoder: BinaryDecoder) throws {
        self = try decoder.decodeVarInt(Self.self)
    }

    func binaryEncode(to encoder: BinaryEncoder) throws {
        encoder.encodeVarInt(self)
    }
}


extension UInt8: BinaryCodable {}
extension UInt16: BinaryCodable {}
extension UInt32: BinaryCodable {}
extension UInt64: BinaryCodable {}
extension UInt: BinaryCodable {}

extension Int8: BinaryCodable {}
extension Int16: BinaryCodable {}
extension Int32: BinaryCodable {}
extension Int64: BinaryCodable {}
extension Int: BinaryCodable {}


extension Float: BinaryCodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        let bitPattern = try decoder.decodeFullWidthInt(UInt32.self)
        self = CFConvertFloatSwappedToHost(CFSwappedFloat32(v: bitPattern))
    }
    
    func binaryEncode(to encoder: BinaryEncoder) throws {
        let bitPattern: UInt32 = CFConvertFloatHostToSwapped(self).v
        encoder.encodeFullWidthInt(bitPattern)
    }
}


extension Double: BinaryCodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        let bitPattern = try decoder.decodeFullWidthInt(UInt64.self)
        self = CFConvertDoubleSwappedToHost(CFSwappedFloat64(v: bitPattern))
    }
    
    func binaryEncode(to encoder: BinaryEncoder) throws {
        let bitPattern: UInt64 = CFConvertDoubleHostToSwapped(self).v
        encoder.encodeFullWidthInt(bitPattern)
    }
}


protocol BinaryEncodableCollection: Collection, BinaryEncodable where Element: BinaryEncodable {}

extension BinaryEncodableCollection {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        encoder.encodeVarInt(self.count)
        for element in self {
            try encoder.encode(element)
        }
    }
}


// TODO model this as a typealias instead of a protocol?!
protocol BinaryDecodableCollection: Collection, BinaryDecodable where Element: BinaryDecodable {
    init(_ elements: [Element])
}

extension BinaryDecodableCollection {
    init(fromBinary decoder: BinaryDecoder) throws {
        let count = try decoder.decodeVarInt(Int.self)
        var elements: [Element] = []
        elements.reserveCapacity(count)
        for _ in 0..<count {
            elements.append(try decoder.decode(Element.self))
        }
        self.init(elements)
    }
}

typealias BinaryCodableCollection = BinaryEncodableCollection & BinaryDecodableCollection


extension Array: BinaryEncodable, BinaryEncodableCollection where Element: BinaryEncodable {}
extension Array: BinaryDecodable, BinaryDecodableCollection where Element: BinaryDecodable {}


extension String: BinaryCodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        let utf8 = try decoder.decode(Array<UTF8.CodeUnit>.self)
        self.init(bytes: utf8, encoding: .utf8)!
    }
    
    func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encodeLengthPrefixed(self.utf8)
    }
}


extension Optional: BinaryDecodable where Wrapped: BinaryDecodable {
    init(fromBinary decoder: BinaryDecoder) throws {
        switch try decoder.decode(Bool.self) {
        case false:
            self = .none
        case true:
            self = .some(try decoder.decode(Wrapped.self))
        }
    }
}

extension Optional: BinaryEncodable where Wrapped: BinaryEncodable {
    func binaryEncode(to encoder: BinaryEncoder) throws {
        switch self {
        case .none:
            try encoder.encode(false)
        case .some(let value):
            try encoder.encode(true)
            try encoder.encode(value)
        }
    }
}
