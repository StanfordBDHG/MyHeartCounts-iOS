//
//  LanguageCheck.swift
//  MyHeartCounts
//
//  Created by Lukas Kollmer on 04.03.25.
//

import Foundation
import SpeziOnboarding
import SwiftUI



struct LanguageCheck: View {
    @Environment(OnboardingNavigationPath.self) private var path
    
    @State private var selection: Bool?
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(
                title: "Screening: Language",
                subtitle: "Before we can continue,\nwe need to learn a little about you"
            )
        } contentView: {
            Form {
                Section {
                    Text("Do you speak English?")
                }
                Section {
                    Picker("", selection: $selection) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } footer: {
                    Text("My Heart Counts is currently only available in English")
                }
            }
        } actionView: {
            OnboardingActionsView("Continue") {
                path.nextStep()
            }
            .disabled(selection != true)
        }

    }
}
