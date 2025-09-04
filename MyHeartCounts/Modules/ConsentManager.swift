//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseStorage
import Foundation
import Spezi
import SpeziLocalization
import SpeziAccount
import SpeziFoundation
import SpeziStudy
import SwiftUI


@Observable
final class ConsentManager: Module, EnvironmentAccessible, @unchecked Sendable {
    // swiftlint:disable attributes
    @ObservationIgnored @StandardActor private var standard: MyHeartCountsStandard
    @ObservationIgnored @Dependency(StudyBundleLoader.self) private var studyBundleLoader
    @ObservationIgnored @Dependency(Account.self) private var account: Account?
    @ObservationIgnored @Dependency(StudyManager.self) private var studyManager
    @ObservationIgnored @LocalPreference(.onboardingFlowComplete) private var onboardingFlowComplete
    // swiftlint:enable attributes
    
    @MainActor private(set) var needsToSignNewConsentVersion = false
    
    nonisolated init() {}
    
    func configure() {
        Task {
            await doUpdate()
        }
    }
    
    @MainActor
    private func doUpdate() async {
        let studyBundle = withObservationTracking {
            studyBundleLoader.studyBundle?.value
        } onChange: {
            Task {
                await self.doUpdate()
            }
        }
        guard onboardingFlowComplete else {
            return
        }
        guard !needsToSignNewConsentVersion else {
            return
        }
        guard let studyBundle else {
            return
        }
        guard let accountDetails = account?.details else {
            return
        }
        guard let consentFile = studyBundle.studyDefinition.metadata.consentFileRef,
              let consentText = studyBundle.consentText(for: consentFile, in: studyManager.preferredLocale),
              let consentVersion = (try? MarkdownDocument.Metadata(parsing: consentText))?.version else {
                  return
        }
        if let lastSignedVersion = accountDetails.lastSignedConsentVersion.flatMap(Version.init) {
            needsToSignNewConsentVersion = consentVersion.isGreaterThan(lastSignedVersion, upFrom: .minor)
        } else {
            // we're unable to get the most recent signed, so we'll make the user re-sign it
//            await MainActor.run {
//                self.needsToSignNewConsentVersion = true
//            }
        }
    }
}


extension Version {
    /// A component of a version.
    public enum Component {
        /// The major component
        case major
        /// The minor component
        case minor
        /// The patch component
        case patch
    }
    
    /// Determines if the version is equal to another version, up to the specified component.
    @inlinable
    public func isEqual(to other: Version, downTo component: Component) -> Bool {
        switch component {
        case .major:
            self.major == other.major
        case .minor:
            self.major == other.major && self.minor == other.minor
        case .patch:
            self.major == other.major && self.minor == other.minor && self.patch == other.patch
        }
    }
    
    /// Determines if the version is greater than another version, starting at the specified component.
    @inlinable
    public func isGreaterThan(_ other: Version, upFrom component: Component) -> Bool {
        switch component {
        case .major:
            self.major > other.major
        case .minor:
            isGreaterThan(other, upFrom: .major) || self.major == other.major && self.minor > other.minor
        case .patch:
            isGreaterThan(other, upFrom: .minor) || self.minor == other.minor && self.patch > other.patch
        }
    }
}


extension AccountDetails {
    @AccountKey(id: "lastSignedConsentVersion", name: "Consent Version", as: String.self)
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

@KeyEntry(\.lastSignedConsentVersion, \.lastSignedConsentDate)
extension AccountKeys {}
