//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct Comorbidities: Hashable, Codable {
    private typealias Entries = [Comorbidity.ID: String]
    
    enum Status: Hashable, Codable {
        /// the user did not select this comorbidity
        case notSelected
        /// the user did select this comorbidity, and optionally specified a start date.
        case selected(startDate: DateComponents)
    }
    
    private var entries: Entries = [:]
    
    var count: Int {
        entries.count
    }
    
    init() {}
    
    init(from decoder: any Decoder) throws {
        entries = try Entries(from: decoder)
    }
    
    func encode(to encoder: any Encoder) throws {
        try entries.encode(to: encoder)
    }
    
    subscript(option: Comorbidity) -> Status {
        get {
            switch entries[option.id] {
            case .none:
                return .notSelected
            case .some(let string): // yyyy-MM
                let components = string.split(separator: "-").map { Int($0) }
                return if components.isEmpty {
                    .selected(startDate: DateComponents())
                } else if components.count == 1 {
                    .selected(startDate: DateComponents(year: components[0]))
                } else {
                    .selected(startDate: DateComponents(year: components[0], month: components[1]))
                }
            }
        }
        set {
            switch newValue {
            case .notSelected:
                entries[option.id] = nil
            case .selected(let startDate):
                if let year = startDate.year, let month = startDate.month {
                    entries[option.id] = String(format: "%.04ld-%.02ld", year, month)
                } else if let year = startDate.year {
                    entries[option.id] = String(format: "%.04ld", year)
                } else {
                    entries[option.id] = ""
                }
            }
        }
    }
}


extension Comorbidities {
    struct Comorbidity: Hashable, Identifiable {
        let id: String
        let title: LocalizedStringResource
        let subtitle: LocalizedStringResource?
        
        init(id: String, title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
        }
        
        init?(id: String) {
            if let value = (Self.primaryComorbidities + Self.secondaryComorbidities).first(where: { $0.id == id }) {
                self = value
            } else {
                return nil
            }
        }
    }
}


extension Comorbidities.Comorbidity {
    static let primaryComorbidities: [Self] = [
        Self(id: "diabetes", title: "Diabetes"),
        Self(id: "heartFailure", title: "Heart Failure"),
        Self(id: "coronaryArteryDisease", title: "Coronary Artery Disease"),
        Self(id: "pulmonaryArterialHypertension", title: "Pulmonary Arterial Hypertension"),
        Self(id: "adultCongenitalHeartDisease", title: "Adult Congenital Heart Disease")
    ]
    
    static let secondaryComorbidities: [Self] = [
        Self(id: "abdominalAorticAneurysm", title: "Abdominal Aortic Aneurysm"),
        Self(id: "angina", title: "Angina (heart chest pains)"),
        Self(id: "aFib", title: "Atrial fibrillation (Afib)"),
        Self(id: "carotidArteryBlockageStenosis", title: "Carotid Artery Blockage/Stenosis"),
        Self(id: "carotidArterySurgeryOrStent", title: "Carotid Artery Surgery or Stent"),
        Self(id: "chronicKidneyDisease", title: "Chronic kidney disease", subtitle: "stage 3, 4 or 5"),
        Self(id: "congenitalHeartDefect", title: "Congenital Heart Defect"),
        Self(id: "coronaryBlockageStenosis", title: "Coronary Blockage/Stenosis"),
        Self(id: "coronaryStentAngioplasty", title: "Coronary Stent/Angioplasty"),
        Self(id: "erectileDysfunction", title: "Erectile dysfunction"),
        Self(id: "heartAttackMyocardialInfarction", title: "Heart Attack/Myocardial Infarction"),
        Self(id: "heartBypassSurgery", title: "Heart Bypass Surgery"),
        Self(id: "heartFailureOrCHF", title: "Heart Failure or CHF"),
        Self(id: "highCoronaryCalciumScore", title: "High Coronary Calcium Score"),
        Self(id: "migraines", title: "Migraines"),
        Self(id: "otherAutoImmuneDisease", title: "Other auto-immune disease"),
        Self(id: "peripheralVascularDisease", title: "Peripheral Vascular Disease", subtitle: "Blockage/Stenosis, Surgery, or Stent"),
        Self(id: "pulmonaryArterialHypertension", title: "Pulmonary Arterial Hypertension"),
        Self(id: "pulmonaryHypertension", title: "Pulmonary Hypertension"),
        Self(id: "raynaudsPhenomenon", title: "Raynaud's Phenomenon"),
        Self(id: "rheumatoidArthritis", title: "Rheumatoid arthritis"),
        Self(
            id: "severeMentalIllness",
            title: "Severe mental illness",
            subtitle: "this includes schizophrenia, bipolar disorder and moderate/severe depression"
        ),
        Self(id: "stroke", title: "Stroke"),
        Self(id: "systemicLupusErythematosus", title: "Systemic lupus erythematosus (SLE)"),
        Self(id: "systemicSclerosisOrScleroderma", title: "Systemic Sclerosis or Scleroderma"),
        Self(id: "transientIschemicAttack", title: "Transient Ischemic Attack (TIA)")
    ]
}
