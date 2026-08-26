//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziFoundation

extension LocalPreferenceKeys {
    /// A `Bool` flag indicating of the onboarding was completed.
    static let onboardingFlowComplete = LocalPreferenceKey<Bool>("onboardingFlowComplete", default: false)
    
    /// Triggers a `Firestore.clearPersistence()` call the next time firebase is loaded (i.e., during the next launch).
    static let shouldClearFirestoreCacheOnNextLaunch = LocalPreferenceKey<Bool>(
        "shouldClearFirestoreCacheOnNextLaunch",
        default: true
    )
    
    /// Whether the Health Dashboard should fetch its data from the server-side stats documents
    /// (`users/{uid}/stats/{metricId}/{year}/{month}`), instead of querying HealthKit locally.
    ///
    /// This only affects sample types for which a stats-documents metric exists (see `HealthStatsMetric`);
    /// everything else always uses the regular data sources.
    static let dashboardUsesStatsDocuments = LocalPreferenceKey<Bool>("dashboardUsesStatsDocuments", default: false)
}
