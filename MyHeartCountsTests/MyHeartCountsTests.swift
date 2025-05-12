//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@testable import MyHeartCounts
import Testing


extension Tag {
    /// The `unitTest` Tag identifies tags that are **non-UI** Unit Tests.
    ///
    /// The purpose of this tag is to be able to launch the app into different configurations,
    /// depending on the specific requirements of the different kinds of tests.
    /// For example, unit tests must always be run in a hosting app where firebase is completely disabled.
    @Tag static var unitTest: Self
}
