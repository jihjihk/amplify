import Testing
import Foundation
@testable import WritingHubLib

@Suite("FileWatcher Tests")
struct FileWatcherTests {

    @Test("FileWatcher detects new file creation", .timeLimit(.minutes(1)))
    func testFileWatcherDetectsNewFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileWatcherTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let watcher = FileWatcher(path: tempDir.path)

        try await confirmation(expectedCount: 1) { confirmed in
            watcher.onChange = {
                confirmed()
            }
            watcher.start()

            // Write a file after a short delay so the watcher is running
            try await Task.sleep(for: .milliseconds(200))
            let filePath = tempDir.appendingPathComponent("test.md")
            try "hello".write(to: filePath, atomically: true, encoding: .utf8)

            // Wait enough time for FSEvents (500ms latency) + debounce (300ms) + margin
            try await Task.sleep(for: .seconds(3))
        }

        watcher.stop()
    }
}
