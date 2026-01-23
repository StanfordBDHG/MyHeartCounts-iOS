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


@Suite//(.tags(.unitTest))
struct NHSNumberTests {
    @Test
    func validate() {
        #expect(NHSNumber(validating: "943 476 5919") != nil)
        #expect(NHSNumber(validating: "901 234 5678") == nil)
        #expect(NHSNumber(validating: "987 654 4321") == nil)
        #expect(NHSNumber(validating: "999 999 9999") != nil)
        
        #expect(NHSNumber(validating: "943-476-5919") != nil)
        #expect(NHSNumber(validating: "901-234-5678") == nil)
        #expect(NHSNumber(validating: "987-654-4321") == nil)
        #expect(NHSNumber(validating: "999-999-9999") != nil)
        
        #expect(NHSNumber(validating: "9434765919") != nil)
        #expect(NHSNumber(validating: "9012345678") == nil)
        #expect(NHSNumber(validating: "9876544321") == nil)
        #expect(NHSNumber(validating: "9999999999") != nil)
    }
}
