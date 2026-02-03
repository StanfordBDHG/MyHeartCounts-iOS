//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziFoundation
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SpeziViews
import SwiftUI


/// The "root" view of the app when logged in and enrolled in a study.
///
/// Displays and manages a `TabView`, with the different tabs in the app.
struct RootView: View {
    // swiftlint:disable attributes
    @Environment(Account.self) private var account: Account?
    @Environment(ConsentManager.self) private var consentManager: ConsentManager?
    @Environment(SetupTestEnvironment.self) private var setupTestEnvironment
    @LocalPreference(.onboardingFlowComplete) private var didCompleteOnboarding
    // swiftlint:enable attributes
    
    @State private var isShowingConsentRenewalSheet = false
    
    var body: some View {
        ZStack {
            switch setupTestEnvironment.state {
            case .disabled, .done:
                if didCompleteOnboarding, account != nil {
                    TabView()
                        // we might simply want to make every `taskPerformingAnchor` also an `taskContinuationAnchor` at some point?
                        // it's not trivial, though, since we'd also need to make sure that if there's multiple `taskContinuationAnchor`s, only one of them will actually pick up the task...
                        .taskContinuationAnchor()
                        .taskPerformingAnchor()
                } else {
                    EmptyView()
                }
            case .pending, .settingUp:
                ProgressView {
                    VStack(alignment: .center) {
                        Text(verbatim: "Setting Up Test Environment")
                        Text(verbatim: setupTestEnvironment.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .failure(let error):
                ContentUnavailableView("Error", systemSymbol: .exclamationmarkOctagon, description: Text(error.localizedDescription))
            }
        }
        .onChange(of: consentManager?.needsToSignNewConsentVersion) { oldValue, newValue in
            if let oldValue, let newValue, !oldValue && newValue {
                isShowingConsentRenewalSheet = true
            }
        }
        .sheet(isPresented: $isShowingConsentRenewalSheet) {
            ConsentRenewalFlow()
        }
        .trackingScenePhase()
    }
}


extension RootView {
    private struct TabView: View {
        @LocalPreference(.rootTabSelection)
        private var selectedTab: String
        
        @LocalPreference(.rootTabViewCustomization)
        private var tabViewCustomization
        
        var body: some View {
            SwiftUI.TabView(selection: $selectedTab) {
                makeTab(HomeTab.self)
                makeTab(UpcomingTasksTab.self)
                makeTab(HeartHealthDashboardTab.self)
            }
            .tabViewStyle(.sidebarAdaptable)
            .tabViewCustomization($tabViewCustomization)
        }
        
        private func makeTab(_ tab: (some RootViewTab).Type) -> some TabContent<String> {
            Tab(String(localized: tab.tabTitle), systemImage: tab.tabSymbol.rawValue, value: tab.tabId) {
                tab.init()
            }
            .customizationID(tab.tabId)
            .accessibilityIdentifier("MHC:Tab:\(tab.tabTitle.localizedString(for: .enUS))")
        }
    }
}


extension LocalPreferenceKeys {
    static let rootTabSelection = LocalPreferenceKey<String>("rootTabSelection", default: HomeTab.tabId)
    
    static let rootTabViewCustomization = LocalPreferenceKey<TabViewCustomization>("rootTabViewCustomization", default: .init())
}


extension ScenePhase: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .background:
            "background"
        case .inactive:
            "inactive"
        case .active:
            "active"
        @unknown default:
            "unknown"
        }
    }
}
