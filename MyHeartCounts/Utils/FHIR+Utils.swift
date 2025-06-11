//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ModelsR4


extension ModelsR4.Resource: @retroactive Identifiable {}

extension ModelsR4.ResourceProxy {
    var observation: Observation? {
        switch self {
        case .observation(let observation):
            observation
        default:
            nil
        }
    }
}
