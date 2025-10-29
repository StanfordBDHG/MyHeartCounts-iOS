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
    
    let code: String
    let display: String?
    
    init(_ code: String, display: String? = nil) {
        self.code = code
        self.display = display
    }
}


extension SpeziCodingSystem {
    static let watchWristLocation = Self("watchWristLocation")
    static let watchCrownOrientation = Self("watchCrownOrientation")
}
