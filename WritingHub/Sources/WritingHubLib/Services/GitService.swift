import Foundation

public final class GitService: Sendable {
    public let repoPath: URL

    public init(repoPath: URL) {
        self.repoPath = repoPath
    }

    /// Initialize a git repo at repoPath. Skips if .git already exists.
    public func initRepo() throws {
        let dotGit = repoPath.appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: dotGit.path) {
            return
        }
        try run("init")
    }

    /// Stage all changes, check for modifications, and commit if there are any.
    public func autoCommit(message: String) throws {
        try run("add", "-A")
        let status = try runOutput("status", "--porcelain")
        guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return // nothing to commit
        }
        try run("commit", "-m", message)
    }

    /// Return the git log as oneline, limited to `limit` entries.
    public func log(limit: Int) throws -> String {
        try runOutput("log", "--oneline", "-\(limit)")
    }

    /// Configure a test user.name and user.email locally for this repo.
    public func configureTestUser() throws {
        try run("config", "user.name", "Test User")
        try run("config", "user.email", "test@example.com")
    }

    // MARK: - Private helpers

    /// Run a git command silently (stdout/stderr to null).
    private func run(_ args: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = repoPath
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed(args: args, status: process.terminationStatus)
        }
    }

    /// Run a git command and capture stdout.
    private func runOutput(_ args: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = repoPath
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitError.commandFailed(args: args, status: process.terminationStatus)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public enum GitError: Error, Sendable {
    case commandFailed(args: [String], status: Int32)
}
