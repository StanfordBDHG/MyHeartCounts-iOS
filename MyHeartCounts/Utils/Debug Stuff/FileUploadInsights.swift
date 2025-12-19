//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct FileUploadInsights: View {
    @Environment(ManagedFileUpload.self)
    private var managedFileUpload
    
    private var inactiveCategories: [ManagedFileUpload.Category] {
        managedFileUpload.categories.filter { category in
            if let progress = managedFileUpload.progressByCategory[category] {
                progress.isFinished
            } else {
                true
            }
        }
    }
    
    var body: some View {
        Form {
            ForEach(Array(managedFileUpload.categories)) { category in
                if let progress = managedFileUpload.progressByCategory[category] {
                    Section(category.title) {
                        ProgressView(progress)
                    }
                }
            }
            Section("Inactive / Complete" as String) {
                ForEach(inactiveCategories) { category in
                    Text(category.title)
                }
            }
        }
    }
}
