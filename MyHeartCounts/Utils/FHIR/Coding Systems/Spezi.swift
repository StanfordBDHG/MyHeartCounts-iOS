//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct SpeziCodingSystem: CodingProtocol {
    static var system: String { "https://spezi.stanford.edu" }
    
    let rawValue: String
    let displayTitle: String?
    
    init(_ code: String, displayTitle: String? = nil) {
        self.rawValue = code
        self.displayTitle = displayTitle
    }
}


extension SpeziCodingSystem {
    static let watchWristLocation = Self("watchWristLocation")
    static let watchCrownOrientation = Self("watchCrownOrientation")
}
