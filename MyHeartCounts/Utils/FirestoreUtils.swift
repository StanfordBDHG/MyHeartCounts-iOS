//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFirestore
import Foundation


/// Wrapper used to give ``encodeFirestoreValue(_:using:)`` a dictionary-shaped top level to encode into.
private struct FirestoreEncodingWrapper<T: Encodable>: Encodable {
    /// The key the wrapper's `value` gets encoded into.
    fileprivate static var key: String { "value" }
    let value: T
}


/// Encodes a value into its Firestore representation.
///
/// - Note: `Firestore.Encoder` rejects every top-level value that doesn't encode into a dictionary, which rules out
///     arrays and scalars. We work around this by encoding the value as the single field of a wrapper object,
///     and then unwrapping the encoded result.
private func encodeFirestoreValue(_ value: some Encodable, using encoder: Firestore.Encoder) throws -> Any {
    let wrapper = FirestoreEncodingWrapper(value: value)
    guard let encoded = try encoder.encode(wrapper)[type(of: wrapper).key] else {
        throw EncodingError.invalidValue(value, .init(
            codingPath: [],
            debugDescription: "Encoding a value of type '\(type(of: value))' yielded no Firestore representation"
        ))
    }
    return encoded
}


extension DocumentReference {
    /// Updates the specified fields of the document, encoding the values using Firestore's `Codable` support.
    ///
    /// - parameter fields: the fields to be updated, keyed by `String` or `FieldPath`.
    func updateData(
        _ fields: [AnyHashable: any Codable],
        using encoder: Firestore.Encoder = .init()
    ) async throws {
        let fields = try fields.mapValues {
            try encodeFirestoreValue($0, using: encoder)
        }
        try await self.updateData(fields)
    }
}
