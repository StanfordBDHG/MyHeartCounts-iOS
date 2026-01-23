//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
@testable import MyHeartCounts
import Testing


@Suite
struct UtilsTests {
    @Test
    func closureInputTypeErasure() {
        let timesTwo = { @Sendable (input: Double) -> Double in
            input * 2
        }
        let erasedRounding = erasingClosureInputType(floatToIntHandlingRule: .allowRounding, timesTwo)
        let erasedNoRounding = erasingClosureInputType(floatToIntHandlingRule: .requireLosslessConversion, timesTwo)
        
        #expect(erasedRounding(1 as Double) == 2)
        #expect(erasedRounding(2 as Double) == 4)
        #expect(erasedRounding(1.25 as Double) == 2.5)
        #expect(erasedRounding(1.5 as Float) == 3)
        #expect(erasedRounding(2.7 as Float16) == 5.3984375) // Float16 limitations and rouding
        #expect(erasedRounding(4.5 as Float16) == 9)
        #expect(erasedRounding("1") == nil)
        #expect(erasedRounding(11 as Int) == 22)
        #expect(erasedRounding(22 as UInt) == 44)
        #expect(erasedRounding(1 as Int8) == 2)
        #expect(erasedRounding(2 as Int16) == 4)
        #expect(erasedRounding(3 as Int32) == 6)
        #expect(erasedRounding(4 as Int64) == 8)
        #expect(erasedRounding(5 as UInt8) == 10)
        #expect(erasedRounding(6 as UInt16) == 12)
        #expect(erasedRounding(7 as UInt32) == 14)
        #expect(erasedRounding(8 as UInt64) == 16)
        #expect(erasedRounding(107 as Int128) == 214)
        #expect(erasedRounding(108 as UInt128) == 216)
        
        #expect(erasedNoRounding(1 as Double) == 2)
        #expect(erasedNoRounding(2 as Double) == 4)
        #expect(erasedNoRounding(1.25 as Double) == 2.5)
        #expect(erasedNoRounding(1.5 as Float) == 3)
        #expect(erasedNoRounding(2.7 as Float16) == 5.3984375) // Float16 limitations and rouding
        #expect(erasedNoRounding(4.5 as Float16) == 9)
        #expect(erasedNoRounding("1") == nil)
        #expect(erasedNoRounding(11 as Int) == 22)
        #expect(erasedNoRounding(22 as UInt) == 44)
        #expect(erasedNoRounding(1 as Int8) == 2)
        #expect(erasedNoRounding(2 as Int16) == 4)
        #expect(erasedNoRounding(3 as Int32) == 6)
        #expect(erasedNoRounding(4 as Int64) == 8)
        #expect(erasedNoRounding(5 as UInt8) == 10)
        #expect(erasedNoRounding(6 as UInt16) == 12)
        #expect(erasedNoRounding(7 as UInt32) == 14)
        #expect(erasedNoRounding(8 as UInt64) == 16)
        #expect(erasedNoRounding(107 as Int128) == 214)
        #expect(erasedNoRounding(108 as UInt128) == 216)
    }
    
    @Test
    func closureInputTypeErasure2() {
        let timesTwo = { @Sendable (input: Int) -> Int in
            input * 2
        }
        let erasedRounding = erasingClosureInputType(floatToIntHandlingRule: .allowRounding, timesTwo)
        let erasedNoRounding = erasingClosureInputType(floatToIntHandlingRule: .requireLosslessConversion, timesTwo)
        
        #expect(erasedRounding(1 as Double) == 2)
        #expect(erasedRounding(2 as Double) == 4)
        #expect(erasedRounding(1.25 as Double) == 2)
        #expect(erasedRounding(1.5 as Float) == 2)
        #expect(erasedRounding(2.7 as Float16) == 4)
        #expect(erasedRounding(4.5 as Float16) == 8)
        #expect(erasedRounding("1") == nil)
        #expect(erasedRounding(11 as Int) == 22)
        #expect(erasedRounding(22 as UInt) == 44)
        #expect(erasedRounding(1 as Int8) == 2)
        #expect(erasedRounding(2 as Int16) == 4)
        #expect(erasedRounding(3 as Int32) == 6)
        #expect(erasedRounding(4 as Int64) == 8)
        #expect(erasedRounding(5 as UInt8) == 10)
        #expect(erasedRounding(6 as UInt16) == 12)
        #expect(erasedRounding(7 as UInt32) == 14)
        #expect(erasedRounding(8 as UInt64) == 16)
        #expect(erasedRounding(107 as Int128) == 214)
        #expect(erasedRounding(108 as UInt128) == 216)
        
        #expect(erasedNoRounding(1 as Double) == 2)
        #expect(erasedNoRounding(2 as Double) == 4)
        #expect(erasedNoRounding(1.25 as Double) == nil)
        #expect(erasedNoRounding(1.5 as Float) == nil)
        #expect(erasedNoRounding(2.7 as Float16) == nil)
        #expect(erasedNoRounding(4.5 as Float16) == nil)
        #expect(erasedNoRounding("1") == nil)
        #expect(erasedNoRounding(11 as Int) == 22)
        #expect(erasedNoRounding(22 as UInt) == 44)
        #expect(erasedNoRounding(1 as Int8) == 2)
        #expect(erasedNoRounding(2 as Int16) == 4)
        #expect(erasedNoRounding(3 as Int32) == 6)
        #expect(erasedNoRounding(4 as Int64) == 8)
        #expect(erasedNoRounding(5 as UInt8) == 10)
        #expect(erasedNoRounding(6 as UInt16) == 12)
        #expect(erasedNoRounding(7 as UInt32) == 14)
        #expect(erasedNoRounding(8 as UInt64) == 16)
        #expect(erasedNoRounding(107 as Int128) == 214)
        #expect(erasedNoRounding(108 as UInt128) == 216)
    }
}
