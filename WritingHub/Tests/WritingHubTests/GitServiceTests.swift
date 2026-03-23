import Foundation
import XCTest
@testable import WritingHubLib

final class GitServiceTests: XCTestCase {
    func testInitAndAutoCommit() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitServiceTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let git = GitService(repoPath: tmp)
        try git.initRepo()
        try git.configureTestUser()

        let testFile = tmp.appendingPathComponent("hello.txt")
        try "Hello, world!".write(to: testFile, atomically: true, encoding: .utf8)

        let commitMessage = "test: add hello file"
        try git.autoCommit(message: commitMessage, paths: [testFile])

        let logOutput = try git.log(limit: 5)
        XCTAssertTrue(logOutput.contains(commitMessage))
    }
}
