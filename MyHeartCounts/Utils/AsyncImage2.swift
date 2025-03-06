//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


struct AsyncImage2: View {
    let data: Data
    
    @State private var internals = AsyncImage2Coordinator()
    
    
    var body: some View {
        Group {
            if let uiImage = internals.uiImage {
                Image(uiImage: uiImage).resizable()
            }
        }.onAppear {
            internals.loadImage(from: data)
        }
    }
}


@Observable
private final class AsyncImage2Coordinator: @unchecked Sendable {
    var uiImage: UIImage?
    
    @ObservationIgnored
    private var data: Data?
    
//    @ObservationIgnored
//    private var imageLoadingTask: Task<Void, Never>?
    
    
    func loadImage(from data: Data) {
//        imageLoadingTask?.cancel()
//        imageLoadingTask = nil
        guard data != self.data else {
            return
        }
        self.data = data
        Task.detached(priority: .userInitiated) {
            self.uiImage = UIImage(data: data)
        }
    }
}
