import Foundation
import XCTest
@testable import WritingHubLib

@MainActor
final class MarkdownDocumentSessionTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritingHubSessionTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func testAutosavePreservesBlankLines() async throws {
        let tempDir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appendingPathComponent("draft.md")
        let original = """
        # Title

        First paragraph.
        """
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        let session = MarkdownDocumentSession(fileURL: fileURL, workspaceRoot: nil)
        try await Task.sleep(for: .milliseconds(200))

        let updated = """
        # Title

        First paragraph.


        Second paragraph after a deliberate blank line.
        """
        session.updateText(updated)
        try await Task.sleep(for: .milliseconds(1300))

        let disk = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(disk, updated)
        XCTAssertFalse(session.isDirty)
    }
}
