//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MarkdownUI
import SFSafeSymbols
import SpeziHealthKit
import SpeziHealthKitUI
import SpeziViews
import SwiftUI


struct ECGInstructionsSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @HealthKitQuery(.electrocardiogram, timeRange: .today)
    private var ecgSamples
    
    @State private var viewTimestamp = Date()
    @State private var didRecordECG = false
    
    private let shouldOfferManualCompletion: Bool
    private let successHandler: @MainActor () -> Void
    
    var body: some View {
        content
            .navigationTitle("ECG")
            .toolbar {
                if !didRecordECG {
                    ToolbarItem(placement: .cancellationAction) {
                        DismissButton()
                    }
                    if shouldOfferManualCompletion {
                        ToolbarItem(placement: .confirmationAction) {
                            Menu {
                                Button(action: successHandler) {
                                    Label("Mark as Complete", systemSymbol: .checkmarkCircle)
                                }
                            } label: {
                                Image(systemSymbol: .ellipsisCircle)
                                    .accessibilityLabel("More")
                            }
                        }
                    }
                }
            }
            .onChange(of: ecgSamples.last) { (_, sample: HKElectrocardiogram?) in
                if !didRecordECG, let sample, sample.startDate >= viewTimestamp {
                    didRecordECG = true
                    successHandler()
                }
            }
    }
    
    @ViewBuilder private var content: some View {
        if !didRecordECG {
            ScrollView {
                VStack(alignment: .leading) {
                    let text = String(localized: "ECG_INSTRUCTIONS_TEXT")
                    Markdown(text)
                        .padding(.horizontal)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemSymbol: .checkmarkCircle)
                    .font(.system(size: 75))
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
                    .padding(.top, 30)
                Text("Success")
                    .font(.title)
                    .foregroundStyle(.primary)
                Text("Your ECG has successfully been recorded")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("OK")
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .bold()
                }
                .buttonStyleGlassProminent()
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
        }
    }
    
    /// - parameter shouldOfferManualCompletion: whether the sheet should offer, via a button hidden behind a "more" menu, the user the ability to manually consider the ECG as completed.
    init(shouldOfferManualCompletion: Bool, successHandler: @escaping @MainActor () -> Void) {
        self.shouldOfferManualCompletion = shouldOfferManualCompletion
        self.successHandler = successHandler
    }
}
