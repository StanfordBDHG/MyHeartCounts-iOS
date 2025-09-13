//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct BloodPressureMeasurement: Hashable, CustomStringConvertible, Sendable {
    /// The systolic blood pressure, in mmHg
    let systolic: Int
    /// The diastolic blood pressure, in mmHg
    let diastolic: Int
    
    var description: String {
        "\(systolic)/\(diastolic)"
    }
}
