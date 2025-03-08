//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SpeziViews
import SwiftUI


@Observable
@MainActor
final class ScreeningDataCollection: Sendable {
    var dateOfBirth: Date = .now
    var region: Locale.Region?
    var speaksEnglish: Bool? // swiftlint:disable:this discouraged_optional_boolean
    var physicalActivity: Bool? // swiftlint:disable:this discouraged_optional_boolean
}


struct EligibilityScreening: View {
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var cal
    @Environment(\.colorScheme) private var colorScheme
    
    @Environment(OnboardingNavigationPath.self) private var path
    @Environment(ScreeningDataCollection.self) private var data
    
    @State private var isPresentingRegionPicker = false
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "Screening", subtitle: "Before we can continue,\nwe need to learn a little about you")
        } contentView: {
            @Bindable var data = data
            Form {
                Section("Date of Birth") {
                    DatePicker(selection: $data.dateOfBirth, in: Date.distantPast...Date.now, displayedComponents: .date) {
                        Text("When were you born?")
                            .fontWeight(.medium)
                    }
                }
                Section("Region") {
                    regionPicker
                }
                Section("Language") {
                    // TODO allow specifying the language via a parameter?!
                    makeBooleanSelectionSection("Do you speak English?", $data.speaksEnglish)
                }
                Section("Physical Activity") {
                    makeBooleanSelectionSection("Are you able to perform physical activies?", $data.physicalActivity)
                }
            }
        } actionView: {
            OnboardingActionsView("Continue") {
                path.nextStep()
            }
            .padding(.horizontal, 24)
            .disabled(cal.isDateInToday(data.dateOfBirth) || data.region == nil || data.speaksEnglish == nil || data.physicalActivity == nil)
        }
        .disablePadding(.horizontal)
        .transforming { view in
            // It seems that this (using background vs backgroundStyle) depending on light/dark mode is what we need to do
            // in order to have the view background match the form background...
            // TODO(@lukas) why is this the case?
            if colorScheme == .dark {
                view.backgroundStyle(Color(uiColor: UIColor.secondarySystemBackground))
            } else {
                view.background(Color(uiColor: UIColor.secondarySystemBackground))
            }
        }
    }
    
    
    @ViewBuilder private var regionPicker: some View {
        @Bindable var data = data
        let allRegions = Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .sorted { $0.localizedName(in: locale) < $1.localizedName(in: locale) }
        Button {
            isPresentingRegionPicker = true
        } label: {
            HStack {
                Text("Where are you currently living?")
                    .fontWeight(.medium)
                    .foregroundStyle(buttonLabelForegroundStyle)
                Spacer()
                if let region = data.region {
                    Text(region.localizedName(in: locale))
                        .foregroundStyle(buttonLabelForegroundStyle.secondary)
                }
                DisclosureIndicator()
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresentingRegionPicker) {
            ListSelectionSheet("Select a Region", items: allRegions, selection: $data.region) { region in
                if let emoji = region.flagEmoji {
                    "\(emoji) \(region.localizedName(in: locale))"
                } else {
                    region.localizedName(in: locale)
                }
            }
        }
    }
    
    
    private var buttonLabelForegroundStyle: Color {
        colorScheme == .dark ? .white : .black
    }
    
    
    @ViewBuilder
    private func makeBooleanSelectionSection(
        _ title: LocalizedStringResource,
        _ binding: Binding<Bool?> // swiftlint:disable:this discouraged_optional_boolean
    ) -> some View {
        Text(title).fontWeight(.medium)
        makeBooleanButton(true, boundTo: binding)
        makeBooleanButton(false, boundTo: binding)
    }
    
    private func makeBooleanButton(
        _ option: Bool,
        boundTo binding: Binding<Bool?> // swiftlint:disable:this discouraged_optional_boolean
    ) -> some View {
        Button {
            switch binding.wrappedValue {
            case nil, !option:
                binding.wrappedValue = option
            case option:
                binding.wrappedValue = nil
            default:
                unsafeUnreachable()
            }
        } label: {
            HStack {
                Text(option ? "Yes" : "No")
                    .foregroundStyle(buttonLabelForegroundStyle)
                if binding.wrappedValue == option {
                    Spacer()
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                    
                }
            }
            .contentShape(Rectangle())
        }
    }
}
