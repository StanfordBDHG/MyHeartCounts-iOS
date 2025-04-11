//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


enum PossiblyLoading<Value> {
    case loading
    case loaded(Value)
    case error(any Error)
}

extension PossiblyLoading: Sendable where Value: Sendable {}
