# Writing Hub Mac App — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native SwiftUI Mac app that turns a local markdown folder into a content operating system with an embedded Claude Code terminal for AI-powered writing agents.

**Architecture:** Three-panel SwiftUI app (pipeline sidebar, WYSIWYG editor, Claude Code terminal). Local folder is the database. FSEvents watches for file changes. Git auto-commits silently. SwiftTerm for terminal emulation. MarkupEditor for WYSIWYG markdown editing.

**Tech Stack:** Swift, SwiftUI, SwiftTerm (terminal), MarkupEditor (WYSIWYG markdown), Yams (YAML frontmatter), FSEvents (file watching), shell git (silent commits). Distributed via DMG + Homebrew (no App Store — sandboxing conflicts with embedded terminal).

---

## Task 1: Project Scaffolding

**Files:**
- Create: `WritingHub/Package.swift`
- Create: `WritingHub/Sources/WritingHub/WritingHubApp.swift`
- Create: `WritingHub/Sources/WritingHub/ContentView.swift`

**Step 1: Create the Xcode project structure**

```bash
mkdir -p WritingHub/Sources/WritingHub
mkdir -p WritingHub/Tests/WritingHubTests
```

**Step 2: Create `Package.swift` with dependencies**

```swift
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
```

**Step 3: Create minimal app entry point**

```swift
// WritingHubApp.swift
import SwiftUI

@main
struct WritingHubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Writing Hub")
            .frame(minWidth: 900, minHeight: 600)
    }
}
```

**Step 4: Build and verify it launches**

Run: `cd WritingHub && swift build`
Expected: Builds successfully with dependencies resolved.

**Step 5: Commit**

```bash
git add WritingHub/
git commit -m "feat: scaffold WritingHub SwiftUI app with dependencies"
```

---

## Task 2: Data Models — Frontmatter & Writing Piece

**Files:**
- Create: `WritingHub/Sources/WritingHub/Models/WritingPiece.swift`
- Create: `WritingHub/Sources/WritingHub/Models/FrontMatter.swift`
- Create: `WritingHub/Sources/WritingHub/Models/PipelineStage.swift`
- Test: `WritingHub/Tests/WritingHubTests/FrontMatterTests.swift`

**Step 1: Write failing tests for frontmatter parsing**

```swift
// FrontMatterTests.swift
import XCTest
@testable import WritingHub

final class FrontMatterTests: XCTestCase {

    func testParseFrontMatter() throws {
        let markdown = """
        ---
        title: Test Post
        created: 2026-02-27
        edited: 2026-02-27
        version: 1
        stage: ideas
        platforms: [x, linkedin]
        ---

        # Test Post

        Some content here.
        """

        let piece = try WritingPiece.parse(from: markdown)
        XCTAssertEqual(piece.frontMatter.title, "Test Post")
        XCTAssertEqual(piece.frontMatter.version, 1)
        XCTAssertEqual(piece.frontMatter.stage, .ideas)
        XCTAssertEqual(piece.frontMatter.platforms, ["x", "linkedin"])
        XCTAssertTrue(piece.body.contains("# Test Post"))
    }

    func testSerializeFrontMatter() throws {
        let fm = FrontMatter(
            title: "Test Post",
            created: "2026-02-27",
            edited: "2026-02-27",
            version: 1,
            stage: .ideas,
            platforms: ["x"]
        )
        let piece = WritingPiece(frontMatter: fm, body: "# Test Post\n\nContent.")
        let serialized = piece.serialize()

        XCTAssertTrue(serialized.hasPrefix("---\n"))
        XCTAssertTrue(serialized.contains("title: Test Post"))
        XCTAssertTrue(serialized.contains("# Test Post"))
    }

    func testParseMarkdownWithoutFrontMatter() throws {
        let markdown = "# Just a heading\n\nNo frontmatter here."
        let piece = try WritingPiece.parse(from: markdown)
        XCTAssertNil(piece.frontMatter.title)
        XCTAssertTrue(piece.body.contains("Just a heading"))
    }

    func testParsePlatformSections() throws {
        let markdown = """
        ---
        title: Multi Platform Post
        created: 2026-02-27
        edited: 2026-02-27
        version: 2
        stage: ready
        platforms: [x, linkedin]
        ---

        # Multi Platform Post

        The main content.

        ---

        ## X Thread

        1/ First tweet.

        ---

        ## LinkedIn

        Professional version here.
        """

        let piece = try WritingPiece.parse(from: markdown)
        XCTAssertEqual(piece.platformSections.count, 2)
        XCTAssertTrue(piece.platformSections["x"]?.contains("First tweet") ?? false)
        XCTAssertTrue(piece.platformSections["linkedin"]?.contains("Professional") ?? false)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd WritingHub && swift test --filter FrontMatterTests`
Expected: FAIL — types don't exist yet.

**Step 3: Implement data models**

