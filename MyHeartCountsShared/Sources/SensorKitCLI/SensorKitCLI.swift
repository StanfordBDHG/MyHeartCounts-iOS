//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ArgumentParser
import Foundation


@main
struct SensorKitCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: nil,
        abstract: "Work with SensorKit data collected by the My Heart Counts iOS app",
        usage: nil,
        discussion: "",
        version: "0.0.1",
        shouldDisplay: true,
        subcommands: [DecodePPG.self],
        groupedSubcommands: [],
        defaultSubcommand: nil,
        helpNames: nil,
        aliases: []
    )
    
    func run() throws {
        print(Self.helpMessage())
    }
}
