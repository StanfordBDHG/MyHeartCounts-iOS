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
    
    @Dependency(FirebaseConfiguration.self)
    var firebaseConfiguration
    
    @Dependency(StudyManager.self)
    private var studyManager: StudyManager?
    
    @Dependency(Account.self)
    var account: Account?
    
    init() {}

    func respondToEvent(_ event: AccountNotifications.Event) async {
        switch event {
        case .deletingAccount(let accountId):
            // QUESTION we probably also need to delete some more stuff? what about the uploaded HealthKit samples?
            do {
                try await firebaseConfiguration.userDocumentReference.delete()
            } catch {
                logger.error("Could not delete user document: \(error)")
            }
        case .associatedAccount, .detailsChanged, .disassociatingAccount:
            break
        }
    }
}
