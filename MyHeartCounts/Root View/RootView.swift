//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
@testable @_spi(APISupport) import Spezi
import SpeziAccount
import SpeziScheduler
import SpeziStudy
import SpeziViews
import SwiftUI


struct OnboardingSheetWrapper: View {
    @Binding var completedOnboardingFlow: Bool
    @Binding var path: [String]
    
    var body: some View {
        let _ = Self._printChanges()
        if !completedOnboardingFlow {
            Color.red.frame(height: 0)
                .sheet(isPresented: !$completedOnboardingFlow) {
                    AppOnboardingFlow(path: $path)
                        .inspectingType("1")
                        .spezi(SpeziAppDelegate.appDelegate!) // swiftlint:disable:this force_cast force_unwrapping
                        .inspectingType("2")
                    //                Text("hmmm")
                    //                    .task {
                    //                        try? await _Concurrency.Task.sleep(for: .seconds(3))
                    //                        SpeziAppDelegate.spezi?.loadModule(TestModule())
                    //                    }
                }
        }
    }
    
//    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
//        true
//    }
}


extension View {
    func inspectingType(_ label: String) -> Self {
        print("TYPE", label, type(of: self))
        return self
    }
}



struct RootView: View {
    @AppStorage(StorageKeys.onboardingFlowComplete)
    private var completedOnboardingFlow = false
    
    @State private var swiftDataAutosaveTask: _Concurrency.Task<Void, Never>?
    
    @AppStorage(StorageKeys.homeTabSelection)
    private var selectedTab: String = HomeTabView.tabId
    @AppStorage(StorageKeys.tabViewCustomization)
    private var tabViewCustomization = TabViewCustomization()
    
    var body: some View {
        ZStack {
            if completedOnboardingFlow {
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
