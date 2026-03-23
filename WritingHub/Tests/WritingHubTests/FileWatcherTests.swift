import Foundation
import XCTest
@testable import WritingHubLib

final class FileWatcherTests: XCTestCase {
    func testFileWatcherDetectsNewFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileWatcherTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let watcher = FileWatcher(path: tempDir.path)
        let expectation = expectation(description: "file watcher change")

        watcher.onChange = {
            expectation.fulfill()
        }
        watcher.start()

        try await Task.sleep(for: .milliseconds(200))
        let filePath = tempDir.appendingPathComponent("test.md")
        try "hello".write(to: filePath, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 5.0)
        watcher.stop()
    }
}
