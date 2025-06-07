//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziHealthKit


/// Compare two sample types, based on their identifiers
@inlinable // swiftlint:disable:next static_operator
public func ~= (pattern: SampleType<some Any>, value: SampleTypeProxy) -> Bool { // donate to SpeziHealthKit eventually!
    pattern.id == value.id
}
