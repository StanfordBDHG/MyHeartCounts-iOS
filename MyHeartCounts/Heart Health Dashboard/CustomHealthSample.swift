//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziHealthKit
import SwiftData


@Model
final class CustomHealthSample {
    enum SampleType: Int, Codable, Identifiable {
        case nicotineExposure = 1
        case bloodLipids = 2
        case dietMEPAScore = 3 // TODO better name!
        
        var id: Int { rawValue }
    }
    
    enum NicotineExposureCategoryValues: Int, Hashable, Sendable, CaseIterable {
        case neverSmoked = 0
        case quitMoreThan5YearsAgo = 1
        case quitWithin1To5Years = 2
        case quitWithinLastYearOrIsUsingNDS = 3
        case activelySmoking = 4
    }
    
    @Attribute(.unique)
    private(set) var id: UUID
    
    private(set) var startDate: Date
    private(set) var endDate: Date
    
    private(set) var sampleTypeRawValue: SampleType.RawValue // ewwww
    
    private(set) var unitString: String
    private(set) var value: Double
    
    var timeRange: Range<Date> {
        startDate..<endDate
    }
    
    var sampleType: SampleType {
        @storageRestrictions(initializes: _sampleTypeRawValue, accesses: _$backingData)
        init(initialValue) {
            _sampleTypeRawValue = .init()
            _$backingData.setValue(forKey: \.sampleTypeRawValue, to: initialValue.rawValue)
        }
        get {
            SampleType(rawValue: sampleTypeRawValue)! // swiftlint:disable:this force_unwrapping
        }
        set {
            sampleTypeRawValue = newValue.rawValue
        }
    }
    
    var unit: HKUnit {
        @storageRestrictions(initializes: _unitString, accesses: _$backingData)
        init(initialValue) {
            _unitString = .init()
            _$backingData.setValue(forKey: \.unitString, to: initialValue.unitString)
        }
        get {
            HKUnit(from: unitString)
        }
        set {
            unitString = newValue.unitString
        }
    }
    
    init(sampleType: SampleType, startDate: Date, endDate: Date, unit: HKUnit, value: Double) {
        self.id = UUID()
        self.sampleType = sampleType
        self.startDate = startDate
        self.endDate = endDate
        self.unit = unit
        self.value = value
    }
    
    convenience init(sampleType: SampleType, date: Date, unit: HKUnit, value: Double) {
        self.init(sampleType: sampleType, startDate: date, endDate: date, unit: unit, value: value)
    }
}


extension CustomHealthSample.SampleType {
    var displayTitle: String {
        switch self {
        case .bloodLipids:
            "Blood Lipids"
        case .nicotineExposure:
            "Nicotine Exposure"
        case .dietMEPAScore:
            "Diet (MEPA Score)"
        }
    }
}
