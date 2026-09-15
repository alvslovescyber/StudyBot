// swift-tools-version: 6.0
import PackageDescription

// StudyBotUI is the design system only (spec §3.2): tokens taken verbatim from §9 and the
// primitives built from them. No screens, no stores. It depends on Kit for RelativeDate,
// the one place dates become words.
let package = Package(
    name: "StudyBotUI",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "StudyBotUI", targets: ["StudyBotUI"])
    ],
    dependencies: [
        .package(path: "../StudyBotCore"),
        .package(path: "../StudyBotKit"),
    ],
    targets: [
        .target(
            name: "StudyBotUI",
            dependencies: [
                .product(name: "StudyBotCore", package: "StudyBotCore"),
                .product(name: "StudyBotKit", package: "StudyBotKit"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "StudyBotUITests",
            dependencies: ["StudyBotUI"]
        ),
    ]
)
