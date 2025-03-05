//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziFirebaseAccount
import SpeziViews
import SwiftData
import SwiftUI
import class ModelsR4.QuestionnaireResponse


@main
struct MyHeartCounts: App {
    @UIApplicationDelegateAdaptor(MyHeartCountsDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        ValueTransformer.setValueTransformer(
            JSONEncodingValueTransformer<QuestionnaireResponse>(),
            forName: .init("JSONEncodingValueTransformer<QuestionnaireResponse>")
        )
        let schema = Schema([
            StudyParticipationContext.self, SPCQuestionnaireEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        print("USING SWIFTDATA MODEL CONTAINER AT \(modelConfiguration.url.path)")
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .testingSetup()
                .spezi(appDelegate)
        }
        .modelContainer(sharedModelContainer)
    }
}
