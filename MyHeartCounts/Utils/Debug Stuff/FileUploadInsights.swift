//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable all

import Foundation
import SwiftUI


struct FileUploadInsights: View {
    @Environment(ManagedFileUpload.self) private var managedFileUpload
    
    var body: some View {
        Form {
            ForEach(managedFileUpload.categories) { category in
                Section(category.id) {
                    if let progress = managedFileUpload.progressByCategory[category] {
                        ProgressView(progress)
                    } else {
                        Text("No active uploads")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
