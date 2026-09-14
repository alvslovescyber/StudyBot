// swift-tools-version: 6.0
import PackageDescription

// StudyBotKit is client-only logic with no UI (spec §3.2): importers, scheduling,
// stores, the sync engine and support helpers. It depends on StudyBotCore.
let package = Package(
    name: "StudyBotKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "StudyBotKit", targets: ["StudyBotKit"])
    ],
    dependencies: [
        .package(path: "../StudyBotCore")
    ],
    targets: [
        .target(
            name: "StudyBotKit",
            dependencies: [
                .product(name: "StudyBotCore", package: "StudyBotCore")
            ],
            resources: [
                // The real programme calendar, bundled so first launch needs no file
                // picker (§4A). A test keeps it identical to the copy in the repo root.
                .copy("Resources/DTS_L6_Sept_2026_intake.ics")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "StudyBotKitTests",
            dependencies: ["StudyBotKit"],
            resources: [
                // programme-calendar.json, the parsed twin, for cross-checking the importer.
                .copy("Fixtures")
            ]
        ),
    ]
)
