//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//


import SpeziHealthKit
import SpeziHealthKitUI
import SpeziOnboarding
import SwiftUI
import SpeziViews


struct AppUsageRestrictions: View {
    @Environment(\.calendar) private var cal
    @Environment(HealthKit.self) private var healthKit
    @Environment(OnboardingNavigationPath.self) private var onboardingPath
    
    @State private var viewState: ViewState = .idle
    @State private var isAllowedToContinue = false
    @State private var dateOfBirth = Date()
    
    @HealthKitCharacteristicQuery(.dateOfBirth) private var healthKitDateOfBirth
    
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(
                title: "Usage Limitations",
                subtitle: "Before we can continue, we need to learn a little about you"
            )
        } contentView: {
            Form {
                Section {
                    DatePicker("When were you born?", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                } footer: {
                    Text("My Heart Counts is only available to persons 18 and older.")
                }
                // NOTE: we could of course simply have an `onChange(of healthKitDateOfBirth) and read in the value automatically and skip the button,
                // but we intentionally do not do this, since having an explicit button gives the user more agency and probably feels less creepy.
                Section {
                    AsyncButton(state: $viewState) {
                        try await healthKit.askForAuthorization(for: .init(
                            read: [HKCharacteristicType(.dateOfBirth)]
                        ))
                        if let healthKitDateOfBirth {
                            dateOfBirth = healthKitDateOfBirth
                        }
                    } label: {
                        HStack {
                            Text("Try to read from Health app")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("If you have entered your date of birth into the Health app, we can try to read it from there.")
                }
            }
        } actionView: {
            OnboardingActionsView("Continue") {
                onboardingPath.nextStep()
            }
            .disabled(!isAllowedToContinue)
            #if DEBUG
            HStack {
                Spacer()
                Button("[DEBUG] enter past date") {
                    dateOfBirth = cal.date(
                        from: DateComponents(year: 1998, month: 6, day: 2, hour: 20, minute: 15)
                    )! // swiftlint:disable:this force_unwrapping
                }
                Spacer()
            }
            #endif
        }
//        .onChange(of: healthKitDateOfBirth, initial: true) { _, newValue in
//            if let newValue {
//                dateOfBirth = newValue
//            }
//        }
        .onChange(of: dateOfBirth) { _, newValue in
            if let age = cal.dateComponents([.year], from: newValue, to: .now).year {
                isAllowedToContinue = age >= 18
            } else {
                isAllowedToContinue = false
            }
        }
    }
}
