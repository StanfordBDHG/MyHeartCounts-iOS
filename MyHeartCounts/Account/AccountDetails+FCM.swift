//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziAccount


extension AccountDetails {
    @AccountKey(id: "fcmToken", name: "FCM Token", as: String.self)
    var fcmToken: String?
}


@KeyEntry(\.fcmToken)
extension AccountKeys {}
