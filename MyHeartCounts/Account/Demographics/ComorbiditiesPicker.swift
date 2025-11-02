//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SFSafeSymbols
import SwiftUI


struct ComorbiditiesPicker: View {
    private typealias Comorbidity = Comorbidities.Comorbidity
    
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.colorScheme)
    private var colorScheme
    
    @Binding private var comorbidities: Comorbidities
    @State private var highlightedOption: Comorbidity?
    
    var body: some View {
        Form {
            Section {
                ForEach(Comorbidity.primaryComorbidities) { option in
                    makeRow(option)
                }
            }
            Section {
                ForEach(Comorbidity.secondaryComorbidities) { option in
                    makeRow(option)
                }
            }
            if comorbidities.isEmpty {
                // we offer a "none of these apply to me" button, but only if the user hasn't yet selected anything.
                // the reason for this is that, were they to accidentally tap the "None" button after already having
                // selected one/multiple options above, and having already entered start dates for these options,
                // all of that would be lost. (which is more problematic than for the other questions we have in the
                // demographics, since these are only boolean yes/no selections, whereas this one also has a follow-
                // up question (the start date)).
                Button("None") {
                    dismiss()
                }
            }
        }
        .navigationTitle("Select Comorbidities")
        .sheet(item: $highlightedOption) { option in
            Sheet(option: option, selection: $comorbidities[option])
        }
    }
    
    init(selection: Binding<Comorbidities>) {
        _comorbidities = selection
    }
    
    @ViewBuilder
    private func makeRow(_ option: Comorbidity) -> some View {
        Button {
            if comorbidities[option] == .notSelected {
                comorbidities[option] = .selected(startDate: DateComponents())
            }
            highlightedOption = highlightedOption == option ? nil : option
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(option.title)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(colorScheme.textLabelForegroundStyle)
                Spacer()
                switch comorbidities[option] {
                case .notSelected:
                    EmptyView()
                case .selected:
                    Image(systemSymbol: .checkmark)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                        .accessibilityLabel("Selected")
                }
            }
            .contentShape(Rectangle())
        }
    }
}


extension ComorbiditiesPicker {
    private struct Sheet: View {
        @Environment(\.dismiss)
        private var dismiss
        
        let option: Comorbidity
        @Binding var selection: Comorbidities.Status
        @State private var showDiagnosisDatePicker = true
        
        var body: some View {
            NavigationStack { // swiftlint:disable:this closure_body_length
                Form { // swiftlint:disable:this closure_body_length
                    Section {
                        Button {
                            if selection == .notSelected {
                                selection = .selected(startDate: DateComponents())
                            }
                        } label: {
                            HStack {
                                Text("I have this comorbidity")
                                Spacer()
                                // No need to have a condition here, this sheet is only presented if the user has selected yes.
                                Image(systemSymbol: .checkmark)
                                    .fontWeight(.medium)
                                    .accessibilityLabel("Selection Checkmark")
                            }
                        }
                        Button("I don't have this comorbidity") {
                            selection = .notSelected
                            dismiss()
                        }
                    }
                    Section("Date of Diagnosis") {
                        Picker("", selection: $showDiagnosisDatePicker) {
                            Text("Don't Know").tag(false)
                            Text("Select Date").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if showDiagnosisDatePicker {
                            MonthYearPicker(selection: Binding<DateComponents> {
                                switch selection {
                                case .notSelected:
                                    DateComponents()
                                case .selected(let startDate):
                                    startDate
                                }
                            } set: { newValue in
                                selection = .selected(startDate: newValue)
                            })
                        }
                    }
                }
                .navigationTitle(option.title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Done", systemSymbol: .checkmark)
                        }
                    }
                }
                .onChange(of: showDiagnosisDatePicker) { oldValue, newValue in
                    if oldValue && !newValue {
                        // ie, the user has tapped the "don't know" option
                        selection = .selected(startDate: DateComponents())
                    }
                }
            }
        }
    }
}


extension ComorbiditiesPicker {
    /// A custom date picker that supports month-and-year, just-year, and empty selections.
    private struct MonthYearPicker: View {
        @Environment(\.locale)
        private var locale
        @Binding private var selection: DateComponents
        
        private var currentYear: Int {
            locale.calendar.component(.year, from: .now)
        }
        
        var body: some View {
            HStack(spacing: 0) {
                Picker("", selection: $selection.month) {
                    Text("—")
                        .tag(Int?.none)
                    ForEach(0..<12, id: \.self) { monthIdx in
                        Text(locale.calendar.monthSymbols[monthIdx])
                            .tag(monthIdx + 1)
                    }
                }
                .accessibilityIdentifier("MonthPicker")
                Picker("", selection: $selection.year) {
                    ForEach(((currentYear - 100)...currentYear).reversed(), id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                .accessibilityIdentifier("YearPicker")
            }
            .pickerStyle(.wheel)
            .onChange(of: selection.year, initial: true) { _, newValue in
                if newValue == nil {
                    selection.year = currentYear
                }
            }
        }
        
        init(selection: Binding<DateComponents>) {
            _selection = selection
        }
    }
}
