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

    // Cleanup helper — called manually at end of each test
    func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Test 1: scaffold creates all directories and CLAUDE.md

    @Test("scaffold creates all directories and CLAUDE.md")
    func testScaffoldCreatesAllDirectories() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("ideas").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("drafts").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("ready").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("published").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("references").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent(".writinghub").path))
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("CLAUDE.md").path))

        let claudeContent = try String(contentsOf: tempDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        #expect(claudeContent.contains("Writing Hub"))
    }

    // MARK: - Test 2: loadPieces reads markdown files from a stage folder

    @Test("loadPieces reads markdown files from ideas folder")
    func testLoadPiecesFromFolder() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        // Write a test markdown file into ideas/
        let mdContent = """
        ---
        title: Test Idea
        created: 2026-02-27
        stage: ideas
        ---

        Some idea content.
        """
        let filePath = tempDir.appendingPathComponent("ideas/test-idea.md")
        try mdContent.write(to: filePath, atomically: true, encoding: .utf8)

        let pieces = try manager.loadPieces(for: .ideas)
        #expect(pieces.count == 1)
        #expect(pieces.first?.frontMatter.title == "Test Idea")
    }

    // MARK: - Test 3: promote moves file and updates frontmatter

    @Test("promote moves file from ideas to drafts and updates frontmatter")
    func testPromoteMovesFile() throws {
        defer { cleanup() }

        let manager = FolderManager(root: tempDir)
        try manager.scaffold()

        // Write a file into ideas/
        let mdContent = """
        ---
        title: Promote Me
        created: 2026-02-27
        stage: ideas
        ---

        Content to promote.
        """
        let filePath = tempDir.appendingPathComponent("ideas/promote-me.md")
        try mdContent.write(to: filePath, atomically: true, encoding: .utf8)

        try manager.promote(fileName: "promote-me.md", from: .ideas)

        let fm = FileManager.default
        // Original should be gone
        #expect(!fm.fileExists(atPath: tempDir.appendingPathComponent("ideas/promote-me.md").path))
        // Should exist in drafts
        #expect(fm.fileExists(atPath: tempDir.appendingPathComponent("drafts/promote-me.md").path))

        // Read the promoted file and check frontmatter
        let promotedContent = try String(
            contentsOf: tempDir.appendingPathComponent("drafts/promote-me.md"),
            encoding: .utf8
        )
        let piece = try WritingPiece.parse(from: promotedContent)
        #expect(piece.frontMatter.stage == .drafts)
        #expect(piece.frontMatter.edited == FolderManager.todayString())
    }
}
