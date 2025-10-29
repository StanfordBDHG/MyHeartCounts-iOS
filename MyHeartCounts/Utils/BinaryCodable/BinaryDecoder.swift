//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import NIOCore
import NIOFoundationCompat



enum BinaryDecodingError: Swift.Error {
    case noData
    case unableToDecodeVarInt(message: String)
    case invalidRawValue(Any.Type, Any.Type, Data)
    case invalidBoolValue(UInt8)
    case other(String)
}


final class BinaryDecoder {
    private var buffer: ByteBuffer
    
    var readableBytes: Int { buffer.readableBytes }
    
    init(buffer: ByteBuffer) {
        self.buffer = buffer
    }
    
    
    static func decode<T: BinaryDecodable>(_ ty: T.Type, from buffer: ByteBuffer) throws -> T {
        let decoder = BinaryDecoder(buffer: buffer)
        return try ty.init(fromBinary: decoder)
    }
    
    static func decode<T: BinaryDecodable>(_ ty: T.Type, from data: some DataProtocol) throws -> T {
        let buffer = ByteBuffer(bytes: data)
        return try decode(ty, from: buffer)
    }
    
    
    
    func decode<T: BinaryDecodable>(_ ty: T.Type) throws -> T {
        try ty.init(fromBinary: self)
    }
    
    func decodeLengthPrefixed<C: BinaryDecodableCollection>(_ ty: C.Type) throws -> C {
        try ty.init(fromBinary: self)
    }
    
    func decodeString(length: Int, encoding: String.Encoding = .utf8) throws -> String {
        if let string = buffer.readString(length: length, encoding: encoding) {
            return string
        } else {
            throw BinaryDecodingError.other("Unable to read string")
        }
    }
    
    
    
    func decodeFullWidthInt<T: FixedWidthInteger>(_: T.Type) throws -> T {
        if let value = buffer.readInteger(endianness: .big, as: T.self) {
            return value
        } else{
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unable to read \(T.self)"))
        }
    }
    
    
    /// Reads the value at the current reader index as a VarInt
    /// - returns: the read number, or `nil` if we were unable to read a number (e.g. because there's no data left to be read)
    func decodeUInt64VarInt() throws -> UInt64 {
        guard buffer.readableBytes > 0 else {
            throw BinaryDecodingError.noData
        }
        var bytes: [UInt8] = [
            buffer.readInteger(endianness: .little, as: UInt8.self)! // We know there's at least one byte.
        ]
        while (bytes.last! & (1 << 7)) != 0 {
            // we have another byte to parse
            guard let nextByte = buffer.readInteger(endianness: .little, as: UInt8.self) else {
                throw BinaryDecodingError.unableToDecodeVarInt(
                    message: "Unexpectedly found no byte to read (even though the VarInt's previous byte indicated that there's be one)"
                )
            }
            bytes.append(nextByte)
        }
        precondition(bytes.count <= 10) // maximum length of a var int is 10 bytes, for negative integers
        
        var result: UInt64 = 0
        for (idx, byte) in bytes.enumerated() { // NOTE that this loop will iterate the VarInt's bytes **least-significant-byte first**!
            result |= UInt64(byte & 0b1111111) << (idx * 7)
        }
        return result
    }
    
    
    func decodeVarInt<T: FixedWidthInteger>(_ ty: T.Type) throws -> T {
        let u64Value = try decodeUInt64VarInt()
        return ty.init(truncatingIfNeeded: u64Value)
    }
}
