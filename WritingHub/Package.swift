// swift-tools-version: 5.9
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
        .executableTarget(
            name: "WritingHub",
            dependencies: ["SwiftTerm", "Yams", "MarkupEditor"]
        ),
        .testTarget(
            name: "WritingHubTests",
            dependencies: ["WritingHub"]
        ),
    ]
)
