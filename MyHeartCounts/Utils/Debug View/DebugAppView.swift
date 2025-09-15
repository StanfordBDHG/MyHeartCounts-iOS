//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziFoundation
import SpeziStudyDefinition
import SpeziViews
import SwiftUI
import UIKit
import XCTSpeziNotificationsUI


struct DebugOptions: View {
    // swiftlint:disable attributes
    @Environment(\.colorScheme) private var colorScheme
    @LocalPreference(.sendHealthSampleUploadNotifications) private var healthUploadNotifications
    // swiftlint:enable attributes
    
    @State private var isTimedWalkingTestSheetShown = false
    @State private var viewState: ViewState = .idle
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $healthUploadNotifications) {
                    Label("Live Health Upload Notifications", systemSymbol: .arrowUpHeart)
                        .foregroundStyle(colorScheme.textLabelForegroundStyle)
                }
                NavigationLink(symbol: .appBadge, "Notifications Status") {
                    NotificationsManagerControlView()
                }
                NavigationLink(symbol: .bellBadge, "Scheduled Local Notifications") {
                    PendingNotificationsList()
                }
            }
            NavigationLink(symbol: .calendar, "Health Data Bulk Upload") {
                HealthImporterControlView()
            }
            Section {
                Button {
                    isTimedWalkingTestSheetShown = true
                } label: {
                    Label("Timed Walking Test", systemSymbol: .figureWalk)
                }
            }
            Section {
                NavigationLink("SensorKit") {
                    SensorKitControlView()
                }
            }
            Section {
                Button("Replace Root View Controller", role: .destructive) {
                    // The idea here is that discarding the root view controller should deallocate all our resources.
                    // We can then launch Xcode's memory graph debugger, and anything that's still in the left sidebar is leaked.
                    replaceRootVC()
                }
            }
        }
        .navigationTitle("Debug Options")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isTimedWalkingTestSheetShown) {
            NavigationStack {
                TimedWalkingTestView(.init(duration: .minutes(6), kind: .walking))
            }
        }
    }
    
    private func replaceRootVC() {
        guard let window = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) else {
            return
        }
        window.rootViewController = UIViewController()
    }
}
