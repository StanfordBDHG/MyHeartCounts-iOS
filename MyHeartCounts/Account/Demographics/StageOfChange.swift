//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct StageOfChangeOption: Hashable, Identifiable, Sendable {
    let id: String
    // periphery:ignore - API
    let title: LocalizedStringResource?
    let text: LocalizedStringResource
}


extension StageOfChangeOption: Codable {
    init?(id: ID) {
        if let option = (Self.allOptions + [.notSet]).first(where: { $0.id == id }) {
            self = option
        } else {
            return nil
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let id = try container.decode(ID.self)
        if let option = Self(id: id) {
            self = option
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown id '\(id)'"))
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}


extension StageOfChangeOption {
    static let notSet = Self(id: "0", title: nil, text: "Not Set")
    
    static let allOptions: [Self] = [
        Self(id: "a", title: nil, text: "STAGE_OF_CHANGE_OPTION_A"),
        Self(id: "b", title: nil, text: "STAGE_OF_CHANGE_OPTION_B"),
        Self(id: "c", title: nil, text: "STAGE_OF_CHANGE_OPTION_C"),
        Self(id: "d", title: nil, text: "STAGE_OF_CHANGE_OPTION_D"),
        Self(id: "e", title: nil, text: "STAGE_OF_CHANGE_OPTION_E"),
        Self(id: "f", title: nil, text: "STAGE_OF_CHANGE_OPTION_F"),
        Self(id: "g", title: nil, text: "STAGE_OF_CHANGE_OPTION_G"),
        Self(id: "h", title: nil, text: "STAGE_OF_CHANGE_OPTION_H"),
        Self(id: "i", title: nil, text: "STAGE_OF_CHANGE_OPTION_I")
    ]
}
