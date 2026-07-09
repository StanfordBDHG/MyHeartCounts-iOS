//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Algorithms
import MyHeartCountsShared
import SpeziFoundation
import SpeziStudyDefinition
import XCTest
import XCTestExtensions


final class ConsentRenewalTests: MHCTestCase, Sendable {
    private func onDiskConsentVersion(for locale: Locale) throws -> Version {
        let studyBundle = try StudyBundle(bundleUrl: try XCTUnwrap(studyBundleUrl))
        let consentFileRef = try XCTUnwrap(studyBundle.studyDefinition.metadata.consentFileRef)
        let url = try XCTUnwrap(studyBundle.resolve(consentFileRef, in: locale))
        let text = try String(contentsOf: url, encoding: .utf8)
        let match = try XCTUnwrap(text.firstMatch(of: /^version: (?<value>.*)$/.anchorsMatchLineEndings()))
        return try XCTUnwrap(Version(String(match.output.value)))
    }
    
    
    func testConsentRenewalNewMajor() throws {
        try _implTestConsentRenewal(nextVersion: \.nextMajor, expectRenewalFlow: true)
    }
    
    func testConsentRenewalNewMinor() throws {
        try _implTestConsentRenewal(nextVersion: \.nextMinor, expectRenewalFlow: true)
    }
    
    func testConsentRenewalNewPatch() throws {
        try _implTestConsentRenewal(nextVersion: \.nextPatch, expectRenewalFlow: false)
    }
    
    
    /// Test the consent renewal flow.
    ///
    /// This test verifies that if the last-signed consent version is lower than the current one, the app prompts the user to renew their consent
    /// (unless the patch was changed and major and minor remain equal).
    /// It also checks that if the last-signed version is equal to the current one in major and minor, and only the patch is smaller (ie, a new consent revision
    /// has been published since the user signed the consent, but it only differs in the patch component), no renewal flow is presented.
    private func _implTestConsentRenewal( // swiftlint:disable:this function_body_length
        nextVersion nextVersionKeyPath: KeyPath<Version, Version>,
        expectRenewalFlow: Bool
    ) throws {
        let locale: Locale = .enUS
        
        func overwriteOnDiskConsentVersion(to newVersion: Version) throws {
            let studyBundle = try StudyBundle(bundleUrl: try XCTUnwrap(studyBundleUrl))
            let consentFileRef = try XCTUnwrap(studyBundle.studyDefinition.metadata.consentFileRef)
            let url = try XCTUnwrap(studyBundle.resolve(consentFileRef, in: locale))
            var text = try String(contentsOf: url, encoding: .utf8)
            text.replace(/^version: (.*)$/.anchorsMatchLineEndings(), maxReplacements: 1) { _ in
                "version: \(newVersion.description)"
            }
            try Data(text.utf8).write(to: url)
        }
        
        let config = SetupTestEnvironmentConfig(
            // note: having the reset here happen is important for the test below to work properly,
            // since otherwise we'd also need to increment the study bundle revision each time we launch
            // the app with a new consent version. (bc otherwise it wouldn't update the study bundle w/in
            // SpeziStudy, but if we first reset the app it won't have a prev enrollment and will simply
            // ingest the new one. which is exactly what we want, since the lastSignedConsentVersion
            // is stored on the server anyway.)
            resetExistingData: true,
            loginAndEnroll: .enable(.random())
        )
        try launchAppAndEnrollIntoStudy(
            locale: locale,
            testEnvironmentConfig: config
        )
        // no consent renewal flow
        XCTAssert(app.staticTexts.matching("label CONTAINS[c] %@", "Consent").element.waitForNonExistence(timeout: 5))
        
        /// Fetches the last-signed consent version, via the account sheet
        ///
        /// - invariant: requires that the app be on either of the root-level tabs, and no sheets are open.
        func determineLastSignedConsentVersion() -> Version? {
            openAccountSheet()
            app.swipeUp()
            app.swipeUp()
            XCTAssert(app.otherElements["MHC:AboutRow"].waitForExistence(timeout: 2))
            app.otherElements["MHC:AboutRow"].tap(withNumberOfTaps: 5, numberOfTouches: 1)
            
            let sheet = app.otherElements["MHC:AboutRow:ExtendedInfoSheet"]
            XCTAssert(sheet.waitForExistence(timeout: 2))
            app.expandSheet(sheet)
            
            let label = sheet.staticTexts.matching("label LIKE %@", "lastSignedConsentVersion, *.*.*").element.label
            let versionPart = String(label.suffix { !$0.isWhitespace })
            let version = Version(versionPart)
            // dismiss the extended info sheet
            sheet.navigationBars.buttons["Close"].tap()
            closeAccountSheet()
            return version
        }
        
        // verify that the test env setup will have implicitly had the user sign the current consent.
        XCTAssertEqual(try XCTUnwrap(determineLastSignedConsentVersion()), try onDiskConsentVersion(for: locale))
        app.terminate()
        
        let initialOnDiskConsentVersion = try onDiskConsentVersion(for: locale)
        let nextConsentVersion = initialOnDiskConsentVersion[keyPath: nextVersionKeyPath]
        
        if expectRenewalFlow {
            // Step 2: check that the new version triggers renewal
            try overwriteOnDiskConsentVersion(to: nextConsentVersion)
            try launchAppAndEnrollIntoStudy(
                locale: locale,
                testEnvironmentConfig: config,
                skipHealthPermissionsHandling: true,
                skipGoingToHomeTab: true
            )
            // the study bundle now contains a new consent version than what was signed before, which we expect to trigger the renewal flow.
            XCTAssert(app.otherElements["MHC:ConsentRenewalFlow"].waitForExistence(timeout: 7))
            XCTAssert(app.staticTexts["Consent Renewal"].exists)
            app.buttons["Continue"].tap()
            
            let onboardingNavigator = OnboardingNavigator(testCase: self)
            onboardingNavigator.navigateConsent(
                expectedName: PersonNameComponents(givenName: "Leland", familyName: "Stanford"),
                signUpForExtraTrial: false
            )
            XCTAssert(app.otherElements["MHC:ConsentRenewalFlow"].waitForNonExistence(timeout: 7))
            // verify that the user is now recorded as having signed the new version
            XCTAssertEqual(try XCTUnwrap(determineLastSignedConsentVersion()), nextConsentVersion)
            app.terminate()
        }
        
        // launch again and verify no second prompt will take place.
        try launchAppAndEnrollIntoStudy(
            locale: locale,
            testEnvironmentConfig: config,
            skipHealthPermissionsHandling: true,
            skipGoingToHomeTab: true
        )
        XCTAssert(app.otherElements["MHC:ConsentRenewalFlow"].waitForNonExistence(timeout: 10))
        if expectRenewalFlow {
            // verify that the user is still recorded as having signed the new version
            XCTAssertEqual(try XCTUnwrap(determineLastSignedConsentVersion()), nextConsentVersion)
        } else {
            XCTAssertEqual(try XCTUnwrap(determineLastSignedConsentVersion()), initialOnDiskConsentVersion)
        }
    }
}
