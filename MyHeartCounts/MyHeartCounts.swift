//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import OSLog
import Spezi
import SwiftData
import SwiftUI


// intentionally a global variable
let logger = Logger(subsystem: "edu.stanford.MyHeartCounts", category: "")


@main
struct MyHeartCounts: App {
    @UIApplicationDelegateAdaptor(MyHeartCountsDelegate.self)
    private var appDelegate
    
    @LocalPreference(.onboardingFlowComplete)
    private var didCompleteOnboarding
    
    private let modelContainer: ModelContainer = {
        let schema = Schema([CustomHealthSample.self], version: .init(0, 0, 1))
        let configuration = ModelConfiguration(
            "MyHeartCounts",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, migrationPlan: nil, configurations: configuration)
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }
    }()
    
//    init() {
//        do {
//            let timesTwo = { @Sendable (input: Double) -> Double in
//                input * 2
//            }
//            func checkEq(_ actual: Double?, _ expected: Double) {
//                precondition(actual == expected, "\(actual) VS \(expected)")
//            }
//            let erased = erasingClosureInputType(floatToIntConversionRule: .allowRounding, timesTwo)
//            checkEq(erased(1 as Double), 2)
//            checkEq(erased(2 as Double), 4)
//            checkEq(erased(1.25 as Double), 2.5)
//            checkEq(erased(1.5 as Float), 3)
//            checkEq(erased(4.5 as Float16), 9)
//            checkEq(erased(2.7 as Float16), 5.4)
//            precondition(erased("1") == nil)
//            checkEq(erased(11 as Int), 22)
//            checkEq(erased(22 as UInt), 44)
//            checkEq(erased(1 as Int8), 2)
//            checkEq(erased(2 as Int16), 4)
//            checkEq(erased(3 as Int32), 6)
//            checkEq(erased(4 as Int64), 8)
//            checkEq(erased(5 as UInt8), 10)
//            checkEq(erased(6 as UInt16), 12)
//            checkEq(erased(7 as UInt32), 14)
//            checkEq(erased(8 as UInt64), 16)
//            checkEq(erased(107 as Int128), 214)
//            checkEq(erased(108 as UInt128), 216)
//        }
//        
//        do {
//            let timesTwo = { @Sendable (input: Int) -> Int in
//                input * 2
//            }
//            func checkEq(_ actual: Int?, _ expected: Int) {
//                precondition(actual == expected, "\(actual) VS \(expected)")
//            }
//            let erased = erasingClosureInputType(floatToIntConversionRule: .allowRounding, timesTwo)
//            checkEq(erased(1 as Double), 2)
//            checkEq(erased(2 as Double), 4)
//            checkEq(erased(1.25 as Double), 2)
//            checkEq(erased(1.5 as Float), 2)
//            checkEq(erased(2.7 as Float16), 4)
//            precondition(erased("1") == nil)
//            checkEq(erased(11 as Int), 22)
//            checkEq(erased(22 as UInt), 44)
//            checkEq(erased(1 as Int8), 2)
//            checkEq(erased(2 as Int16), 4)
//            checkEq(erased(3 as Int32), 6)
//            checkEq(erased(4 as Int64), 8)
//            checkEq(erased(5 as UInt8), 10)
//            checkEq(erased(6 as UInt16), 12)
//            checkEq(erased(7 as UInt32), 14)
//            checkEq(erased(8 as UInt64), 16)
//            checkEq(erased(107 as Int128), 214)
//            checkEq(erased(108 as UInt128), 216)
//        }
//    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .spezi(appDelegate)
            OnboardingSheet(
                didCompleteOnboarding: $didCompleteOnboarding
            )
            .environment(StudyDefinitionLoader.shared)
        }
        .environment(appDelegate)
        .modelContainer(modelContainer)
    }
}
