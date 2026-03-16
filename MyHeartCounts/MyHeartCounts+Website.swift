//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import MyHeartCountsShared
import Spezi
import SpeziFoundation


extension MyHeartCounts {
    /// Returns the official My Heart Counts study website, for the specified region.
    ///
    /// - parameter region: The region whose website should be returned. If omitted, the region is determined based on the app's available context.
    @MainActor
    static func website(for region: Locale.Region? = nil) -> URL {
        switch region {
        case .none:
            guard Spezi.didLoadFirebase else {
                // we don't know which firebase deployment we're connected to, so we return the one for the current region
                return website(for: Locale.current.region ?? .unitedStates)
            }
            switch LocalPreferencesStore.standard[.lastUsedFirebaseConfig] {
            case .none:
                // should be unreachable, but we handle it like the case where we're not connected to firebase at all
                return website(for: Locale.current.region ?? .unitedStates)
            case .custom, .customUrl:
                // development only
                return website(for: .unitedStates)
            case .region(let region):
                return website(for: region)
            }
        case .some(.unitedKingdom):
            // TASK: swap out for UK website once available
            return "https://myheartcounts.stanford.edu"
        case .some:
            return "https://myheartcounts.stanford.edu"
        }
    }
}
