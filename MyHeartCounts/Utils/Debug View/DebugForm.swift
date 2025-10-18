//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_types_order

import Foundation
import SFSafeSymbols
import SpeziAccount
import SpeziFoundation
import SpeziLocalStorage
import SpeziStudy
import SpeziStudyDefinition
import SpeziViews
import SwiftUI
import UIKit
import XCTSpeziNotificationsUI


struct DebugForm: View {
    var body: some View {
        DebugFormImpl()
            .taskPerformingAnchor()
    }
}


private struct DebugFormImpl: View {
    // swiftlint:disable attributes
    @Environment(\.colorScheme) private var colorScheme
    @Environment(StudyManager.self) private var studyManager
    @LocalPreference(.sendHealthSampleUploadNotifications) private var healthUploadNotifications
    @LocalStorageEntry(.rejectedHomeTabPromptedActions) private var rejectedHomeTabActions
    @PerformTask private var performTask
    // swiftlint:enable attributes
    
    var body: some View {
        Form { // swiftlint:disable:this closure_body_length
            Section("Notifications") {
                Toggle(isOn: $healthUploadNotifications) {
                    Label("Live Health Upload Notifications", systemSymbol: .arrowUpHeart)
                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                }
                NavigationLink(symbol: .appBadge, "Notifications Status") {
                    NotificationsManagerControlView()
                }
                NavigationLink(symbol: .bellBadge, "Scheduled Local Notifications") {
                    PendingNotificationsList()
                }
            }
            Section("Other") {
                NavigationLink(symbol: .calendar, "Health Data Bulk Upload") {
                    HealthImporterControlView()
                }
                NavigationLink("SensorKit") {
                    SensorKitControlView()
                }
                Button("Reset rejeted HomeTab actions") {
                    rejectedHomeTabActions = []
                }
                Button {
                    performTask(.timedWalkTest(.sixMinuteWalkTest), context: nil)
                } label: {
                    Label("Timed Walking Test", systemSymbol: .figureWalk)
                }
                Button("Answer HeartRisk Questionnaire") {
                    let fileRef = StudyBundle.FileReference(category: .questionnaire, filename: "HeartRisk", fileExtension: "json")
                    if let questionnaire = studyManager.studyEnrollments.first?.studyBundle?.questionnaire(for: fileRef, in: .enUS) {
                        performTask(.answerQuestionnaire(questionnaire), context: nil)
                    }
                }
                Button("Replace Root View Controller", role: .destructive) {
                    // The idea here is that discarding the root view controller should deallocate all our resources.
                    // We can then launch Xcode's memory graph debugger, and anything that's still in the left sidebar is leaked.
                    replaceRootVC()
                }
            }
        }
        .navigationTitle("Debug Options")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func replaceRootVC() {
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return
        }
        window.rootViewController = UIViewController()
    }
}


extension DebugForm {
    // periphery:ignore - occasionally useful
    struct EnrollmentTestingView: View {
        @Environment(Account.self)
        private var account: Account
        @Environment(StudyManager.self)
        private var studyManager
        @State private var viewState: ViewState = .idle
        
        let refresh: @MainActor () -> Void
        
        var body: some View {
            AsyncButton("Enroll", state: $viewState) {
                guard let enrollmentDate = account.details?.dateOfEnrollment else {
                    throw NSError(domain: "edu.stanford.MHC", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No Enrollment Date"
                    ])
                }
                let studyBundle = try await StudyBundleLoader.shared.update()
                try await studyManager.enroll(in: studyBundle, enrollmentDate: enrollmentDate - Duration.days(5).timeInterval)
                refresh()
            }
            AsyncButton("Unenroll", state: $viewState) {
                guard let enrollment = studyManager.studyEnrollments.first else {
                    return
                }
                try studyManager.unenroll(from: enrollment)
                refresh()
            }
            .viewStateAlert(state: $viewState)
        }
    }
}


extension Locale {
    static let enUS = Locale(identifier: "en-US")
}
