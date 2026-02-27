import Testing
import Foundation
@testable import WritingHubLib

@Suite("GitService Tests")
struct GitServiceTests {

    @Test("Init repo, write file, auto-commit, verify log")
    func testInitAndAutoCommit() throws {
        // Create a temp directory
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitServiceTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let git = GitService(repoPath: tmp)

        // Init repo
        try git.initRepo()

        // Configure git user for the temp repo so commits work
        try git.configureTestUser()

        // Write a test file
        let testFile = tmp.appendingPathComponent("hello.txt")
        try "Hello, world!".write(to: testFile, atomically: true, encoding: .utf8)

        // Auto-commit
        let commitMessage = "test: add hello file"
        try git.autoCommit(message: commitMessage)

        // Verify log contains the commit message
        let logOutput = try git.log(limit: 5)
        #expect(logOutput.contains(commitMessage))
    }
}
