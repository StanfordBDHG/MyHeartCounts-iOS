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
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SpeziViews
import SwiftUI


struct RootView: View {
    // swiftlint:disable attributes
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Account.self) private var account: Account?
    @Environment(ConsentManager.self) private var consentManager: ConsentManager?
    @Environment(SetupTestEnvironment.self) private var setupTestEnvironment
    @Environment(Lifecycle.self) private var lifecycle
    @LocalPreference(.onboardingFlowComplete) private var didCompleteOnboarding
    @LocalPreference(.rootTabSelection) private var selectedTab
    @LocalPreference(.rootTabViewCustomization) private var tabViewCustomization
    // swiftlint:enable attributes
    
    @State private var isShowingConsentRenewalSheet = false
    
    var body: some View {
        ZStack {
            switch setupTestEnvironment.state {
            case .disabled, .done:
                if didCompleteOnboarding, account != nil {
                    content
                } else {
                    EmptyView()
                }
            case .pending, .settingUp:
                ProgressView("Preparing Test Environment")
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
        .onChange(of: scenePhase, initial: true) { _, newValue in
            lifecycle._set(\.scenePhase, to: newValue)
        }
        .taskPerformingAnchor()
    }
    
    @ViewBuilder private var content: some View {
        TabView(selection: $selectedTab) {
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
    }
}


extension LocalPreferenceKey {
    static var rootTabSelection: LocalPreferenceKey<String> {
        .make("rootTabSelection", default: HomeTab.tabId)
    }
    
    static var rootTabViewCustomization: LocalPreferenceKey<TabViewCustomization> {
        .make("rootTabViewCustomization", default: .init())
    }
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
