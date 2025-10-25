//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SpeziAccount
import SpeziOnboarding
import SpeziViews
import SwiftUI


struct PreferredWorkoutStep: View {
    // swiftlint:disable attributes
    @Environment(\.calendar) private var calendar
    @Environment(ManagedNavigationStack.Path.self) private var path
    @Environment(Account.self) private var account
    // swiftlint:enable attributes
    
    @State private var viewState: ViewState = .idle
    @State private var workoutType: WorkoutType?
    @State private var notificationTime = NotificationTime(hour: 9)
    
    var body: some View {
        OnboardingPage(title: "Workout Preference", description: "WORKOUT_PREFERENCE_TEXT") {
            selectionForm
            DatePicker(
                "Notification Time",
                selection: Binding<Date> {
                    calendar.date(
                        bySettingHour: notificationTime.hour,
                        minute: notificationTime.minute,
                        second: 0,
                        of: .now
                    )! // swiftlint:disable:this force_unwrapping
                } set: { newValue in
                    let components = calendar.dateComponents([.hour, .minute], from: newValue)
                    notificationTime = NotificationTime(
                        hour: components.hour ?? 9,
                        minute: components.minute ?? 0
                    )
                },
                displayedComponents: [.hourAndMinute]
            )
        } footer: {
            OnboardingActionsView("Continue", viewState: $viewState) {
                var newDetails = AccountDetails()
                newDetails.preferredWorkoutType = workoutType?.id
                newDetails.preferredNudgeNotificationTime = notificationTime
                let modifications = AccountModifications(modifiedDetails: newDetails)
                do {
                    try await account.accountService.updateAccountDetails(modifications)
                } catch {
                    logger.error("Error updating workout preference account details: \(error)")
                }
                path.nextStep()
            }
        }
    }
    
    
    @ViewBuilder private var selectionForm: some View {
        Picker("Workout Preference", selection: $workoutType) {
            ForEach(WorkoutType.options) { option in
                Label(option.title, systemSymbol: option.symbol)
            }
        }
        .pickerStyle(.inline)
    }
}


extension PreferredWorkoutStep {
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


extension PreferredWorkoutStep {
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
            self.hour = hour
            self.minute = minute
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
            self.hour = hour
            self.minute = minute
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


extension PreferredWorkoutStep.WorkoutType {
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
