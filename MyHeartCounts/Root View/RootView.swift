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
    
    @AppStorage(StorageKeys.homeTabSelection)
    private var selectedTab: String = HomeTabView.tabId
    @AppStorage(StorageKeys.tabViewCustomization)
    private var tabViewCustomization = TabViewCustomization()
    
    var body: some View {
        ZStack {
            if didCompleteOnboarding {
                content
            } else {
                EmptyView()
            }
        }
        #if DEBUG
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // ???
                } label: {
                    Image(systemSymbol: .ladybug)
                        .tint(.red)
                        .accessibilityLabel("Debug Menu")
                }
            }
        }
        #endif
    }
    
    @ViewBuilder private var content: some View {
        TabView(selection: $selectedTab) {
            makeTab(HomeTabView.self)
            makeTab(HeartHealthDashboardTab.self)
            makeTab(NewsTabView.self)
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


extension RootView: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        true
    }
}
