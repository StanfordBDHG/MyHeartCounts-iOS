//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziAccount
import SpeziScheduler
import SpeziStudy
import SpeziViews
import SwiftUI
import SFSafeSymbols


// TODO(@lukas) can we somehow prevent the account sheet from:
// - showing up for a fraction of a second when launching the app, and
// - somwtimes not getting dismissed (and needing to manually be dismissed by the user)

struct RootView: View {
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    @Environment(StudyManager.self) private var studyManager
    @Environment(Scheduler.self) private var scheduler
    
    @State private var swiftDataAutosaveTask: _Concurrency.Task<Void, Never>?
    
    @AppStorage(StorageKeys.homeTabSelection) private var selectedTab: String = HomeTabView.tabId
    @AppStorage(StorageKeys.tabViewCustomization) private var tabViewCustomization = TabViewCustomization()
    
    var body: some View {
//        LabeledContent("now", value: Date.now, format: .iso8601)
        ZStack {
            if completedOnboardingFlow {
                content
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: !$completedOnboardingFlow) {
            AppOnboardingFlow()
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
            makeTab(Contacts.self)
            makeTab(NewsTabView.self)
//            ForEach(Self.tabs, id: \.tabId) { tab in
//                Tab(tab.tabTitle, systemImage: tab.tabSymbol.rawValue, value: tab.tabId) {
//                    tab.init().intoAnyView()
//                }
//                .customizationID(tab.tabId)
//            }
//            Tab("Schedule", systemImage: "cube.transparent", value: .homepage) { // list.clipboard
//                HomeTabView(presentingAccount: $presentingAccount)
//            }
//                .customizationID("tabs.home")
//            Tab("Contacts", systemImage: "person.fill", value: .contact) {
//                Contacts(presentingAccount: $presentingAccount)
//            }
//                .customizationID("tabs.contacts")
        }
            .tabViewStyle(.sidebarAdaptable)
            .tabViewCustomization($tabViewCustomization)
//            .sheet(isPresented: $presentingAccount) {
//                AccountSheet(dismissAfterSignIn: false) // presentation was user initiated, do not automatically dismiss
//            }
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



//struct T1: RootViewTab {
//    static var tabId: String { String(describing: Self.self) }
//    static var tabIitle: LocalizedStringResource { "T1" }
//    static var tabSymbol: SFSymbol { ._1Brakesignal }
//    
//    @Binding var isPresentingAccount: Bool
//    
//    init(isPresentingAccount: Binding<Bool>) {
//        self._isPresentingAccount = isPresentingAccount
//    }
//    
//    var body: some View {
//        
//    }
//}
