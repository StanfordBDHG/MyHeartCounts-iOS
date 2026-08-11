//
// This source file is part of the My Heart Counts iOS open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

#if !os(Linux)

import Foundation
@testable import MyHeartCountsShared
import Testing


@Suite
struct MHCLaunchOptionsTests {
    @Test
    func setupEnvConfig() throws {
        let input = SetupTestEnvironmentConfig(
            resetExistingData: true,
            loginAndEnroll: .enable(.init(username: "LoMhrYN@stanford.edu", password: ">G;IFozm$]+M"))
        )
        let argvInput = input.launchOptionArgs(for: .setupTestEnvironment)
        #expect(argvInput == [
            "--setupTestEnvironment", "reset", "login-and-enroll:lomhryn@stanford.edu;>G;IFozm$]+M"
        ])
        let container = LaunchOptions.commandLineOptionsContainer(for: [""] + argvInput)
        let parsed = try container._decode(.setupTestEnvironment)
        #expect(parsed == input)
    }
}

#endif
