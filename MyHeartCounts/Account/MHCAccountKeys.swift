//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import FirebaseStorage
import Foundation
import SpeziAccount
import SpeziLocalStorage
import SwiftUI


// MARK: Study & Enrollment

extension AccountDetails {
    /// The date the user first enrolled in the study.
    @AccountKey(
        id: "dateOfEnrollment",
        name: "Date of Enrollment",
        category: .other,
        options: .mutable,
        as: Date.self,
        initial: .empty(.distantPast)
    )
    var dateOfEnrollment: Date?
    
    // NOTE: this is, for the time being, stored using SpeziLocalStorage.
//    /// The date the current study actication, i.e. when the user logged in to the app and started/resumed their study participation.
//    @AccountKey(
//        id: "currentStudyActivationDate",
//        name: "Date of Enrollment",
//        category: .other,
//        options: .mutable,
//        as: Date.self,
//        initial: .empty(.distantPast)
//    )
//    var currentStudyActivationDate: Date?
    
    @AccountKey(
        id: "lastSignedConsentVersion",
        name: "Consent Version",
        as: String.self
    )
    var lastSignedConsentVersion: String?
    
    @AccountKey(
        id: "lastSignedConsentDate",
        name: "Consent Date",
        category: .other,
        options: .mutable,
        as: Date.self,
        initial: .empty(Date(timeIntervalSince1970: 0))
    )
    var lastSignedConsentDate: Date?
}


// MARK: App-Specific Stuff

extension AccountDetails {
    @AccountKey(
        id: "fcmToken",
        name: "FCM Token",
        as: String.self
    )
    var fcmToken: String?
    
    @AccountKey(id: "enableAppDebugMode", name: "Enable App Debug Mode", as: Bool.self)
    var enableDebugMode: Bool? // swiftlint:disable:this discouraged_optional_boolean
    
    @AccountKey(id: "timeZone", name: "Time Zone", as: String.self)
    var timeZone: String?
    
    @AccountKey(
        id: "mostRecentOnboardingStep",
        name: "",
        category: .other,
        options: .mutable,
        as: OnboardingStep.self,
        initial: .default(.init(rawValue: ""))
    )
    var mostRecentOnboardingStep: OnboardingStep?
}


@KeyEntry(
    \.dateOfEnrollment, \.lastSignedConsentVersion, \.lastSignedConsentDate,
    \.fcmToken, \.enableDebugMode, \.timeZone, \.mostRecentOnboardingStep
)
extension AccountKeys {}


// MARK: Other

extension LocalStorageKeys {
    static let studyActivationDate = LocalStorageKey<Date>(
        "edu.stanford.MyHeartCounts.studyActivationDate",
        setting: .unencrypted(excludeFromBackup: true)
    )
}
