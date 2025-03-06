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
import SpeziViews
import SwiftData
import SwiftUI
import SFSafeSymbols


// TODO(@lukas) can we somehow prevent the account sheet from:
// - showing up for a fraction of a second when launching the app, and
// - somwtimes not getting dismissed (and needing to manually be dismissed by the user)

struct RootView: View {
    private static let tabs: [any RootViewTab.Type] = [
        HomeTabView.self, Contacts.self
    ]
//    private enum TabId: String {
//        case homepage
//        case contact
//    }
    
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.onboardingFlowComplete) var completedOnboardingFlow = false
    @Environment(MHC.self) private var mhc
    @Environment(Scheduler.self) private var scheduler
    
    @State private var swiftDataAutosaveTask: _Concurrency.Task<Void, Never>?
    
    @AppStorage(StorageKeys.homeTabSelection) private var selectedTab: String = HomeTabView.tabId
    @AppStorage(StorageKeys.tabViewCustomization) private var tabViewCustomization = TabViewCustomization()
    
    var body: some View {
        LabeledContent("now", value: Date.now, format: .iso8601)
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
        .onAppear {
            // TODO THIS SHOULD NOT BE NECESSARY
            // WHY IS THIS REQUIRED??????
            // WHY DOESN'T THE MODELCONTEXT AUTOSAVE, EVEN THOUGH THAT'S ENABLED BY DEFAULT????
            guard swiftDataAutosaveTask == nil else {
                return
            }
            swiftDataAutosaveTask = _Concurrency.Task.detached {
                while true {
                    try? await self.saveModelContext()
                    try? await self.scheduler._saveModelContext()
                    try? await _Concurrency.Task.sleep(for: .seconds(0.25))
                }
            }
        }
        .task {
            // not perfect, but we need to inject it somehow...
            try! await mhc.initialize(with: modelContext) // swiftlint:disable:this force_try
        }
    }
    
    @ViewBuilder private var content: some View {
        TabView(selection: $selectedTab) {
            makeTab(HomeTabView.self)
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
    
    
//    @ViewBuilder
    private func makeTab(_ ty: (some RootViewTab).Type) -> some TabContent<String> { // swiftlint:disable:this identifier_name
        Tab(ty.tabTitle, systemImage: ty.tabSymbol.rawValue, value: ty.tabId) {
            ty.init()
        }
        .customizationID(ty.tabId)
    }
    
    func saveModelContext() throws {
        try self.modelContext.save()
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
