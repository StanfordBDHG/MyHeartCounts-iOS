//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import FirebaseFunctions
import Foundation
import SFSafeSymbols
@_spi(APISupport)
import Spezi
import SpeziFirebaseAccount
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct RegionComingSoon: View {
    @Environment(\.locale)
    private var locale
    
    let selectedRegion: Locale.Region
    
    @State private var emailAddress = ""
    @State private var showInvalidEmailAlert = false
    @State private var showSuccessfullyAddedEmailAlert = false
    @State private var viewState: ViewState = .idle
    
    
    var body: some View {
        OnboardingPage(
            symbol: .documentBadgeClock,
            title: "Coming Soon",
            description: """
                The My Heart Counts study isn't yet available in \(locale.localizedStringWithDefinitiveArticle(for: selectedRegion)).
                
                Add your email and we'll update you when it becomes available in your region.
                """,
            content: {
                TextField("Email…", text: $emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
            },
            footer: {
                AsyncButton(
                    state: $viewState,
                    action: {
                        try await notifyMe()
                    },
                    label: {
                        Text("Notify Me")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(12)
                    }
                )
                .buttonStyleGlassProminent()
                Link(destination: MyHeartCounts.website) {
                    HStack {
                        Text("INELIGIBLE_LEARN_MORE")
                        Spacer()
                        Image(systemSymbol: .arrowUpRight)
                            .accessibilityHidden(true)
                    }
                    .bold()
                    .padding(12)
                }
                .buttonStyleGlass()
            }
        )
        .makeBackgroundMatchFormBackground()
        .alert("Invalid Email Address", isPresented: $showInvalidEmailAlert) {
            Button("OK") {
                showInvalidEmailAlert = false
            }
        } message: {
            Text("Please enter a valid email address and try again.")
        }
        .alert("You're on the List", isPresented: $showSuccessfullyAddedEmailAlert) {
            Button("OK") {
                showSuccessfullyAddedEmailAlert = false
            }
        } message: {
            Text("We've saved your email and will notify you when My Heart Counts becomes available in your region.")
        }
    }
    
    private func notifyMe() async throws {
        let pattern = /^[A-Z0-9a-z.!#$%&'*+\-\/=?^_`{|}~]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
        guard emailAddress.wholeMatch(of: pattern) != nil else {
            showInvalidEmailAlert = true
            return
        }
        if !Spezi.didLoadFirebase {
            Spezi.loadFirebase(for: .unitedStates)
            try? await Task.sleep(for: .seconds(1))
        }
        guard let spezi = SpeziAppDelegate.spezi else {
            fatalError("Spezi not loaded?")
        }
        guard let accountService = spezi.module(FirebaseAccountService.self) else {
            fatalError("Missing FirebaseAccountService?")
        }
        try await accountService.signUpAnonymously()
        _ = try await Functions.functions()
            .httpsCallable("joinWaitlist")
            .call([
                "region": selectedRegion.identifier,
                "email": emailAddress
            ])
        showSuccessfullyAddedEmailAlert = true
        try await accountService.logout()
    }
}


extension Locale {
    /// Regions that need to be prefixed with "the" in English.
    private static let regionsNeedingEnglishDefinitiveArticle: Set<Locale.Region> = [
        .unitedStates, .unitedKingdom, .netherlands, .philippines,
        .bahamas, .maldives, .unitedArabEmirates, .congoKinshasa, .congoBrazzaville,
        .gambia, .côteDIvoire, .southSudan
    ]
    
    /// Spanish: region -> article (only regions that conventionally take one)
    private static let spanishDefiniteArticleMapping: [Locale.Region: String] = [
        .unitedStates: "los",
        .unitedKingdom: "el",
        .india: "la",
        .philippines: "las",
        .netherlands: "los",
        .bahamas: "las",
        .maldives: "las",
        .unitedArabEmirates: "los",
        .yemen: "el",
        .ecuador: "el",
        .peru: "el"
    ]
    
    func localizedStringWithDefinitiveArticle(for region: Locale.Region) -> String {
        let name = self.localizedString(forRegionCode: region.identifier) ?? region.identifier
        switch self.language.languageCode?.identifier {
        case "en":
            if Self.regionsNeedingEnglishDefinitiveArticle.contains(region) {
                return "the \(name)"
            }
        case "es":
            if let article = Self.spanishDefiniteArticleMapping[region] {
                return "\(article) \(name)"
            }
        default:
            break
        }
        return name
    }
}


#Preview {
    RegionComingSoon(selectedRegion: .unitedKingdom)
}
