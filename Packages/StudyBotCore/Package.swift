// swift-tools-version: 6.0
import PackageDescription

// StudyBotCore is shared between the Mac app and the Vapor server (spec §3.2).
// It therefore depends on nothing but Foundation: no SwiftData, no UI, no Vapor.
let package = Package(
    name: "StudyBotCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "StudyBotCore", targets: ["StudyBotCore"])
    ],
    targets: [
        .target(
            name: "StudyBotCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "StudyBotCoreTests",
            dependencies: ["StudyBotCore"]
        ),
    ]
)
