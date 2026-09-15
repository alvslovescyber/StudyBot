// swift-tools-version: 6.0
import PackageDescription

// The StudyBot server (spec §3.2 Server/): Vapor over SQLite, sharing StudyBotCore with the
// Mac app so client and server cannot disagree about a wire shape. Four dependencies (§3.10):
// Vapor, Fluent, the SQLite driver, and Core.
let package = Package(
    name: "studybot-server",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // One binary: `studybotctl serve` runs the server, `studybotctl pair` prints a code (§3.6).
        .executable(name: "studybotctl", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.8.0"),
        .package(path: "../Packages/StudyBotCore"),
        // Tests only: the real client engine against the real server over HTTP.
        .package(path: "../Packages/StudyBotKit"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "StudyBotCore", package: "StudyBotCore"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "StudyBotKit", package: "StudyBotKit"),
            ]
        ),
    ]
)
