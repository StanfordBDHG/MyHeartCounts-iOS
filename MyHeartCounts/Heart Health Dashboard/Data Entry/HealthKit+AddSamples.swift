//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziHealthKit


extension HealthKit {
    func save(_ sample: HKSample) async throws {
        try await save(CollectionOfOne(sample))
    }
    
    func save(_ samples: some Collection<HKSample>) async throws {
        let permissions = samples.reduce(into: DataAccessRequirements()) { reqs, sample in
            reqs.merge(with: .init(readAndWrite: CollectionOfOne(sample.sampleType)))
        }
        try await askForAuthorization(for: permissions)
        try await healthStore.save(Array(samples))
    }
}
