//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


extension UUID {
    var isValidV4: Bool {
        (self.uuid.6 & 0b11110000 == 0b01000000) && (self.uuid.8 & 0b11000000 == 0b10000000)
    }
    
    func makeValidV4() -> UUID {
        var uuid = self.uuid
        uuid.6 = (uuid.6 & 0b00001111) | 0b01000000
        uuid.8 = (uuid.8 & 0b00111111) | 0b10000000
        return UUID(uuid: uuid)
    }
}
