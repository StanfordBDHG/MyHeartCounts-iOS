//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if canImport(HealthKit)

public import class HealthKit.HKUnit
private import SpeziFoundation


public protocol _HKUnitCodableExtensionProtocol: Codable {
    static func parse(_ unitString: String) -> HKUnit?
    var unitString: String { get }
}

extension _HKUnitCodableExtensionProtocol {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let unitString = try container.decode(String.self)
        guard let unit = Self.parse(unitString) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Invalid unit string '\(unitString)'"
            ))
        }
        self = unit as! Self
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(unitString)
    }
}


extension HKUnit: _HKUnitCodableExtensionProtocol, @retroactive Codable {
    public static func parse(_ unitString: String) -> HKUnit? {
        // ideally this would be a failing convenience init, but the language isn't able to express that.
        // (we could define it as a category in ObjC, but this is good enough...)
        try? catchingNSException {
            HKUnit(from: unitString)
        }
    }
}


#endif
