//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


/// Live-updating view that displays the app's current memory usage. Intended for debugging purposes only.
struct MemoryUsageIndicator: View {
    private var dataSource = DataSource()
    
    var body: some View {
        LabeledContent(
            "Memory Usage",
            value: "\(ProcessInfo.processInfo.physicalMemory) / \(dataSource.residentMemory) / \(dataSource.memoryFootprint)"
        )
        .task {
            await dataSource.startUpdating(interval: .seconds(2))
        }
    }
}


extension MemoryUsageIndicator {
    @Observable
    @MainActor
    fileprivate final class DataSource {
        private(set) var residentMemory: UInt64 = 0
        private(set) var memoryFootprint: UInt64 = 0
        
        func startUpdating(interval: Duration) async {
            while !Task.isCancelled {
                self.residentMemory = ProcessInfo.residentMemory
                self.memoryFootprint = ProcessInfo.memoryFootprint
                try? await Task.sleep(for: interval)
            }
        }
    }
}
