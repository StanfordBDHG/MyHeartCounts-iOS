//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable discouraged_optional_boolean

import Foundation
@testable import MyHeartCounts
import Testing


@Suite(.tags(.unitTest))
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
    func boolParsing() {
        let inputs: [(Bool?, [String])] = [
            (true, ["true", "yes", "y", "1", "YES", "Y"]),
            (false, ["false", "no", "n", "0", "NO", "N"]),
            (nil, ["T", "F", "t", "f", "2"])
        ]
        for (expected, inputs) in inputs {
            for input in inputs {
                let options = LaunchOptions.commandLineOptionsContainer(for: ["", "--option", input])
                let option = LaunchOption<Bool?>("--option", default: nil)
                #expect(options[option] == expected, "Failed for input \(input)")
            }
        }
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
        let options1 = LaunchOptions.commandLineOptionsContainer(for: ["", "--intOption"])
        #expect(options1[.intOption] == nil)
        
        let options2 = LaunchOptions.commandLineOptionsContainer(for: ["", "--intOption2"])
        #expect(options2[.intOption2] == 123)
    }
    
    
    @Test
    func url() throws {
        let inputs: [(URL?, [String])] = [
            (.documentsDirectory.appending(component: "hey.txt"), [/*"~/hey.txt",*/ "hey.txt"]),
            ("https://stanford.edu", ["https://stanford.edu"])
        ]
        for (expected, inputs) in inputs {
            let expected = expected?.absoluteURL.resolvingSymlinksInPath()
            for input in inputs {
                let options = LaunchOptions.commandLineOptionsContainer(for: ["", "--url", input])
                let option = LaunchOption<URL?>("--url", default: nil)
                guard let expected else {
                    #expect(options[option] == nil)
                    continue
                }
                let url = try #require(options[option]).absoluteURL.resolvingSymlinksInPath()
                #expect(url == expected, "Failed for input \(input)")
                if url != expected {
                    print("\nFAILED")
                    print("EXPECTED: \(expected)")
                    print("  ACTUAL: \(url)")
                }
            }
        }
    }
}


extension LaunchOptions {
    static let boolOption1 = LaunchOption<Bool>("--boolOption1", default: false)
    static let boolOption2 = LaunchOption<Bool>("--boolOption2", default: true)
    static let intOption = LaunchOption<Int?>("--intOption", default: nil)
    static let intOption2 = LaunchOption<Int?>("--intOption2", default: 123)
}
