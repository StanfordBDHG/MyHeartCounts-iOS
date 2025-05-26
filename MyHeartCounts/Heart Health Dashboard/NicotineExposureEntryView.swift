//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftData
import SwiftUI


struct NicotineExposureEntryView: View {
    private typealias Option = CustomHealthSample.NicotineExposureCategoryValues
    
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.colorScheme)
    private var colorScheme
    
    @State private var selection: Option?
    
    var body: some View {
        List {
            Section {
                Text("What's your level of nicotine exposure? How often do you smoke?")
            }
            Section {
                ForEach(Option.allCases, id: \.self) { option in
                    makeRow(for: option)
                }
            }
        }
        .navigationTitle("Nicotine Exposure")
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    guard let selection else {
                        return
                    }
                    let sample = CustomHealthSample(
                        sampleType: .nicotineExposure,
                        date: .now,
                        value: Double(selection.rawValue)
                    )
                    modelContext.insert(sample)
                    try? modelContext.save()
                    dismiss()
                }
                .bold()
                .disabled(selection == nil)
            }
        }
    }
    
    private func makeRow(for option: Option) -> some View {
        Button {
            if selection == option {
                // deselect
                selection = nil
            } else {
                // select
                selection = option
            }
        } label: {
            HStack {
                Text(option.displayTitle)
                    .foregroundStyle(colorScheme.buttonLabelForegroundStyle)
                if selection == option {
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
}


extension CustomHealthSample.NicotineExposureCategoryValues {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .neverSmoked:
            "I have never smoked"
        case .quitMoreThan5YearsAgo:
            "I last smoked more than 5 years ago"
        case .quitWithin1To5Years:
            "I last smoked between 1 and 5 years ago"
        case .quitWithinLastYearOrIsUsingNDS:
            "I last smoked within the last year, or am using NDS"
        case .activelySmoking:
            "I'm actively smoking"
        }
    }
    
    var shortDisplayTitle: LocalizedStringResource {
        switch self {
        case .neverSmoked:
            "Never"
        case .quitMoreThan5YearsAgo:
            "More than 5 years ago"
        case .quitWithin1To5Years:
            "1 to 5 years ago"
        case .quitWithinLastYearOrIsUsingNDS:
            "Within last year, or am using NDS"
        case .activelySmoking:
            "Actively smoking"
        }
    }
}
