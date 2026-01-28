//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if canImport(SFSafeSymbols) && canImport(SpeziStudyDefinition)

public import SFSafeSymbols
public import SpeziStudyDefinition


extension TimedWalkingTestConfiguration.Kind {
    /// A SFSymbol suitable for the test
    @inlinable public var symbol: SFSymbol {
        switch self {
        case .walking: .figureWalk
        case .running: .figureRun
        }
    }
}

#endif
