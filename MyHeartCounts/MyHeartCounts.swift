//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

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
            OnboardingSheet(
                didCompleteOnboarding: $didCompleteOnboarding
            )
            .environment(StudyDefinitionLoader.shared)
        }
        .environment(appDelegate)
        .modelContainer(modelContainer)
    }
}
