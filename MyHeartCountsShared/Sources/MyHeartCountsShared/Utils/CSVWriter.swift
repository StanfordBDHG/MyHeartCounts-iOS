//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

public import Foundation

/// A CSV Writer.
public struct CSVWriter: ~Copyable {
    private let separator: Character
    private let output: OutputStream
    private let columnHeaders: [String]
    
    /// Creates a new `CSVWriter`
    public init(separator: Character = ",", columns columnHeaders: [String]) throws {
        self.separator = separator
        self.columnHeaders = columnHeaders
        output = .toMemory()
        output.open()
        try appendRow(fields: columnHeaders)
    }
    
    /// Retrieves the written `Data`.
    public consuming func data() -> Data {
        if let data = output.property(forKey: .dataWrittenToMemoryStreamKey) as? Data {
            return data
        } else {
            // according to the docs, this should be unreachable, but just to be safe we still return _something_
            return Data()
        }
    }
    
    deinit {
        if output.streamStatus == .open {
            output.close()
        }
    }
}


extension CSVWriter {
    public enum AppendRowError: Error {
        case invalidNumberOfFields(expected: Int, supplied: Int)
        case writeError(any Error)
    }
    
    /// Appends a new row of fields to the CSV.
    public func appendRow(fields: some RandomAccessCollection<any FieldValue>) throws(AppendRowError) {
        guard fields.count == columnHeaders.count else {
            throw .invalidNumberOfFields(expected: columnHeaders.count, supplied: fields.count)
        }
        do {
            for field in fields.dropLast(1) {
                try output.write(normalize(field.csvFieldValue).utf8)
                try output.write(separator.utf8)
            }
            try output.write(normalize(fields.last!.csvFieldValue).utf8) // swiftlint:disable:this force_unwrapping
            try output.write("\n".utf8)
        } catch {
            throw .writeError(error)
        }
    }
    
    
    private func normalize(_ fieldValue: String) -> String {
        let quote: Character = "\""
        let needsQuoting = fieldValue.contains {
            $0 == separator || $0 == quote || $0.isNewline
        }
        if _fastPath(!needsQuoting) {
            return fieldValue
        } else {
            var result = String()
            result.reserveCapacity(fieldValue.utf8.count + (fieldValue.utf8.count / 8)) // reserve 1.125x as much as the initial string
            result.append(quote)
            for char in fieldValue {
                result.append(char)
                if char == quote {
                    // if the char is a quote, we need to insert a second one, to escape it.
                    result.append(quote)
                }
            }
            result.append(quote)
            return result
        }
    }
}


extension CSVWriter {
    /// A value that can be encoded into a CSV column field.
    public protocol FieldValue {
        /// A CSV-field-compatible representation of the value.
        ///
        /// - Note: The ``CSVWriter`` will take care of ensuring that the string is properly formatted for use within a CSV.
        var csvFieldValue: String { get }
    }
}

extension String: CSVWriter.FieldValue {
    public var csvFieldValue: String {
        self
    }
}

extension LosslessStringConvertible {
    // swiftlint:disable:next missing_docs
    public var csvFieldValue: String {
        String(self)
    }
}

extension Int: CSVWriter.FieldValue {}
extension UInt: CSVWriter.FieldValue {}
extension Int8: CSVWriter.FieldValue {}
extension Int16: CSVWriter.FieldValue {}
extension Int32: CSVWriter.FieldValue {}
extension Int64: CSVWriter.FieldValue {}
extension UInt8: CSVWriter.FieldValue {}
extension UInt16: CSVWriter.FieldValue {}
extension UInt32: CSVWriter.FieldValue {}
extension UInt64: CSVWriter.FieldValue {}
extension Double: CSVWriter.FieldValue {}
extension Float: CSVWriter.FieldValue {}

extension UUID: CSVWriter.FieldValue {
    public var csvFieldValue: String {
        self.uuidString
    }
}

extension Date: CSVWriter.FieldValue {
    public var csvFieldValue: String {
        self.timeIntervalSince1970.csvFieldValue
    }
}

extension Optional: CSVWriter.FieldValue where Wrapped: CSVWriter.FieldValue {
    public var csvFieldValue: String {
        switch self {
        case .none:
            ""
        case .some(let value):
            value.csvFieldValue
        }
    }
}

extension Array: CSVWriter.FieldValue where Element: CSVWriter.FieldValue {
    public var csvFieldValue: String {
        self.lazy.map(\.csvFieldValue).joined(separator: ",")
    }
}


// MARK: Utils

extension OutputStream {
    enum WriteError: Error {
        case reachedCapacity
        case other((any Error)?)
    }
    
    func write(_ bytes: some Sequence<UInt8>) throws(WriteError) { // swiftlint:disable:this cyclomatic_complexity
        let result: Result<Void, WriteError>? = bytes.withContiguousStorageIfAvailable { buffer in
            if let base = buffer.baseAddress, !buffer.isEmpty {
                switch self.write(base, maxLength: buffer.count) {
                case 0:
                    .failure(.reachedCapacity)
                case -1:
                    .failure(.other(self.streamError))
                default:
                    .success(())
                }
            } else {
                .success(())
            }
        }
        switch result {
        case .success:
            return
        case .failure(let error):
            throw error
        case .none:
            // if `bytes` does not provide a contiguous storage, so we need to manually write its contents to the output stream
            for var byte in bytes {
                switch self.write(&byte, maxLength: 1) {
                case 0:
                    throw .reachedCapacity
                case -1:
                    throw .other(self.streamError)
                default:
                    // ok
                    continue
                }
            }
        }
    }
}
