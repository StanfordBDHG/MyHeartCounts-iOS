// swift-tools-version: 6.2

//
// This source file is part of the My Heart Counts iOS application based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//


import PackageDescription

let package = Package(
    name: "MyHeartCountsShared",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "MyHeartCountsShared", targets: ["MyHeartCountsShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziStudy.git", from: "0.1.15"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", from: "7.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MyHeartCountsShared",
            dependencies: [
                .product(name: "SpeziStudyDefinition", package: "SpeziStudy"),
                .product(name: "SFSafeSymbols", package: "SFSafeSymbols")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault")
            ]
        )
    ]
)
