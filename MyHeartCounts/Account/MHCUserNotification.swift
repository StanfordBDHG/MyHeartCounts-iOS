//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


struct MHCUserNotification: Decodable {
    let originalTimestamp: Date
    let title: String
    let body: String
}