```swift
// PipelineStage.swift
import Foundation

enum PipelineStage: String, Codable, CaseIterable {
    case ideas
    case drafts
    case ready
    case published

    var displayName: String {
        rawValue.capitalized
    }

    var folderName: String {
        rawValue
    }

    var next: PipelineStage? {
        switch self {
        case .ideas: return .drafts
        case .drafts: return .ready
        case .ready: return .published
        case .published: return nil
        }
    }
}
```

```swift
// FrontMatter.swift
import Foundation
import Yams

struct FrontMatter: Codable {
    var title: String?
    var created: String?
    var edited: String?
    var version: Int?
    var stage: PipelineStage?
    var platforms: [String]?
}
```

```swift
// WritingPiece.swift
import Foundation
import Yams

struct WritingPiece {
    var frontMatter: FrontMatter
    var body: String
    var platformSections: [String: String]
    var filePath: URL?

    static func parse(from content: String) throws -> WritingPiece {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("---") else {
            return WritingPiece(
                frontMatter: FrontMatter(),
                body: content,
                platformSections: [:]
            )
        }

        let parts = trimmed.components(separatedBy: "\n")
        guard let endIndex = parts.dropFirst().firstIndex(of: "---") else {
            return WritingPiece(
                frontMatter: FrontMatter(),
                body: content,
                platformSections: [:]
            )
        }

        let yamlBlock = parts[1..<endIndex].joined(separator: "\n")
        let decoder = YAMLDecoder()
        let fm = try decoder.decode(FrontMatter.self, from: yamlBlock)

        let afterFrontmatter = parts[(endIndex + 1)...].joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let (mainBody, sections) = parsePlatformSections(from: afterFrontmatter)

        return WritingPiece(
            frontMatter: fm,
            body: mainBody,
            platformSections: sections
        )
    }

    func serialize() -> String {
        let encoder = YAMLEncoder()
        let yamlString = (try? encoder.encode(frontMatter)) ?? ""
        var result = "---\n\(yamlString)---\n\n\(body)"

        for (platform, content) in platformSections.sorted(by: { $0.key < $1.key }) {
            result += "\n\n---\n\n## \(platformDisplayName(platform))\n\n\(content)"
        }

        return result
    }

    private static func parsePlatformSections(from text: String) -> (String, [String: String]) {
        let sectionPattern = "\n---\n"
        let chunks = text.components(separatedBy: sectionPattern)

        guard chunks.count > 1 else {
            return (text, [:])
        }

        let mainBody = chunks[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var sections: [String: String] = [:]

        for chunk in chunks.dropFirst() {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("## ") {
                let lines = trimmed.components(separatedBy: "\n")
                let header = lines[0].replacingOccurrences(of: "## ", with: "")
                let key = header.lowercased().replacingOccurrences(of: " thread", with: "")
                    .replacingOccurrences(of: " intro hook", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let body = lines.dropFirst().joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                sections[key] = body
            }
        }

        return (mainBody, sections)
    }

    private func platformDisplayName(_ key: String) -> String {
        switch key {
        case "x": return "X Thread"
        case "linkedin": return "LinkedIn"
        case "substack": return "Substack Intro Hook"
        default: return key.capitalized
        }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `cd WritingHub && swift test --filter FrontMatterTests`
Expected: All 4 tests PASS.

**Step 5: Commit**

```bash
git add WritingHub/Sources/WritingHub/Models/ WritingHub/Tests/
git commit -m "feat: add WritingPiece data model with frontmatter parsing"
```

---

## Task 3: Folder Manager — Scaffolding & File Operations

**Files:**
- Create: `WritingHub/Sources/WritingHub/Services/FolderManager.swift`
- Test: `WritingHub/Tests/WritingHubTests/FolderManagerTests.swift`

**Step 1: Write failing tests**

```swift
// FolderManagerTests.swift
import XCTest
@testable import WritingHub

final class FolderManagerTests: XCTestCase {

    var tempDir: URL!
    var manager: FolderManager!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = FolderManager(root: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testScaffoldCreatesAllDirectories() throws {
        try manager.scaffold()

        for stage in PipelineStage.allCases {
            let dir = tempDir.appendingPathComponent(stage.folderName)
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
            XCTAssertTrue(isDir.boolValue)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("references").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent(".writinghub").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("CLAUDE.md").path))
    }

    func testLoadPiecesFromFolder() throws {
        try manager.scaffold()
        let content = """
        ---
        title: Test Idea
        created: 2026-02-27
        edited: 2026-02-27
        version: 1
        stage: ideas
        platforms: []
        ---

        # Test Idea

        A raw idea.
        """
        let ideaPath = tempDir.appendingPathComponent("ideas/test-idea.md")
        try content.write(to: ideaPath, atomically: true, encoding: .utf8)

        let pieces = try manager.loadPieces(for: .ideas)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(pieces[0].frontMatter.title, "Test Idea")
    }

