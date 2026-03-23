import Foundation
import XCTest
@testable import WritingHubLib

final class FolderManagerTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritingHubTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func testScaffoldCreatesBaseStructure() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".writinghub").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("CLAUDE.md").path))

        let claudeContent = try String(contentsOf: tempDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        XCTAssertTrue(claudeContent.contains("Amplify"))
    }

    func testScaffoldFounderFolders() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("ideas").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("drafts").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("published").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("references").path))
    }

    func testScaffoldBlankNoFolders() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .blank)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".writinghub").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("CLAUDE.md").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("ideas").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("drafts").path))
    }

    func testLoadWorkspaceFiles() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder)

        let filePath = tempDir.appendingPathComponent("drafts/test.md")
        try "# Test".write(to: filePath, atomically: true, encoding: .utf8)

        let files = manager.loadWorkspaceFiles()
        XCTAssertFalse(files.isEmpty)
        XCTAssertNotNil(files.first(where: { $0.name == "CLAUDE.md" }))
    }

    func testScaffoldEmbedsMeta() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder, name: "Ji", useCase: "Founder building audience")

        let content = try String(contentsOf: tempDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        XCTAssertTrue(content.contains("Ji"))
        XCTAssertTrue(content.contains("Founder building audience"))
    }

    func testSavePiece() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        let filePath = tempDir.appendingPathComponent("drafts/save-test.md")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("drafts"),
            withIntermediateDirectories: true
        )

        let piece = WritingPiece(
            frontMatter: FrontMatter(title: "Save Test", created: "2026-03-01"),
            body: "Test body content.",
            filePath: filePath
        )
        try manager.savePiece(piece)

        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
        let content = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertTrue(content.contains("Save Test"))
        XCTAssertTrue(content.contains("Test body content."))
    }

    func testSaveMarkdownDocumentPreservesFormatting() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        let filePath = tempDir.appendingPathComponent("drafts/formatting.md")
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent("drafts"),
            withIntermediateDirectories: true
        )

        let original = """
        ---
        title: Formatting
        edited: 2026-03-01
        ---

        First paragraph.

        - bullet one
        - bullet two

        Second paragraph.

        """

        let saved = try manager.saveMarkdownDocument(original, to: filePath)

        XCTAssertTrue(saved.contains("First paragraph.\n\n- bullet one\n- bullet two\n\nSecond paragraph."))
        XCTAssertTrue(saved.hasSuffix("\n"))
        XCTAssertEqual(try String(contentsOf: filePath, encoding: .utf8), saved)
    }

    func testLoadWorkspaceSnapshotLimit() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder)

        for index in 0..<10 {
            let file = tempDir.appendingPathComponent("drafts/file-\(index).md")
            try "test".write(to: file, atomically: true, encoding: .utf8)
        }

        let snapshot = manager.loadWorkspaceSnapshot(limit: WorkspaceLoadLimit(maxEntries: 5, maxDepth: 12))

        XCTAssertTrue(snapshot.wasLimited)
        XCTAssertNotNil(snapshot.warningMessage)
        XCTAssertLessThanOrEqual(snapshot.fileCount + snapshot.folderCount, 5)
    }

    func testSearchWorkspaceLimit() throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold(skill: .founder)

        for index in 0..<6 {
            let file = tempDir.appendingPathComponent("drafts/search-\(index).md")
            try "needle \(index)".write(to: file, atomically: true, encoding: .utf8)
        }

        let snapshot = manager.searchWorkspace(
            query: "needle",
            limit: WorkspaceSearchLimit(maxFilesToScan: 3, maxResults: 20, maxFileSizeBytes: 1024)
        )

        XCTAssertTrue(snapshot.wasLimited)
        XCTAssertNotNil(snapshot.warningMessage)
        XCTAssertEqual(snapshot.filesScanned, 3)
        XCTAssertLessThanOrEqual(snapshot.matches.count, 3)
    }
}
