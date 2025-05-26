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
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .spezi(appDelegate)
                .onAppear {
                    return;
                    let scoreDef = ScoreDefinition(default: 0, mapping: [
                        .inRange(0...5, score: 1)
                    ])
                    precondition(scoreDef.apply(to: 1) == 1)
                    precondition(scoreDef.apply(to: 1.0) == 1)
                    precondition(scoreDef.apply(to: 10) == 0)
                    precondition(scoreDef.apply(to: 10.0) == 0)
                    precondition(scoreDef.apply(to: 5) == 1)
                    precondition(scoreDef.apply(to: 5.0) == 1)
                    precondition(scoreDef.apply(to: 5.5) == 0)
                    
                    var cal = Calendar(identifier: .gregorian)
                    cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
                    
                    func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T) {
                        precondition(lhs == rhs, "\(lhs) != \(rhs)")
                    }
                    
                    do {
                        let date1 = cal.date(from: .init(timeZone: .gmt, year: 2025, month: 5, day: 24, hour: 7, minute: 6, second: 44, nanosecond: Int(1e9 * 0.2320943)))!
                        print(date1.formatted(.iso8601.timeZone(cal.timeZone)))
                        expectEqual(date1.timeIntervalSinceReferenceDate, 769763204.2320943)
                        expectEqual(date1.timeIntervalSinceReferenceDate - 769763204.2320943, 0)
                        let date2 = cal.date(from: .init(year: 2025, month: 5, day: 24, hour: 12, minute: 0, second: 0))!
                        print(date2.formatted(.iso8601.timeZone(cal.timeZone)))
                        expectEqual(cal.makeNoon(date1),  date2)
                    }
                    
                    do {
                        let date1 = cal.date(from: .init(timeZone: .gmt, year: 2025, month: 5, day: 25, hour: 3, minute: 49, second: 27, nanosecond: Int(1e9 * 0.886064)))!
                        print(date1.formatted(.iso8601.timeZone(cal.timeZone)))
                        expectEqual(date1.timeIntervalSinceReferenceDate, 769837767.886064)
                        expectEqual(date1.timeIntervalSinceReferenceDate - 769837767.886064, 0)
                        let date2 = cal.date(from: .init(year: 2025, month: 5, day: 25, hour: 12, minute: 0, second: 0))!
                        print(date2.formatted(.iso8601.timeZone(cal.timeZone)))
                        expectEqual(cal.makeNoon(date1), date2)
                    }
                    
                    do {
                        let date1 = Date(timeIntervalSinceReferenceDate: 769763204.2320942)
                        let date2 = cal.date(from: .init(/*timeZone: .gmt, */year: 2025, month: 5, day: 24, hour: 12, minute: 0, second: 0))!
                        expectEqual(cal.makeNoon(date1), date2)
                    }
                    
                    do {
                        let date1 = Date(timeIntervalSinceReferenceDate: 769837767.886064)
                        let date2 = cal.date(from: .init(/*timeZone: .gmt, */year: 2025, month: 5, day: 25, hour: 12, minute: 0, second: 0))!
                        expectEqual(cal.makeNoon(date1), date2)
                    }
//                    fatalError()
                }
            OnboardingSheet(
                didCompleteOnboarding: $didCompleteOnboarding
            )
            .environment(StudyDefinitionLoader.shared)
        }
        .environment(appDelegate)
        .modelContainer(modelContainer)
    }
}
