//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable missing_docs

extension String {
    public struct Alphabet: Hashable, ExpressibleByStringLiteral, Sendable {
        @usableFromInline let pool: Set<Character>
        
        public init(_ chars: some Sequence<Character>) {
            pool = Set(chars)
        }
        
        public init(stringLiteral value: String) {
            self.init(value)
        }
        
        public static func + (lhs: Self, rhs: Self) -> Self {
            Self(lhs.pool.union(rhs.pool))
        }
        
        public func excluding(_ chars: some Sequence<Character>) -> Alphabet {
            Alphabet(pool.subtracting(chars))
        }
    }
}


extension String.Alphabet {
    public static let lowercase: Self = "abcdefghijklmnopqrstuvwxyz"
    public static let uppercase: Self = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    public static let digits: Self = "0123456789"
    public static let alphanumerics: Self = .lowercase + .uppercase + .digits
    public static let printableASCII = Self((0x21...0x7E as ClosedRange<UInt8>).map { Character(UnicodeScalar($0)) })
}


extension String {
    public static func random(from chars: Alphabet, length: Int) -> String {
        var rng = SystemRandomNumberGenerator()
        return .random(from: chars, length: length, using: &rng)
    }
    
    public static func random(from chars: Alphabet, length: Int, using rng: inout some RandomNumberGenerator) -> String {
        guard length > 0 else {
            return ""
        }
        precondition(!chars.pool.isEmpty, "'chars' must contain at least one element!")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            // SAFETY: we check above that chars is not empty;
            // therefore we know for a fact that there will always be at least one element.
            result.append(chars.pool.randomElement(using: &rng).unsafelyUnwrapped)
        }
        return result
    }
}
