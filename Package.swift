// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Reminders",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "Reminders", targets: ["Reminders"])
    ],
    targets: [
        .executableTarget(
            name: "Reminders",
            path: "Sources/Reminders",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RemindersTests",
            dependencies: ["Reminders"],
            path: "Tests/RemindersTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
