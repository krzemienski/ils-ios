// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ILSApp",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ILSShared",
            targets: ["ILSShared"]
        ),
        .executable(
            name: "ILSBackend",
            targets: ["ILSBackend"]
        )
    ],
    dependencies: [
        // Vapor web framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // Fluent ORM
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // SQLite driver for Fluent
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        // YAML parsing for skill files
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        // Claude Code SDK for CLI integration (forked for customization)
        .package(url: "https://github.com/krzemienski/ClaudeCodeSDK.git", branch: "main"),
    ],
    targets: [
        // Shared models between iOS and backend
        .target(
            name: "ILSShared",
            dependencies: [],
            path: "Sources/ILSShared"
        ),
        // Vapor backend
        .executableTarget(
            name: "ILSBackend",
            dependencies: [
                "ILSShared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK"),
            ],
            path: "Sources/ILSBackend"
        ),
        // Tests
        .testTarget(
            name: "ILSSharedTests",
            dependencies: ["ILSShared"],
            path: "Tests/ILSSharedTests"
        ),
        .testTarget(
            name: "ILSBackendTests",
            dependencies: [
                "ILSBackend",
                .product(name: "XCTVapor", package: "vapor"),
            ],
            path: "Tests/ILSBackendTests"
        ),
    ]
)
