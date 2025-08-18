//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import XCTest


func sleep(for duration: Duration) {
    usleep(UInt32(duration.timeInterval * 1000000))
}


extension XCUIElement {
    enum Direction {
        case up, down, left, right // swiftlint:disable:this identifier_name
        
        var opposite: Self {
            switch self {
            case .up: .down
            case .down: .up
            case .left: .right
            case .right: .left
            }
        }
    }
    
    func swipe(_ direction: Direction, velocity: XCUIGestureVelocity = .default) {
        switch direction {
        case .up:
            swipeUp(velocity: velocity)
        case .down:
            swipeDown(velocity: velocity)
        case .left:
            swipeLeft(velocity: velocity)
        case .right:
            swipeRight(velocity: velocity)
        }
    }
}
