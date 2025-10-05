//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SFSafeSymbols
import Spezi
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct NotificationPermissions: View {
    @Environment(ManagedNavigationStack.Path.self)
    private var onboardingPath
    @Environment(NotificationsManager.self)
    private var notificationsManager

    @State private var notificationProcessing = false
    
    
    var body: some View {
        VStack {
            OnboardingDisclaimerInfoView(
                icon: .bellBadge,
                title: "Notifications",
                description: "NOTIFICATION_PERMISSIONS_DESCRIPTION"
            )
            OnboardingActionsView("Allow Notifications") {
                await allowNotifications()
            }
                .padding(.horizontal)
        }
            .navigationBarBackButtonHidden(notificationProcessing)
    }
    
    
    private func allowNotifications() async {
        do {
            notificationProcessing = true
            // Notification Authorization is not available in the preview simulator.
            if ProcessInfo.processInfo.isPreviewSimulator {
                try await _Concurrency.Task.sleep(for: .seconds(0.75))
            } else {
                try await notificationsManager.requestNotificationPermissions()
            }
        } catch {
            print("Could not request notification permissions.")
        }
        notificationProcessing = false
        onboardingPath.nextStep()
    }
}


#Preview {
    ManagedNavigationStack {
        NotificationPermissions()
    }
        .environment(StudyBundleLoader.shared)
        .previewWith(standard: MyHeartCountsStandard()) {
            NotificationsManager()
            MyHeartCountsStandard.previewModels
        }
}
