//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SFSafeSymbols
import Spezi
import SpeziFoundation
import SpeziSensorKit
import SwiftUI


#if DEBUG
extension SensorKitDataFetcher {
    struct TriggerBackgroundTaskMenu: View {
        @Environment(MHCBackgroundTasks.self)
        private var backgrundTasks
        
        var body: some View {
            Menu {
                makeButton("SensorKit", for: .sensorKitProcessing)
                makeButton("App Refresh", for: .generalAppRefresh)
            } label: {
                Label("Trigger Background Task", systemSymbol: .insetFilledCircle)
            }
        }
        
        private func makeButton(_ title: String, for taskId: MHCBackgroundTasks.TaskIdentifier) -> some View {
            Button(title) {
                backgrundTasks.trigger(taskId)
            }
        }
    }
}
#endif
