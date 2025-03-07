//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziOnboarding
import SpeziStudy
import SpeziViews
import SwiftUI


///// Attempts to convert
//@MainActor
//func screeningOnboardingSteps(forParticipationCriteriaIn study: StudyDefinition) throws -> [AnyView] {
////    let leafCriteria = study.metadata.participationCriteria.criterion.allLeafs
////    guard !leafCriteria.isEmpty else {
////        return []
////    }
//    try screeningOnboardingSteps(for: study.metadata.participationCriteria.criterion)
//}
//
//
//@MainActor
//func screeningOnboardingSteps(for criterion: StudyDefinition.ParticipationCriteria.Criterion) throws -> [AnyView] {
////    let leafCriteria = study.metadata.participationCriteria.criterion.allLeafs
////    guard !leafCriteria.isEmpty else {
////        return []
////    }
//    switch criterion {
//    case /*.any([]),*/ .all([]):
//        return []
//    case .all(let nested):
//        guard nested.allSatisfy(\.isLeaf) else {
//            throw SimpleError("Not-Yet-Supported Criteria Definition!")
//        }
//        return try nested.map { criterion in
//            switch criterion {
//            case .ageAtLeast(let minAge):
//                AgeCheck(requiredMinAgeInYears: minAge).intoAnyView()
//            case .isFromRegion(let region):
//                RegionCheck(allowedRegions: region).intoAnyView()
//            case .custom:
//                throw SimpleError("Not-Yet-Supported Criteria Definition!")
//            case .all:
//                fatalError()
//            }
//        }
//    case .ageAtLeast, .isFromRegion, .custom:
//        return try screeningOnboardingSteps(for: .all([criterion]))
//    }
//}


@Observable @MainActor
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
    
    
    @State private var isPresentingRegionPicker = false
    
    @ViewBuilder private var regionPicker: some View {
        @Bindable var data = data
        let allRegions = Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty }
            .map { ($0, name(for: $0)) }
            .sorted(using: KeyPathComparator(\.1))
            .map(\.0)
        let highlightedRegions: [Locale.Region] = [
            .unitedStates, .unitedKingdom
        ]
        let remainingRegions = allRegions
            .filter { !highlightedRegions.contains($0) }
            .map { ($0, name(for: $0)) }
            .sorted(using: KeyPathComparator(\.1))
        Button {
            isPresentingRegionPicker = true
        } label: {
            HStack {
                Text("Where are you currently living?")
                    .fontWeight(.medium)
                    .foregroundStyle(buttonLabelForegroundStyle)
                Spacer()
                if let region = data.region {
                    Text(name(for: region))
                        .foregroundStyle(buttonLabelForegroundStyle.secondary)
                }
                DisclosureIndicator()
            }
            .contentShape(Rectangle())
        }
        .sheet(isPresented: $isPresentingRegionPicker) {
            ListSelectionSheet("Select a Region", items: allRegions, selection: $data.region) { region in
                name(for: region)
            }
        }
    }
    
    
    private var buttonLabelForegroundStyle: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private func name(for region: Locale.Region) -> String {
        locale.localizedString(forRegionCode: region.identifier) ?? region.identifier
    }
    
    
    @ViewBuilder
    private func makeBooleanSelectionSection(_ title: LocalizedStringResource, _ binding: Binding<Bool?>) -> some View {
        Text(title).fontWeight(.medium)
        makeBooleanButton(true, boundTo: binding)
        makeBooleanButton(false, boundTo: binding)
    }
    
    private func makeBooleanButton(_ option: Bool, boundTo binding: Binding<Bool?>) -> some View {
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

extension View {
    consuming func intoAnyView() -> AnyView {
        AnyView(self)
    }
    
    consuming func transforming(@ViewBuilder _ transform: (Self) -> some View) -> some View {
        transform(self)
    }
}
