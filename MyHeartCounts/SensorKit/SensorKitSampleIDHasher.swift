//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A Hasher that finalizes into a `UUID`; intended to obtain stable unique IDs for SensorKit samples.
///
/// This hasher's `combine` functions work by XOR-ing the input data onto the hasher's internal state (a `UInt128`),
/// in a way that the range of the state onto which an XOR operation is applied is always shifted relative to the previous XOR,
/// by half the size of the previous input (but at least 8 bits).
struct SensorKitSampleIDHasher: ~Copyable {
    private var state: UInt128 = 85073555474209096226415955104694206904
    private var nextShift: Int = 0
    
    init() {}
    
    mutating func combine(_ value: Date) {
        combine(value.timeIntervalSince1970)
    }
    
    mutating func combine(_ value: Double) {
        combine(value.bitPattern)
    }
    
    mutating func combine<T: FixedWidthInteger>(_ input: T) {
        let remainingBitsInState = UInt128.bitWidth - nextShift
        if T.bitWidth <= remainingBitsInState { // ez (no wraparound)
            state ^= UInt128(input) << nextShift
        } else { // oh no (wraparound)
            // XOR the lower bits of `input` into the upper bits of `state`
            state ^= UInt128(input & .bitmask(remainingBitsInState)) << nextShift
            // XOR the upper bits of `input` into the lower bits of `state`
            state ^= ((UInt128(input) >> remainingBitsInState) & .bitmask(T.bitWidth - remainingBitsInState))
        }
        if T.bitWidth == 8 {
            nextShift = (nextShift + T.bitWidth) % UInt128.bitWidth
        } else {
            assert(T.bitWidth.isMultiple(of: 16))
            nextShift = (nextShift + (T.bitWidth / 2)) % UInt128.bitWidth
        }
    }
    
    mutating func combine(_ string: some StringProtocol) {
        combine(string.count)
        for character in string {
            for codePoint in character.utf8 {
                combine(codePoint)
            }
        }
    }
    
    mutating func combine(_ value: Double?) {
        switch value {
        case .none:
            self.combine(0 as UInt8)
        case .some(let value):
            self.combine(1 as UInt8)
            self.combine(value)
        }
    }
    
    mutating func combine(_ value: (some FixedWidthInteger)?) {
        switch value {
        case .none:
            self.combine(0 as UInt8)
        case .some(let value):
            self.combine(1 as UInt8)
            self.combine(value)
        }
    }
    
    consuming func finalize() -> UUID {
        let uuid = UUID(uuid: unsafeBitCast(state, to: uuid_t.self)).makeValidV4()
        assert(uuid.isValidV4)
        return uuid
    }
}


extension FixedWidthInteger {
    /// Constructs a value with the lowest `numBits` bits set to `1`, and everything else set to `0`.
    static func bitmask(_ numBits: Int) -> Self {
        (1 << numBits) - 1
    }
}
