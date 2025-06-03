////
//// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
////
//// SPDX-FileCopyrightText: 2025 Stanford University
////
//// SPDX-License-Identifier: MIT
////
//
////import CoreHaptics
//import Foundation
//import SwiftUI
//
//
////@propertyWrapper
////struct HapticFeedback: DynamicProperty {
////    @State private let hapticsManager = HapticsManager()
////    
////    var wrappedValue: Self { self }
////}
//
//
//@Observable
//@MainActor
//public final class HapticFeedback {
//    fileprivate static let shared = HapticFeedback()
//    
//    private let hapticEngine: CHHapticEngine?
//    
//    private init() {
//        hapticEngine = try? CHHapticEngine()
//    }
//    
//    public func playLoopingFeedbackPattern(times: Int, pause: Duration) async throws {
//        guard let hapticEngine else {
//            return // TODO throw?
//        }
//        let hapticDict = [
//            CHHapticPattern.Key.pattern: [
//                [CHHapticPattern.Key.event: [
//                    CHHapticPattern.Key.eventType: CHHapticEvent.EventType.hapticTransient,
//                    CHHapticPattern.Key.time: CHHapticTimeImmediate,
//                    CHHapticPattern.Key.eventDuration: 1.0]
//                ]
//            ]
//        ]
//        let pattern = try CHHapticPattern(dictionary: hapticDict)
//        let player = try hapticEngine.makePlayer(with: pattern)
//        try hapticEngine.start()
//        try player.start(atTime: 0)
//    }
//}
//
//
//
//extension EnvironmentValues {
//    @Entry public var hapticFeedback: HapticFeedback = .shared
//}
