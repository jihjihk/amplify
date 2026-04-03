// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WritingHub",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/jihjihk/MarkupEditor.git", branch: "fix/swift6-deinit"),
    ],
    targets: [
        .target(
            name: "WritingHubLib",
            dependencies: ["SwiftTerm", "Yams", "MarkupEditor"],
            path: "Sources/WritingHubLib",
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/markdown-editor.css"),
            ]
        ),
        .executableTarget(
            name: "WritingHub",
            dependencies: ["WritingHubLib"],
            path: "Sources/WritingHub",
            exclude: [
                "Amplify.entitlements",
                "Info.plist",
            ]
        ),
        .testTarget(
            name: "WritingHubTests",
            dependencies: ["WritingHubLib"]
        ),
    ]
)
