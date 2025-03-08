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
    @Environment(\.locale)
    private var locale
    @Environment(\.calendar)
    private var cal
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Environment(OnboardingNavigationPath.self)
    private var path
    @Environment(ScreeningDataCollection.self)
    private var data
    
    @State private var isPresentingRegionPicker = false
    
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "Screening", subtitle: "Before we can continue,\nwe need to learn a little about you")
        } contentView: {
            @Bindable var data = data
            Form {
                Section("Date of Birth") {
                    DatePicker(
                        selection: $data.dateOfBirth,
                        in: Date.distantPast...Date.now,
                        displayedComponents: .date
                    ) {
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
                Section {
                    OnboardingActionsView("Continue") {
                        evaluateEligibilityAndProceed()
                    }
                    .disabled(cal.isDateInToday(data.dateOfBirth) || data.region == nil || data.speaksEnglish == nil || data.physicalActivity == nil)
                    .listRowInsets(.zero)
                    // TODO(@lukas) can we somehow make it so that the scroll view fills the entire screen? ie, all the way to the bottom?
                }
            }
        } actionView: {
            EmptyView()
        }
        .disablePadding([.horizontal, .bottom])
        .makeBackgroundMatchFormBackground()
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
                        .accessibilityLabel("Selection Checkmark")
                }
            }
            .contentShape(Rectangle())
        }
    }
    
    private func evaluateEligibilityAndProceed() {
        let age = cal.dateComponents([.year], from: data.dateOfBirth, to: .tomorrow).year ?? 0
        
        let isEligible = age >= 18
            && (data.region == .unitedStates || data.region == .unitedKingdom) // TODO(@lukas) check for only one, and allow injecting it!
            && data.speaksEnglish == true
            && data.physicalActivity == true
        
        if isEligible {
            path.nextStep()
        } else {
            path.append(customView: NotEligibleView())
        }
    }
}


// TODO make this look pretty!
private struct NotEligibleView: View {
    var body: some View {
        OnboardingView {
            OnboardingTitleView(title: "Screening Results")
                .padding(.top, 47)
        } contentView: {
            Form {
                Section {
                    Text("You're sadly not eligible to participate in the My Heart Counts study.")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.zero)
                Section {
                    Link("Check out our other work", destination: URL(string: "https://bdh.stanford.edu")!)
                }
            }
        } actionView: {
            EmptyView()
        }
        .makeBackgroundMatchFormBackground()
        .navigationBarBackButtonHidden()
    }
}
