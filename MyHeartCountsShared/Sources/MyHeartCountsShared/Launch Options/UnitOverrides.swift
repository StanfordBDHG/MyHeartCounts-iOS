//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


extension LaunchOptions {
    enum HeightInputUnitOverride: LaunchOptionDecodable {
        case none
        case cm // swiftlint:disable:this identifier_name
        case feet
        
        init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
            try context.assertNumRawArgs(.atMost(1))
            switch context.rawArgs[safe: 0] {
            case nil, "none":
                self = .none
            case "cm":
                self = .cm
            case "feet":
                self = .feet
            case .some(let value):
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: value)
            }
        }
    }
    
    static let heightInputUnitOverride = LaunchOption<HeightInputUnitOverride>("--heightInputUnitOverride", default: .none)
}


extension LaunchOptions {
    enum WeightInputUnitOverride: LaunchOptionDecodable {
        case none
        case kg // swiftlint:disable:this identifier_name
        case lbs
        
        init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
            try context.assertNumRawArgs(.atMost(1))
            switch context.rawArgs[safe: 0] {
            case nil, "none":
                self = .none
            case "kg":
                self = .kg
            case "lbs":
                self = .lbs
            case .some(let value):
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: value)
            }
        }
    }
    
    static let weightInputUnitOverride = LaunchOption<WeightInputUnitOverride>("--weightInputUnitOverride", default: .none)
}
