//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


public protocol _UnitOverrideLaunchOption: LaunchOptionDecodable, LaunchOptionEncodable, RawRepresentable, CaseIterable where RawValue == String {
    static var none: Self { get }
}


extension _UnitOverrideLaunchOption {
    public init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
        try context.assertNumRawArgs(.atMost(1))
        switch context.rawArgs[safe: 0] {
        case nil, "none":
            self = .none
        case .some(let arg):
            if let selfValue = Self.allCases.first(where: { $0.rawValue == arg }) {
                self = selfValue
            } else {
                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: arg)
            }
//        case "cm":
//            self = .cm
//        case "feet":
//            self = .feet
//        case .some(let value):
//            throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: value)
        }
    }
    
    public func launchOptionArgs(for launchOption: LaunchOption<Self>) -> [String] {
        if self == .none {
            []
        } else {
            [launchOption.key, self.rawValue]
        }
    }
}

extension LaunchOptions {
    public enum HeightInputUnitOverride: String, _UnitOverrideLaunchOption {
        case none
        case cm // swiftlint:disable:this identifier_name
        case feet
        
//        public init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
//            try context.assertNumRawArgs(.atMost(1))
//            switch context.rawArgs[safe: 0] {
//            case nil, "none":
//                self = .none
//            case "cm":
//                self = .cm
//            case "feet":
//                self = .feet
//            case .some(let value):
//                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: value)
//            }
//        }
//        
//        public func launchOptionArgs(for launchOption: LaunchOption<Self>) -> [String] {
//        }
    }
    
    public static let heightInputUnitOverride = LaunchOption<HeightInputUnitOverride>("--heightInputUnitOverride", default: .none)
}


extension LaunchOptions {
    public enum WeightInputUnitOverride: String, _UnitOverrideLaunchOption {
        case none
        case kg // swiftlint:disable:this identifier_name
        case lbs
        
//        public init(decodingLaunchOption context: LaunchOptionDecodingContext) throws {
//            try context.assertNumRawArgs(.atMost(1))
//            switch context.rawArgs[safe: 0] {
//            case nil, "none":
//                self = .none
//            case "kg":
//                self = .kg
//            case "lbs":
//                self = .lbs
//            case .some(let value):
//                throw LaunchOptionDecodingError.unableToDecode(Self.self, rawValue: value)
//            }
//        }
    }
    
    public static let weightInputUnitOverride = LaunchOption<WeightInputUnitOverride>("--weightInputUnitOverride", default: .none)
}
