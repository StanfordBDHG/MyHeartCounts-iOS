//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseStorage
import HealthKitOnFHIR
import OSLog
@preconcurrency import PDFKit.PDFDocument
import Spezi
import SpeziAccount
import SpeziFirebaseAccount
import SpeziFirestore
import SpeziHealthKit
import SpeziQuestionnaire
import SpeziStudy
import SwiftUI


actor MyHeartCountsStandard: Standard, EnvironmentAccessible, AccountNotifyConstraint {
    @Application(\.logger)
    private var logger
    
    @Dependency var firebaseConfiguration = FirebaseConfiguration(setupTestAccount: FeatureFlags.setupTestAccount)
    
    @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    @Dependency(Account.self)
    var account: Account?
    
    init() {}

    func respondToEvent(_ event: AccountNotifications.Event) async {
        switch event {
        case .deletingAccount:
            // QUESTION deleting the userDocument will probably also delete everything nested w/in it (eg: Questionnaire Resonse
            // NOTE: we want as many of these as possible to succeed; hence why we use try? everywhere...
            try? FileManager.default.removeItem(at: .scheduledHealthKitUploads)
            try? await firebaseConfiguration.userDocumentReference.delete()
            if let studyManager {
                await MainActor.run {
                    guard let enrollment = studyManager.studyEnrollments.first(where: { $0.studyId == mockMHCStudy.id }) else {
                        return
                    }
                    try? studyManager.unenroll(from: enrollment)
                }
            }
        case .associatedAccount, .detailsChanged, .disassociatingAccount:
            break
        }
    }
}