    func testPromoteMovesFile() throws {
        try manager.scaffold()
        let content = """
        ---
        title: Promote Me
        created: 2026-02-27
        edited: 2026-02-27
        version: 1
        stage: ideas
        platforms: []
        ---

        # Promote Me
        """
        let ideaPath = tempDir.appendingPathComponent("ideas/promote-me.md")
        try content.write(to: ideaPath, atomically: true, encoding: .utf8)

        try manager.promote(fileName: "promote-me.md", from: .ideas)

        XCTAssertFalse(FileManager.default.fileExists(atPath: ideaPath.path))
        let newPath = tempDir.appendingPathComponent("drafts/promote-me.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath.path))

        let movedContent = try String(contentsOf: newPath, encoding: .utf8)
        XCTAssertTrue(movedContent.contains("stage: drafts"))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd WritingHub && swift test --filter FolderManagerTests`
Expected: FAIL — `FolderManager` doesn't exist.

**Step 3: Implement FolderManager**

```swift
// FolderManager.swift
import Foundation

class FolderManager: ObservableObject {
    let root: URL
    @Published var pieces: [PipelineStage: [WritingPiece]] = [:]

    init(root: URL) {
        self.root = root
    }

    func scaffold() throws {
        let fm = FileManager.default

        for stage in PipelineStage.allCases {
            let dir = root.appendingPathComponent(stage.folderName)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let extraDirs = ["references", ".writinghub"]
        for dir in extraDirs {
            try fm.createDirectory(
                at: root.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }

        let claudeMDPath = root.appendingPathComponent("CLAUDE.md")
        if !fm.fileExists(atPath: claudeMDPath.path) {
            try Self.defaultClaudeMD.write(to: claudeMDPath, atomically: true, encoding: .utf8)
        }
    }

    func loadPieces(for stage: PipelineStage) throws -> [WritingPiece] {
        let dir = root.appendingPathComponent(stage.folderName)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }

        return try files
            .filter { $0.pathExtension == "md" }
            .map { url in
                let content = try String(contentsOf: url, encoding: .utf8)
                var piece = try WritingPiece.parse(from: content)
                piece.filePath = url
                return piece
            }
            .sorted { ($0.frontMatter.edited ?? "") > ($1.frontMatter.edited ?? "") }
    }

    func loadAllPieces() throws {
        for stage in PipelineStage.allCases {
            pieces[stage] = try loadPieces(for: stage)
        }
    }

    func promote(fileName: String, from stage: PipelineStage) throws {
        guard let nextStage = stage.next else { return }

        let sourcePath = root.appendingPathComponent(stage.folderName)
            .appendingPathComponent(fileName)
        let destPath = root.appendingPathComponent(nextStage.folderName)
            .appendingPathComponent(fileName)

        var content = try String(contentsOf: sourcePath, encoding: .utf8)
        content = content.replacingOccurrences(
            of: "stage: \(stage.rawValue)",
            with: "stage: \(nextStage.rawValue)"
        )

        let today = Self.todayString()
        if let range = content.range(of: #"edited: \d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
            content.replaceSubrange(range, with: "edited: \(today)")
        }

        try content.write(to: destPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: sourcePath)
    }

    func savePiece(_ piece: WritingPiece) throws {
        guard let filePath = piece.filePath else { return }
        var updated = piece
        updated.frontMatter.edited = Self.todayString()
        let content = updated.serialize()
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    static let defaultClaudeMD: String = """
    # Writing Hub — CLAUDE.md

    You are a writing assistant operating inside a Writing Hub folder.
    See the full CLAUDE.md template for instructions.
    """
}
```

**Step 4: Run tests to verify they pass**

Run: `cd WritingHub && swift test --filter FolderManagerTests`
Expected: All 3 tests PASS.

**Step 5: Commit**

```bash
git add WritingHub/Sources/WritingHub/Services/ WritingHub/Tests/
git commit -m "feat: add FolderManager with scaffold, load, and promote"
```

---

## Task 4: File Watcher Service

**Files:**
- Create: `WritingHub/Sources/WritingHub/Services/FileWatcher.swift`
- Test: `WritingHub/Tests/WritingHubTests/FileWatcherTests.swift`

**Step 1: Write failing test**

```swift
// FileWatcherTests.swift
import XCTest
@testable import WritingHub

final class FileWatcherTests: XCTestCase {

    func testFileWatcherDetectsNewFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let expectation = XCTestExpectation(description: "File change detected")
        let watcher = FileWatcher(path: tempDir.path)
        watcher.onChange = { expectation.fulfill() }
        watcher.start()

        let newFile = tempDir.appendingPathComponent("test.md")
        try "hello".write(to: newFile, atomically: true, encoding: .utf8)

        wait(for: [expectation], timeout: 3.0)
        watcher.stop()
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd WritingHub && swift test --filter FileWatcherTests`
Expected: FAIL — `FileWatcher` doesn't exist.

**Step 3: Implement FileWatcher using FSEvents**

```swift
// FileWatcher.swift
import Foundation

class FileWatcher {
    private let path: String
    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private var pendingSelfWrites: Set<String> = []

    var onChange: (() -> Void)?

    init(path: String) {
        self.path = path
    }

    func markSelfWrite(_ filePath: String) {
        pendingSelfWrites.insert(filePath)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.pendingSelfWrites.remove(filePath)
        }
    }

    func start() {
        let pathsToWatch = [path] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.handleEvents()
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // 500ms latency (debounce)
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func handleEvents() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.onChange?()
        }
    }

    deinit {
        stop()
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd WritingHub && swift test --filter FileWatcherTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add WritingHub/Sources/WritingHub/Services/FileWatcher.swift WritingHub/Tests/
git commit -m "feat: add FSEvents-based FileWatcher with debouncing"
```

---

## Task 5: Git Service — Silent Auto-Commits

**Files:**
- Create: `WritingHub/Sources/WritingHub/Services/GitService.swift`
- Test: `WritingHub/Tests/WritingHubTests/GitServiceTests.swift`

**Step 1: Write failing test**

```swift
// GitServiceTests.swift
import XCTest
@testable import WritingHub

final class GitServiceTests: XCTestCase {

    func testInitAndAutoCommit() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let git = GitService(repoPath: tempDir)
        try git.initRepo()

        let testFile = tempDir.appendingPathComponent("test.md")
        try "hello".write(to: testFile, atomically: true, encoding: .utf8)

        try git.autoCommit(message: "test commit")

        let log = try git.log(limit: 1)
        XCTAssertTrue(log.contains("test commit"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd WritingHub && swift test --filter GitServiceTests`
Expected: FAIL — `GitService` doesn't exist.

**Step 3: Implement GitService using shell git**

```swift
// GitService.swift
import Foundation

class GitService {
    let repoPath: URL

    init(repoPath: URL) {
        self.repoPath = repoPath
    }

    func initRepo() throws {
        guard !FileManager.default.fileExists(
            atPath: repoPath.appendingPathComponent(".git").path
        ) else { return }
        try run("git", "init")
    }

    func autoCommit(message: String) throws {
        try run("git", "add", "-A")
        // Check if there's anything to commit
        let status = try runOutput("git", "status", "--porcelain")
        guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        try run("git", "commit", "-m", message, "--allow-empty-message")
    }

    func log(limit: Int) throws -> String {
        try runOutput("git", "log", "--oneline", "-\(limit)")
    }

    @discardableResult
    private func run(_ args: String...) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = repoPath
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process
    }

    private func runOutput(_ args: String...) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.currentDirectoryURL = repoPath
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd WritingHub && swift test --filter GitServiceTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add WritingHub/Sources/WritingHub/Services/GitService.swift WritingHub/Tests/
git commit -m "feat: add GitService for silent auto-commits"
```

---

## Task 6: Pipeline Sidebar View

**Files:**
- Create: `WritingHub/Sources/WritingHub/Views/PipelineSidebar.swift`
- Create: `WritingHub/Sources/WritingHub/ViewModels/HubViewModel.swift`

**Step 1: Create the shared ViewModel**

```swift
// HubViewModel.swift
import SwiftUI

@MainActor
class HubViewModel: ObservableObject {
    @Published var folderManager: FolderManager?
    @Published var selectedFile: WritingPiece?
    @Published var pieces: [PipelineStage: [WritingPiece]] = [:]
    @Published var isHubOpen: Bool = false

    private var fileWatcher: FileWatcher?
    private var gitService: GitService?

    func openFolder(_ url: URL) throws {
        let manager = FolderManager(root: url)
        try manager.scaffold()
        self.folderManager = manager

        gitService = GitService(repoPath: url)
        try gitService?.initRepo()

        fileWatcher = FileWatcher(path: url.path)
        fileWatcher?.onChange = { [weak self] in
            Task { @MainActor in
                self?.reload()
            }
        }
        fileWatcher?.start()

        reload()
        isHubOpen = true
    }

    func reload() {
        guard let manager = folderManager else { return }
        try? manager.loadAllPieces()
        pieces = manager.pieces
    }

    func promote(_ piece: WritingPiece, from stage: PipelineStage) {
        guard let fileName = piece.filePath?.lastPathComponent else { return }
        try? folderManager?.promote(fileName: fileName, from: stage)
        try? gitService?.autoCommit(message: "Promote \(fileName) to \(stage.next?.rawValue ?? "")")
        reload()
    }

    func savePiece(_ piece: WritingPiece) {
        guard let manager = folderManager, let path = piece.filePath else { return }
        fileWatcher?.markSelfWrite(path.path)
        try? manager.savePiece(piece)
        try? gitService?.autoCommit(message: "Update \(path.lastPathComponent)")
    }

    func pipelineCounts() -> [PipelineStage: Int] {
        var counts: [PipelineStage: Int] = [:]
        for stage in PipelineStage.allCases {
            counts[stage] = pieces[stage]?.count ?? 0
        }
        return counts
    }
}
```

**Step 2: Build the pipeline sidebar**

```swift
// PipelineSidebar.swift
import SwiftUI

struct PipelineSidebar: View {
    @ObservedObject var viewModel: HubViewModel

    var body: some View {
        List {
            ForEach(PipelineStage.allCases, id: \.self) { stage in
                Section(isExpanded: .constant(true)) {
                    let stagePieces = viewModel.pieces[stage] ?? []
                    if stagePieces.isEmpty {
                        Text("No files")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(stagePieces, id: \.filePath) { piece in
                            SidebarRow(piece: piece, isSelected: viewModel.selectedFile?.filePath == piece.filePath)
                                .onTapGesture {
                                    viewModel.selectedFile = piece
                                }
                                .contextMenu {
                                    if stage.next != nil {
                                        Button("Promote to \(stage.next!.displayName)") {
                                            viewModel.promote(piece, from: stage)
                                        }
                                    }
                                    Button("Show in Finder") {
                                        if let path = piece.filePath {
                                            NSWorkspace.shared.activateFileViewerSelecting([path])
                                        }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        if let path = piece.filePath {
                                            try? FileManager.default.removeItem(at: path)
                                            viewModel.reload()
                                        }
                                    }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text(stage.displayName)
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.pieces[stage]?.count ?? 0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

struct SidebarRow: View {
    let piece: WritingPiece
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(piece.frontMatter.title ?? piece.filePath?.lastPathComponent ?? "Untitled")
                .font(.body)
                .lineLimit(1)
            if let edited = piece.frontMatter.edited {
                Text(edited)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}
```

**Step 3: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds successfully.

**Step 4: Commit**

```bash
git add WritingHub/Sources/WritingHub/Views/ WritingHub/Sources/WritingHub/ViewModels/
git commit -m "feat: add pipeline sidebar with stage grouping and context menus"
```

---

## Task 7: WYSIWYG Markdown Editor Panel

**Files:**
- Create: `WritingHub/Sources/WritingHub/Views/EditorView.swift`

**Step 1: Create the editor view wrapping MarkupEditor**

```swift
// EditorView.swift
import SwiftUI
import MarkupEditor

struct EditorView: View {
    @ObservedObject var viewModel: HubViewModel
    @State private var editorContent: String = ""
    @State private var saveTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            if let piece = viewModel.selectedFile {
                // Title bar
                HStack {
                    Text(piece.frontMatter.title ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    if let version = piece.frontMatter.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let edited = piece.frontMatter.edited {
                        Text("Edited \(edited)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // WYSIWYG editor
                MarkupEditorView(
                    html: markdownToHTML(piece.body),
                    onContentChanged: { html in
                        debounceSave(html: html)
                    }
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a file from the sidebar")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func markdownToHTML(_ markdown: String) -> String {
        // Basic markdown to HTML conversion for MarkupEditor
        // In production, use a proper markdown parser (cmark or similar)
        markdown
    }

    private func debounceSave(html: String) {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            guard var piece = viewModel.selectedFile else { return }
            piece.body = htmlToMarkdown(html)
            viewModel.savePiece(piece)
        }
    }

    private func htmlToMarkdown(_ html: String) -> String {
        // Convert HTML back to markdown for disk storage
        // In production, use a proper converter
        html
    }
}
```

> **Note:** MarkupEditor works with HTML internally. The app converts markdown → HTML for display and HTML → markdown for saving. A production implementation needs a proper bidirectional converter (cmark-gfm or similar). This can be refined in a later task.

**Step 2: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds successfully.

**Step 3: Commit**

```bash
git add WritingHub/Sources/WritingHub/Views/EditorView.swift
git commit -m "feat: add WYSIWYG editor panel with MarkupEditor"
```

---

## Task 8: Embedded Claude Code Terminal

**Files:**
- Create: `WritingHub/Sources/WritingHub/Views/TerminalView.swift`

**Step 1: Create SwiftTerm wrapper for SwiftUI**

```swift
// TerminalView.swift
import SwiftUI
import SwiftTerm

struct TerminalPanelView: NSViewRepresentable {
    let folderPath: URL

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Style the terminal
        let fontSize: CGFloat = 13
        terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.nativeBackgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)

        // Start shell in the writing hub folder
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: [],
            environment: nil,
            execName: nil
        )

        // cd to the writing hub folder
        let cdCommand = "cd \"\(folderPath.path)\" && clear\n"
        terminalView.send(txt: cdCommand)

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No dynamic updates needed
    }
}
```

**Step 2: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds successfully.

**Step 3: Commit**

```bash
git add WritingHub/Sources/WritingHub/Views/TerminalView.swift
git commit -m "feat: add embedded terminal panel using SwiftTerm"
```

---

## Task 9: Main Layout — Three-Panel Window

**Files:**
- Modify: `WritingHub/Sources/WritingHub/ContentView.swift`

**Step 1: Assemble the three-panel layout**

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HubViewModel()
    @State private var showFolderPicker = false

    var body: some View {
        Group {
            if viewModel.isHubOpen {
                HSplitView {
                    // Left: Pipeline sidebar
                    PipelineSidebar(viewModel: viewModel)
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                    // Center: WYSIWYG editor
                    EditorView(viewModel: viewModel)
                        .frame(minWidth: 400)

                    // Right: Claude Code terminal
                    VStack(spacing: 0) {
                        HStack {
                            Text("Claude Code")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.bar)

                        if let root = viewModel.folderManager?.root {
                            TerminalPanelView(folderPath: root)
                        }
                    }
                    .frame(minWidth: 300, idealWidth: 380, maxWidth: 500)
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: { /* open settings */ }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            } else {
                WelcomeView(onOpenFolder: openFolder)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private func openFolder(_ url: URL) {
        try? viewModel.openFolder(url)
    }
}

struct WelcomeView: View {
    let onOpenFolder: (URL) -> Void
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Writing Hub")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose a folder to get started")
                .foregroundStyle(.secondary)

            Button("Open Folder") {
                showPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onOpenFolder(url)
            }
        }
    }
}
```

**Step 2: Build and verify it launches with three panels**

Run: `cd WritingHub && swift build && swift run`
Expected: App launches, shows welcome screen. Picking a folder shows three-panel layout.

**Step 3: Commit**

```bash
git add WritingHub/Sources/WritingHub/ContentView.swift
git commit -m "feat: assemble three-panel layout with welcome screen"
```

---

## Task 10: Status Bar

**Files:**
- Create: `WritingHub/Sources/WritingHub/Views/StatusBar.swift`
- Modify: `WritingHub/Sources/WritingHub/ContentView.swift`

**Step 1: Create the status bar**

```swift
// StatusBar.swift
import SwiftUI

struct StatusBar: View {
    @ObservedObject var viewModel: HubViewModel

    var body: some View {
        HStack(spacing: 16) {
            let counts = viewModel.pipelineCounts()

            Label("Pipeline:", systemImage: "arrow.right.square")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(PipelineStage.allCases, id: \.self) { stage in
                HStack(spacing: 4) {
                    Text("\(counts[stage] ?? 0)")
                        .fontWeight(.medium)
                    Text(stage.displayName.lowercased())
                }
                .font(.caption)

                if stage != .published {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Cadence indicator (placeholder — reads from config later)
            Label("Cadence: --", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
```

**Step 2: Add StatusBar to ContentView**

Add below the `HSplitView` closing brace, inside the `if viewModel.isHubOpen` block:

```swift
// In ContentView, wrap HSplitView + StatusBar in a VStack:
VStack(spacing: 0) {
    HSplitView {
        // ... existing three panels ...
    }
    StatusBar(viewModel: viewModel)
}
```

**Step 3: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds. Status bar appears at bottom of window.

**Step 4: Commit**

```bash
git add WritingHub/Sources/WritingHub/Views/StatusBar.swift WritingHub/Sources/WritingHub/ContentView.swift
git commit -m "feat: add pipeline status bar with counts"
```

---

## Task 11: CLAUDE.md Template with Agent Commands

**Files:**
- Create: `WritingHub/Sources/WritingHub/Resources/CLAUDE_TEMPLATE.md`
- Modify: `WritingHub/Sources/WritingHub/Services/FolderManager.swift` (replace placeholder CLAUDE.md)

**Step 1: Write the full CLAUDE.md template**

This is the product's brain. Create `Resources/CLAUDE_TEMPLATE.md`:

```markdown
# Writing Hub — Agent Instructions

You are a writing assistant operating inside a Writing Hub folder. Follow these instructions exactly.

## Folder Structure

```
├── CLAUDE.md          # This file (your instructions)
├── voice-dna.md       # User's writing voice profile — ALWAYS reference this
├── .writinghub/
│   └── config.json    # User preferences, platform list, cadence settings
├── references/        # User's past writing samples (for voice analysis)
├── ideas/             # Raw ideas, seed concepts
├── drafts/            # Work in progress
├── ready/             # Ready to publish
└── published/         # Archive of published pieces
```

## File Format

Every content file uses YAML frontmatter:

```yaml
---
title: [Title]
created: YYYY-MM-DD
edited: YYYY-MM-DD
version: [number]
stage: [ideas|drafts|ready|published]
platforms: [list of platforms]
---
```

When you create or modify any file, ALWAYS:
1. Preserve existing frontmatter
2. Update `edited` to today's date
3. Increment `version` if you rewrote content (not for minor edits)
4. Set `stage` to match the folder the file is in

## Voice DNA

ALWAYS read `voice-dna.md` before generating or editing ANY content. Match the user's voice exactly. If `voice-dna.md` doesn't exist yet, tell the user to run `/createvoicedna`.

## Anti-AI Writing Patterns (Humanizer Baseline)

Based on https://github.com/blader/humanizer — apply these checks to ALL output:

### Content Patterns to Avoid
- Significance inflation ("groundbreaking", "revolutionary", "game-changing")
- Vague name-dropping without specifics
- Unsupported superlatives

### Language Patterns to Avoid
- AI vocabulary: "delve", "tapestry", "landscape", "nuanced", "multifaceted", "testament", "underpinned", "leveraging", "robust", "comprehensive", "holistic"
- Copula avoidance (writing "proves challenging" instead of "is challenging")
- Excessive hedging ("it's worth noting that", "it's important to remember")
- Filler phrases: "in order to" (use "to"), "the fact that" (cut it), "it is worth mentioning" (just mention it)

### Style Patterns to Avoid
- Em-dash overuse (max 2 per piece)
- Emoji in professional writing
- Title Case In Every Heading
- Sycophantic tone ("Great question!", "I hope this helps!")
- Lists where prose would be better

### Final Check
After every generation, re-read your output and ask: "Does this sound like it was obviously written by AI?" If yes, rewrite.

---

## Commands

### /createvoicedna

1. Read ALL files in `references/`
2. Read `.writinghub/config.json` for existing preferences
3. Ask the user:
   - "What platforms do you publish on?" (Substack, X, LinkedIn, blog, etc.)
   - "Any writers or authors whose style you admire?"
   - "Anything specific you want to AVOID in your writing?"
4. Analyze the writing samples for:
   - Average sentence length and variation
   - Vocabulary patterns (frequent words, distinctive phrases)
   - Tone (formal/casual, personal/analytical, serious/playful)
   - Structure (how they open, transition, close)
   - Hook patterns (how they grab attention)
5. Generate `voice-dna.md` with sections: Core Voice, Vocabulary, Sentence Patterns, Influences, Anti-Patterns, Examples of Good Writing, Examples of Bad Writing
6. Save platform preferences to `.writinghub/config.json`
7. Show the user a summary and ask if anything needs adjusting

### /brainstorm [topic]

1. Read `voice-dna.md`
2. Generate 10 different angles/hooks for the topic
3. For each angle, include: a one-line hook, a 2-sentence description, and a suggested format (thread, essay, hot take, tutorial, story)
4. Save as a new file in `ideas/` with frontmatter (stage: ideas, today's date)
5. Show the user the list and ask which angles resonate

### /draft [file]

1. Read `voice-dna.md`
2. Read the specified file (should be in `ideas/`)
3. Write a complete first draft in the user's voice
4. Apply Humanizer anti-patterns check
5. Update the file content with the draft
6. Move the file from `ideas/` to `drafts/`
7. Update frontmatter: stage → drafts, version increment, edited date

### /edit [file]

1. Read `voice-dna.md`
2. Read the specified file
3. Tighten the prose:
   - Cut filler words and phrases
   - Vary sentence length
   - Strengthen verbs (no "is/was/were" where action verbs work)
   - Apply Humanizer anti-patterns
   - Ensure voice DNA match
4. Show the changes as a diff — tell the user exactly what you changed and why
5. Update frontmatter: version increment, edited date

### /critique [file]

1. Read the specified file
2. Attack the piece honestly:
   - Weak arguments — where is the logic thin?
   - Missing objections — what would a smart critic say?
   - Unsupported claims — where are the receipts?
   - Structural issues — does it flow? Is the hook strong enough?
   - Audience fit — will the target reader care?
3. Return a numbered list of specific issues. Do NOT rewrite anything.
4. For each issue, suggest a direction to fix it (but don't write the fix)

### /replicate [file]

1. Read `voice-dna.md`
2. Read `.writinghub/config.json` for the user's platform list
3. Read the specified file (should be in `ready/`)
4. For each configured platform, generate a section:
   - **X Thread**: Break into tweet-sized chunks (280 chars). Hook in first tweet. Number each tweet (1/, 2/, etc.). Max 10 tweets.
   - **LinkedIn**: Professional but human tone. Start with a hook. Use line breaks for readability. ~300-600 words.
   - **Substack Intro Hook**: First 2-3 paragraphs that make someone click "continue reading". Provocative, personal, specific.
5. Append each platform section to the file, separated by `---` and `## [Platform Name]`
6. Update frontmatter: platforms list, edited date
7. Apply Humanizer anti-patterns to each section

### /promote [file]

1. Read the specified file's frontmatter
2. Determine current stage
3. Move file to the next stage folder (ideas→drafts→ready→published)
4. Update frontmatter: stage, edited date
5. Confirm the move to the user

### /status

1. Count files in each stage folder
2. Read `.writinghub/config.json` for cadence target
3. Check `published/` for recent publish dates
4. Report:
   - Pipeline: X ideas → Y drafts → Z ready → W published
   - Cadence: on track / behind (based on target)
   - Stale drafts: files not edited in 7+ days
   - Suggestions: "You have 2 drafts ready. Consider running /edit or /promote."
```

**Step 2: Update FolderManager to use the template**

Replace the `defaultClaudeMD` static property in `FolderManager.swift` to read from the bundled template file, or inline the full template string. For simplicity, reference the file:

```swift
// In FolderManager.scaffold(), replace the CLAUDE.md write with:
let claudeMDPath = root.appendingPathComponent("CLAUDE.md")
if !fm.fileExists(atPath: claudeMDPath.path) {
    if let templateURL = Bundle.main.url(forResource: "CLAUDE_TEMPLATE", withExtension: "md"),
       let template = try? String(contentsOf: templateURL, encoding: .utf8) {
        try template.write(to: claudeMDPath, atomically: true, encoding: .utf8)
    }
}
```

**Step 3: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds. New folders get the full CLAUDE.md.

**Step 4: Commit**

```bash
git add WritingHub/Sources/WritingHub/Resources/ WritingHub/Sources/WritingHub/Services/FolderManager.swift
git commit -m "feat: add full CLAUDE.md template with all agent commands"
```

---

## Task 12: Onboarding Flow

**Files:**
- Modify: `WritingHub/Sources/WritingHub/Views/ContentView.swift` (enhance WelcomeView)

**Step 1: Enhance WelcomeView with onboarding steps**

```swift
struct WelcomeView: View {
    let onOpenFolder: (URL) -> Void
    @State private var showPicker = false
    @State private var step: OnboardingStep = .pickFolder

    enum OnboardingStep {
        case pickFolder
        case scaffolded(URL)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 64))
                .foregroundStyle(.accent)

            Text("Writing Hub")
                .font(.largeTitle)
                .fontWeight(.bold)

            switch step {
            case .pickFolder:
                Text("Choose a folder for your writing hub.\nPick an existing folder or create a new one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Choose Folder") {
                    showPicker = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .scaffolded(let url):
                VStack(spacing: 12) {
                    Label("Hub created at \(url.lastPathComponent)/", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text("Next steps:")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Drop past writing into references/", systemImage: "1.circle")
                        Label("Run /createvoicedna in the terminal", systemImage: "2.circle")
                        Label("Start writing!", systemImage: "3.circle")
                    }
                    .foregroundStyle(.secondary)
                }

                Button("Open Hub") {
                    onOpenFolder(url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let manager = FolderManager(root: url)
                try? manager.scaffold()
                step = .scaffolded(url)
            }
        }
    }
}
```

**Step 2: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds. Welcome screen shows two-step onboarding.

**Step 3: Commit**

```bash
git add WritingHub/Sources/WritingHub/Views/
git commit -m "feat: add onboarding flow with folder picker and next steps"
```

---

## Task 13: Publishing Action

**Files:**
- Create: `WritingHub/Sources/WritingHub/Services/PublishService.swift`
- Create: `WritingHub/Sources/WritingHub/Views/PublishSheet.swift`

**Step 1: Implement PublishService**

```swift
// PublishService.swift
import AppKit
import Foundation

struct PublishService {
    static let platformURLs: [String: String] = [
        "x": "https://twitter.com/compose/tweet",
        "linkedin": "https://www.linkedin.com/feed/?shareActive=true",
        "substack": "" // Substack has no compose URL — just copy
    ]

    static func publish(piece: WritingPiece, platform: String) {
        // Extract the platform section content
        guard let content = piece.platformSections[platform] ?? (platform == piece.frontMatter.platforms?.first ? piece.body : nil) else {
            return
        }

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        // Open platform compose page
        if let urlString = platformURLs[platform],
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Step 2: Create PublishSheet view**

```swift
// PublishSheet.swift
import SwiftUI

struct PublishSheet: View {
    let piece: WritingPiece
    let onPublish: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Publish to...")
                .font(.headline)

            let platforms = piece.frontMatter.platforms ?? []
            ForEach(platforms, id: \.self) { platform in
                Button(action: {
                    onPublish(platform)
                    dismiss()
                }) {
                    HStack {
                        Text(platformIcon(platform))
                        Text(platform.capitalized)
                        Spacer()
                        if piece.platformSections[platform] != nil {
                            Text("Ready")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("No section — will copy main body")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(.quaternary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            if platforms.isEmpty {
                Text("No platforms configured. Run /createvoicedna to set up platforms.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 400)
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "x": return "𝕏"
        case "linkedin": return "in"
        case "substack": return "✉️"
        default: return "📝"
        }
    }
}
```

**Step 3: Build and verify**

Run: `cd WritingHub && swift build`
Expected: Builds.

**Step 4: Commit**

```bash
git add WritingHub/Sources/WritingHub/Services/PublishService.swift WritingHub/Sources/WritingHub/Views/PublishSheet.swift
git commit -m "feat: add publish flow with clipboard copy and browser open"
```

---

## Summary: Build Order

| Task | Component | Depends On |
|------|-----------|-----------|
| 1 | Project scaffolding | — |
| 2 | Data models (frontmatter, WritingPiece) | 1 |
| 3 | FolderManager (scaffold, load, promote) | 2 |
| 4 | FileWatcher (FSEvents) | 1 |
| 5 | GitService (silent commits) | 1 |
| 6 | Pipeline sidebar view | 2, 3 |
| 7 | WYSIWYG editor panel | 2 |
| 8 | Claude Code terminal panel | 1 |
| 9 | Main layout (three panels) | 6, 7, 8 |
| 10 | Status bar | 6 |
| 11 | CLAUDE.md template | 3 |
| 12 | Onboarding flow | 3, 9 |
| 13 | Publishing action | 2, 9 |

**Parallelizable:** Tasks 2-5 can run in parallel (independent models/services). Tasks 6-8 can run in parallel (independent views). Tasks 10-13 can run in parallel after Task 9.
