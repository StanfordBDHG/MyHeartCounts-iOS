//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKitOnFHIR
import SpeziFoundation
import SpeziHealthKit
import SpeziHealthKitBulkExport


struct HealthKitSamplesToFHIRJSONProcessor: BatchProcessor {
    typealias Output = URL?
    
    func process<Sample>(_ samples: consuming [Sample], of sampleType: SampleType<Sample>) async throws -> URL? {
        guard !samples.isEmpty else {
            return nil
        }
        return try storeSamples(samples, of: sampleType)
    }
    
    private func storeSamples<Sample>(_ samples: consuming [Sample], of sampleType: SampleType<Sample>) throws -> URL {
        let fileManager = FileManager.default
        let resources = try (consume samples).mapIntoResourceProxies()
        let encoded = try JSONEncoder().encode(consume resources)
        
        let compressed = try (consume encoded).compressed(using: Zlib.self)
        let compressedUrl = fileManager.temporaryDirectory.appendingPathComponent("\(sampleType.id)_\(UUID().uuidString).json.zlib")
        try (consume compressed).write(to: compressedUrl)
        return compressedUrl
    }
}
