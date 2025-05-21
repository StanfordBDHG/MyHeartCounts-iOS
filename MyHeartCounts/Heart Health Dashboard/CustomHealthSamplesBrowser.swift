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


struct CustomHealthSamplesBrowser: View {
    @Environment(\.modelContext)
    private var modelContext
    
    private let sampleType: CustomHealthSample.SampleType
    @Query private var samples: [CustomHealthSample]
    
    var body: some View {
        Form {
            ForEach(samples) { sample in
                makeRow(for: sample)
            }
            .onDelete { indices in
                let samplesToDelete = samples.elements(at: indices)
                for sample in samplesToDelete {
                    modelContext.delete(sample)
                }
                try? modelContext.save()
            }
        }
        .navigationTitle("\(sampleType.displayTitle)")
    }
    
    init(_ sampleType: CustomHealthSample.SampleType) {
        let sampleTypeRawValue = sampleType.rawValue
        let descriptor = FetchDescriptor<CustomHealthSample>(predicate: #Predicate { sample in
            sample.sampleTypeRawValue == sampleTypeRawValue
        }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        self.sampleType = sampleType
        self._samples = .init(descriptor)
    }
    
    
    @ViewBuilder
    private func makeRow(for sample: CustomHealthSample) -> some View {
        HStack {
            if abs(sample.startDate.distance(to: sample.endDate)) <= 1 {
                Text(sample.startDate, format: .iso8601)
            } else {
                Text("\(sample.startDate..<sample.endDate)") // give this nice formatting?!
            }
            Spacer()
            Text("\(sample.value)")
                .monospacedDigit()
            Text(sample.unitString)
                .foregroundStyle(.secondary)
        }
    }
}
