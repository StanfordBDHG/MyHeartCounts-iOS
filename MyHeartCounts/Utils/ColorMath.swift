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


func lerp<T: FloatingPoint>(from a: T, to b: T, t: T) -> T { // swiftlint:disable:this identifier_name
    a + (b - a) * t
}

extension Gradient {
    func color(at position: CGFloat) -> Color {
        guard !stops.isEmpty else {
            preconditionFailure("Empty gradient!")
        }
        precondition(stops.isSorted(by: { $0.location < $1.location }))
        
        let position = position.clamped(to: 0...1)
        
        guard stops.count > 1 else {
            return stops[0].color
        }
        
        if let stop = stops.first, position <= stop.location {
            return stop.color
        } else if let stop = stops.last, position >= stop.location {
            return stop.color
        }
        
        let surroundingStops = stops.adjacentPairs().first { (lhs, rhs) in
            (lhs.location...rhs.location).contains(position)
        }
        guard let (stop1, stop2) = surroundingStops else {
            fatalError("unreachable")
        }

        // 5. Calculate the interpolation factor (t) for the segment
        // This 't' is normalized to the space *between* stop1.location and stop2.location
        let segmentLength = stop2.location - stop1.location
        
        // If p is exactly at stop1.location, or if segmentLength is 0 (stops are at same location)
        if segmentLength <= 0 { // Using <= 0 to catch potential floating point issues if very close
            return stop1.color // Or stop2.color if p is closer to it, but stop1 is fine
        }
        
        let rgba1 = stop1.color.resolve(in: .init())
        let rgba2 = stop2.color.resolve(in: .init())
        
        let t = (position - stop1.location) / segmentLength
        
        let red = lerp(from: Double(rgba1.red), to: Double(rgba2.red), t: t)
        let green = lerp(from: Double(rgba1.green), to: Double(rgba2.green), t: t)
        let blue = lerp(from: Double(rgba1.blue), to: Double(rgba2.blue), t: t)
        let alpha = lerp(from: Double(rgba1.opacity), to: Double(rgba2.opacity), t: t)
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}



extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
