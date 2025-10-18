//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI


@propertyWrapper
struct TriggerUpdate: DynamicProperty, @unchecked Sendable {
    struct X { // swiftlint:disable:this type_name
        fileprivate init() {}
    }
    
    @State private var id = UUID()
    
    var wrappedValue: X {
        _ = id
        return X()
    }
    
    var projectedValue: @Sendable () -> Void {
        {
            Task { @MainActor in
                id = UUID()
            }
        }
    }
}
