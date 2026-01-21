//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import Foundation
public import NIOFoundationCompat


// MARK: Basic Types

extension Bool: BinaryCodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
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
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        encoder.encodeFullWidthInt(self ? 1 : 0 as UInt8)
    }
}


extension FixedWidthInteger {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        self = try decoder.decodeVarInt(Self.self)
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
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
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        let bitPattern = try decoder.decodeFullWidthInt(UInt32.self)
        self = CFConvertFloatSwappedToHost(CFSwappedFloat32(v: bitPattern))
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        let bitPattern: UInt32 = CFConvertFloatHostToSwapped(self).v
        encoder.encodeFullWidthInt(bitPattern)
    }
}


extension Double: BinaryCodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        let bitPattern = try decoder.decodeFullWidthInt(UInt64.self)
        self = CFConvertDoubleSwappedToHost(CFSwappedFloat64(v: bitPattern))
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        let bitPattern: UInt64 = CFConvertDoubleHostToSwapped(self).v
        encoder.encodeFullWidthInt(bitPattern)
    }
}


extension Date: BinaryCodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        self.init(timeIntervalSince1970: try decoder.decode(TimeInterval.self))
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encode(timeIntervalSince1970)
    }
}


extension String: BinaryCodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        let utf8 = try decoder.decode(Array<UTF8.CodeUnit>.self)
        guard let string = String(bytes: utf8, encoding: .utf8) else {
            throw BinaryDecodingError.other("Unable to decode as UTF-8 String")
        }
        self = string
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encodeLengthPrefixed(self.utf8)
    }
}


// MARK: Collections

extension Array: BinaryEncodable where Element: BinaryEncodable {
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encodeLengthPrefixed(self)
    }
}

extension Array: BinaryDecodable where Element: BinaryDecodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        self = try decoder.decodeLengthPrefixed(Self.self)
    }
}


extension Set: BinaryEncodable where Element: BinaryEncodable {
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        try encoder.encodeLengthPrefixed(self)
    }
}

extension Set: BinaryDecodable where Element: BinaryDecodable {
    public init(fromBinary decoder: BinaryDecoder) throws {
        let length = try decoder.decodeVarInt(Int.self)
        self.init()
        self.reserveCapacity(length)
        for _ in 0..<length {
            self.insert(try decoder.decode(Element.self))
        }
    }
}


extension Data: BinaryCodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        let length = try decoder.decodeVarInt(Int.self)
        self = try decoder.readRawBytes(length: length, byteTransferStrategy: .automatic)
    }
    
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        encoder.encodeVarInt(self.count)
        encoder.writeRawBytes(self)
    }
}


// MARK: Other

extension Optional: BinaryDecodable where Wrapped: BinaryDecodable {
    @inlinable
    public init(fromBinary decoder: BinaryDecoder) throws {
        switch try decoder.decode(Bool.self) {
        case false:
            self = .none
        case true:
            self = .some(try decoder.decode(Wrapped.self))
        }
    }
}

extension Optional: BinaryEncodable where Wrapped: BinaryEncodable {
    @inlinable
    public func binaryEncode(to encoder: BinaryEncoder) throws {
        switch self {
        case .none:
            try encoder.encode(false)
        case .some(let value):
            try encoder.encode(true)
            try encoder.encode(value)
        }
    }
}
