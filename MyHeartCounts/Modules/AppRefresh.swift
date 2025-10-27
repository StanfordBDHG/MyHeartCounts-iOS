//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi


@MainActor
final class AppRefresh: Module, Sendable {
    // swiftlint:disable attributes
    @Application(\.logger) private var logger
    @Dependency(MHCBackgroundTasks.self) private var backgroundTasks
    @Dependency(LocalNotifications.self) private var localNotifications
    // swiftlint:enable attributes
    
    func configure() {
        logger.notice("\(#function)")
        do {
            try backgroundTasks.register(.appRefresh(id: .generalAppRefresh) {
                try await self.localNotifications.send(title: "MHC App Refresh", body: "App refresh triggered")
            })
            try backgroundTasks.register(.processing(id: .generalBackgroundProcessing) {
                try await self.localNotifications.send(title: "MHC Background Processing", body: "Background Processing Task triggered")
            })
        } catch {
            self.logger.error("Error registering app refresh background task: \(error)")
            Task {
                try? await localNotifications.send(title: "MHC App Refresh", body: "Error registering app refresh background task: \(error)")
            }
        }
    }
}


extension MHCBackgroundTasks.TaskIdentifier {
    static let generalAppRefresh = Self("edu.stanford.MyHeartCounts.AppRefresh")
    static let generalBackgroundProcessing = Self("edu.stanford.MyHeartCounts.BackgroundProcessing")
}
