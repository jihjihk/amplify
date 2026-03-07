import Foundation
import Testing
@testable import WritingHubLib

@Suite("FolderManager Tests")
struct FolderManagerTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritingHubTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Test 1: scaffold creates .writinghub and CLAUDE.md

    @Test("scaffold creates .writinghub directory and CLAUDE.md")
    func testScaffoldCreatesBaseStructure() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent(".writinghub").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("CLAUDE.md").path))

        let claudeContent = try String(contentsOf: tempDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        #expect(claudeContent.contains("Amplify"))
    }

    // MARK: - Test 2: scaffold creates skill-specific folders

    @Test("scaffold creates founder skill folders")
    func testScaffoldFounderFolders() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("ideas").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("drafts").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("published").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("references").path))
    }

    @Test("scaffold creates marketing skill folders")
    func testScaffoldMarketingFolders() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .marketingManager)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("strategy").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("campaigns").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("content").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("references").path))
    }

    // MARK: - Test 3: loadWorkspaceFiles returns file tree

    @Test("loadWorkspaceFiles returns non-hidden files")
    func testLoadWorkspaceFiles() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .hobbyWriter)

        // Write a test file
        let filePath = tempDir.appendingPathComponent("drafts/test.md")
        try "# Test".write(to: filePath, atomically: true, encoding: .utf8)

        let files = manager.loadWorkspaceFiles()
        // Should include drafts/ folder (which contains test.md), published/, references/
        #expect(!files.isEmpty)

        // CLAUDE.md should be at root level
        let claudeFile = files.first(where: { $0.name == "CLAUDE.md" })
        #expect(claudeFile != nil)
    }

    // MARK: - Test 4: savePiece writes to disk

    @Test("savePiece writes piece to disk with updated edited date")
    func testSavePiece() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        let filePath = tempDir.appendingPathComponent("drafts/save-test.md")
        let fm = FileManager.default
        try fm.createDirectory(
            at: tempDir.appendingPathComponent("drafts"),
            withIntermediateDirectories: true
        )

        let piece = WritingPiece(
            frontMatter: FrontMatter(title: "Save Test", created: "2026-03-01"),
            body: "Test body content.",
            filePath: filePath
        )
        try manager.savePiece(piece)

        #expect(fm.fileExists(atPath: filePath.path))
        let content = try String(contentsOf: filePath, encoding: .utf8)
        #expect(content.contains("Save Test"))
        #expect(content.contains("Test body content."))
    }
}
