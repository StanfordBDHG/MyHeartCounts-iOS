//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import Spezi
import SpeziAccount
import SpeziOnboarding
import SpeziScheduler
import SpeziStudy
import SpeziViews
import SwiftUI


struct RootView: View {
    @LocalPreference(.onboardingFlowComplete)
    private var didCompleteOnboarding
    
    @LocalPreference(.rootTabSelection)
    private var selectedTab
    
    @LocalPreference(.rootTabViewCustomization)
    private var tabViewCustomization
    
    var body: some View {
        ZStack {
            if didCompleteOnboarding {
                content
            } else {
                EmptyView()
            }
        }
    }
    
    @ViewBuilder private var content: some View {
        TabView(selection: $selectedTab) {
            makeTab(HomeTab.self)
            makeTab(UpcomingTasksTab.self)
            makeTab(HeartHealthDashboardTab.self)
            makeTab(NewsTab.self)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabViewCustomization)
        .accountRequired(!FeatureFlags.disableFirebase && !FeatureFlags.skipOnboarding) {
            AccountSheet()
        }
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
