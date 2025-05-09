//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

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
        OnboardingView {
            VStack {
                OnboardingTitleView(
                    title: "Notifications",
                    subtitle: "Spezi Scheduler Notifications."
                )
                Spacer()
                Image(systemName: "bell.square.fill")
                    .font(.system(size: 150))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                Text("NOTIFICATION_PERMISSIONS_DESCRIPTION")
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                Spacer()
            }
        } footer: {
            OnboardingActionsView(
                "Allow Notifications",
                action: {
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
            )
        }
        .navigationBarBackButtonHidden(notificationProcessing)
        // Small fix as otherwise "Login" or "Sign up" is still shown in the nav bar
        .navigationTitle(Text(verbatim: ""))
    }
}


#if DEBUG
#Preview {
    ManagedNavigationStack {
        NotificationPermissions()
    }
}
#endif
