//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI



struct TmpSamplesQueryer<DataSource: HealthDashboardLayout.CustomDataSourceProtocol>: View {
    var dataSource: DataSource
    
    var body: some View {
        Form {
            ForEach(dataSource.samples) { sample in
                Text("\(sample)")
            }
        }
    }
}
