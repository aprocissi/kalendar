// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Kalendar",
    platforms: [.macOS(.v14)],
    dependencies: [
        // in-app updates; the appcast is attached to each GitHub release
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .target(name: "KalendarCore", path: "Sources/KalendarCore"),
        .executableTarget(
            name: "Kalendar",
            dependencies: ["KalendarCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Kalendar"),
        .testTarget(name: "KalendarCoreTests", dependencies: ["KalendarCore"], path: "Tests/KalendarCoreTests"),
    ]
)
