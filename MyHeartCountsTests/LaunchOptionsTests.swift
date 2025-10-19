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


@Suite(.tags(.unitTest), .disabled())
struct LaunchOptionsTests {
    @Test
    func simpleTypes() {
        let options = LaunchOptions.commandLineOptionsContainer(for: [
            "", "--boolOption1", "true"
        ])
        #expect(options[.boolOption1] == true)
    }
    
    @Test
    func boolCanOmitValue() {
        let options1A = LaunchOptions.commandLineOptionsContainer(for: ["", "--boolOption1", "true"])
        let options1B = LaunchOptions.commandLineOptionsContainer(for: ["", "--boolOption1"])
        #expect(options1A[.boolOption1] == options1B[.boolOption1])
        let options2A = LaunchOptions.commandLineOptionsContainer(for: ["", "--boolOption2", "true"])
        let options2B = LaunchOptions.commandLineOptionsContainer(for: ["", "--boolOption2"])
        #expect(options2A[.boolOption2] == options2B[.boolOption2])
    }
    
    @Test
    func idiosyncraticBehaviours() {
        let options1 = LaunchOptions.commandLineOptionsContainer(for: ["", "--intOption", "52"])
        let options2 = LaunchOptions.commandLineOptionsContainer(for: [])
        #expect(options1[.intOption] == 52)
        // the LaunchOption caches its parsed value. might wanna change that at some point, or have it cache by the container / on a per-container basis?
        #expect(options2[.intOption] == 52)
    }
    
    @Test
    func invalidInput() {
        let options = LaunchOptions.commandLineOptionsContainer(for: ["", "--intOption"])
        #expect(options[.intOption] == nil)
    }
}


extension LaunchOptions {
    static let boolOption1 = LaunchOption<Bool>("--boolOption1", default: false)
    static let boolOption2 = LaunchOption<Bool>("--boolOption2", default: true)
    static let intOption = LaunchOption<Int?>("--intOption", default: nil)
}
