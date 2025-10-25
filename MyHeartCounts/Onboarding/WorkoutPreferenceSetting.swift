//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import SFSafeSymbols
import SpeziAccount
import SpeziOnboarding
import SpeziViews
import SwiftUI


/// Lets the user set their preferred workout mode, and a notification time for related notification.
struct WorkoutPreferenceSetting: View {
    // swiftlint:disable attributes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(ManagedNavigationStack.Path.self) private var path: ManagedNavigationStack.Path?
    @Environment(Account.self) private var account
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    @State private var workoutType: WorkoutType?
    @State private var notificationTime = NotificationTime(hour: 9)
    
    private var canContinue: Bool {
        workoutType != nil
    }
    
    var body: some View {
        OnboardingPage(title: "Workout Preference", description: "WORKOUT_PREFERENCE_TEXT") {
            content
        } footer: {
            if let path {
                OnboardingActionsView("Continue", viewState: $viewState) {
                    await saveToAccountDetails()
                    path.nextStep()
                }
                .disabled(!canContinue)
            } else {
                EmptyView()
            }
        }
        .interactiveDismissDisabled()
        .toolbar {
            if path == nil {
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26, *) {
                        AsyncButton(role: .confirm, state: $viewState) {
                            await saveToAccountDetails()
                            dismiss()
                        } label: {
                            Text("Done")
                        }
                        .disabled(!canContinue)
                    } else {
                        AsyncButton("Done", state: $viewState) {
                            await saveToAccountDetails()
                            dismiss()
                        }
                        .disabled(!canContinue)
                    }
                }
            }
        }
        .onAppear {
            if let details = account.details {
                workoutType = details.preferredWorkoutType.flatMap { .init(id: $0) }
                notificationTime = details.preferredNudgeNotificationTime ?? .init(hour: 9)
            }
        }
    }
    
    @ViewBuilder private var content: some View {
        Divider()
        HStack {
            Text("Preferred Workout Type")
            Spacer()
            Picker("", selection: $workoutType) {
                Text("No Selection")
                    .tag(WorkoutType?.none)
                    .selectionDisabled()
                Divider()
                ForEach(WorkoutType.options) { option in
                    Label(option.title, systemSymbol: option.symbol)
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
        }
        Divider()
        DatePicker(
            "Notification Time",
            selection: Binding<Date> {
                calendar.date(
                    bySettingHour: notificationTime.hour,
                    minute: notificationTime.minute,
                    second: 0,
                    of: .now
                ) ?? .now // will never fail, but just to be safe we provide a default
            } set: { newValue in
                let components = calendar.dateComponents([.hour, .minute], from: newValue)
                notificationTime = NotificationTime(
                    hour: components.hour ?? 9,
                    minute: components.minute ?? 0
                )
            },
            displayedComponents: [.hourAndMinute]
        )
        Divider()
        Text("WORKOUT_TYPE_PREFERENCE_FOOTER")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
    
    private func saveToAccountDetails() async {
        do {
            var newDetails = AccountDetails()
            newDetails.preferredWorkoutType = workoutType?.id
            newDetails.preferredNudgeNotificationTime = notificationTime
            let modifications = try AccountModifications(modifiedDetails: newDetails)
            try await account.accountService.updateAccountDetails(modifications)
        } catch {
            logger.error("Error updating workout preference account details: \(error)")
        }
    }
}


extension WorkoutPreferenceSetting {
    private struct Section<Header: View, Content: View>: View {
        private let header: Header
        private let content: Content
        
        var body: some View {
            VStack {
                header
                    .font(.title3.bold()/*.scaled(by: 0.9)*/)
                    .foregroundStyle(.secondary)
                content
            }
        }
        
        init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) where Header == Text {
            self.header = Text(title)
            self.content = content()
        }
    }
}


extension WorkoutPreferenceSetting {
    struct WorkoutType: Hashable, Identifiable, Sendable {
        let id: String
        let title: String
        let symbol: SFSymbol
    }
    
    
    struct NotificationTime: Hashable, LosslessStringConvertible, Codable, Sendable {
        var hour: Int
        var minute: Int
        
        var description: String {
            String(format: "%.02ld:%02ld", hour, minute)
        }
        
        init(hour: Int, minute: Int = 0) {
            self.hour = hour.clamped(to: 0...23)
            self.minute = minute.clamped(to: 0...59)
        }
        
        init?(_ description: String) {
            let components = description.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]),
                  (0..<24).contains(hour),
                  (0..<60).contains(minute) else {
                return nil
            }
            self.init(hour: hour, minute: minute)
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let description = try container.decode(String.self)
            if let time = Self(description) {
                self = time
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unable to parse '\(description)' into a \(Self.self)"))
            }
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }
    }
}


extension WorkoutPreferenceSetting.WorkoutType {
    static let options: [Self] = [
        Self(id: "walk", title: "Walking", symbol: .figureWalk),
        Self(id: "run", title: "Running", symbol: .figureRun),
        Self(id: "bicycle", title: "Cycling", symbol: .figureOutdoorCycle),
        Self(id: "swim", title: "Swimmimg", symbol: .figurePoolSwim),
        Self(id: "strength", title: "Strength", symbol: .figureStrengthtrainingFunctional),
        Self(id: "HIIT", title: "High-intensity Training", symbol: .figureHighintensityIntervaltraining),
        Self(id: "yoga/pilates", title: "Yoga / Pilates", symbol: .figureYoga),
        Self(id: "sport", title: "Sport", symbol: .figureIndoorSoccer)
    ]
    
    init?(id: ID) {
        if let value = Self.options.first(where: { $0.id == id }) {
            self = value
        } else {
            return nil
        }
    }
}
