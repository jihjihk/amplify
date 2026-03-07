// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WritingHub",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/stevengharris/MarkupEditor.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "WritingHubLib",
            dependencies: ["SwiftTerm", "Yams", "MarkupEditor"],
            path: "Sources/WritingHubLib",
            resources: [
                .copy("Resources/Fonts"),
            ]
        ),
        .executableTarget(
            name: "WritingHub",
            dependencies: ["WritingHubLib"],
            path: "Sources/WritingHub"
        ),
        .testTarget(
            name: "WritingHubTests",
            dependencies: ["WritingHubLib"]
        ),
    ]
)
