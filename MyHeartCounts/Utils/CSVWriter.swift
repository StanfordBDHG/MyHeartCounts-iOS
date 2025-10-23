//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Algorithms
import Foundation
import System


final class CSVWriter {
    private let separator: Character
    private let fileDescriptor: FileDescriptor
    private let columnHeaders: [String]
    
    init(
        separator: Character = ",", // swiftlint:disable:this function_default_parameter_at_end
        url: URL,
        columns columnHeaders: [String]
    ) throws {
        self.separator = separator
        self.columnHeaders = columnHeaders
        guard let filePath = FilePath(url) else {
            throw NSError(domain: "edu.stanford.MyHeartCounts", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Unable to create FilePath from URL '\(url)'"
            ])
        }
        fileDescriptor = try .open(filePath, .writeOnly, options: [.create, .append], permissions: .ownerReadWrite)
        try appendRow(fields: columnHeaders)
    }
    
    deinit {
        try? fileDescriptor.close()
    }
}


extension CSVWriter {
    enum AppendRowError: Error {
        case invalidNumberOfFields(expected: Int, supplied: Int)
        case writeError(any Error)
    }
    
    func appendRow(fields: [any CSVFieldValue]) throws(AppendRowError) {
        guard fields.count == columnHeaders.count else {
            throw .invalidNumberOfFields(expected: columnHeaders.count, supplied: fields.count)
        }
        let fieldValues = fields.map { normalize($0.csvFieldValue) }
        let bytes: some Sequence<UInt8> = fieldValues.lazy
            .interspersed(with: String(separator))
            .chained(with: CollectionOfOne("\n")).lazy // https://github.com/apple/swift-algorithms/pull/47
            .flatMap { $0.utf8 }
        do {
            try fileDescriptor.writeAll(bytes)
        } catch {
            throw .writeError(error)
        }
    }
    
    
    private func normalize(_ fieldValue: String) -> String {
        let needsQuoting = fieldValue.contains {
            $0.isNewline || $0 == "\"" || $0 == "/" || $0.isUmlaut || $0.lowercased() == "ß"
        }
        guard needsQuoting else {
            return fieldValue
        }
        return fieldValue
            .reduce(into: #"""#) { normalized, char in
                if char == "\"" {
                    normalized.append(#""""#)
                } else {
                    normalized.append(char)
                }
            }
            .appending(#"""#)
    }
}


protocol CSVFieldValue {
    var csvFieldValue: String { get }
}

extension String: CSVFieldValue {
    var csvFieldValue: String {
        // Note that we're intentionally not performing normalization here; this is done by the writer.
        self
    }
}

extension LosslessStringConvertible {
    var csvFieldValue: String {
        String(self)
    }
}

extension Int: CSVFieldValue {}
extension UInt: CSVFieldValue {}
extension Int8: CSVFieldValue {}
extension Int16: CSVFieldValue {}
extension Int32: CSVFieldValue {}
extension Int64: CSVFieldValue {}
extension UInt8: CSVFieldValue {}
extension UInt16: CSVFieldValue {}
extension UInt32: CSVFieldValue {}
extension UInt64: CSVFieldValue {}
extension Double: CSVFieldValue {}
extension Float: CSVFieldValue {}

extension UUID: CSVFieldValue {
    var csvFieldValue: String {
        self.uuidString
    }
}

extension Date: CSVFieldValue {
    var csvFieldValue: String {
        self.ISO8601Format()
    }
}

extension Optional: CSVFieldValue where Wrapped: CSVFieldValue {
    var csvFieldValue: String {
        switch self {
        case .none:
            ""
        case .some(let value):
            value.csvFieldValue
        }
    }
}

extension Array: CSVFieldValue where Element: CSVFieldValue {
    var csvFieldValue: String {
        self.lazy.map(\.csvFieldValue).joined(separator: ",")
    }
}


// MARK: Utils

extension Character {
    var isUmlaut: Bool {
        let lowercased = self.lowercased()
        return lowercased == "ä" || lowercased == "ö" || lowercased == "ü"
    }
}

extension Sequence {
    func chained(with nextSequence: some Sequence<Element>) -> some Sequence<Element> {
        chain(self, nextSequence)
    }
}
