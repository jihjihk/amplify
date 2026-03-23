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

    /// Stage the provided paths and commit them if there are staged changes.
    public func autoCommit(message: String, paths: [URL]) throws {
        let relativePaths = try paths.map(relativePath(for:))
        guard !relativePaths.isEmpty else { return }
        guard hasConfiguredUserIdentity() else {
            throw GitError.missingAuthorIdentity
        }

        try run(["add", "--"] + relativePaths)
        let status = try runOutput(["diff", "--cached", "--name-only", "--"] + relativePaths)
        guard !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return // nothing to commit
        }
        try run(["commit", "-m", message, "--"] + relativePaths)
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
        try run(args)
    }

    private func run(_ args: [String]) throws {
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
        try runOutput(args)
    }

    private func runOutput(_ args: [String]) throws -> String {
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

    private func hasConfiguredUserIdentity() -> Bool {
        let name = (try? runOutput("config", "user.name"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = (try? runOutput("config", "user.email"))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !name.isEmpty && !email.isEmpty
    }

    private func relativePath(for fileURL: URL) throws -> String {
        let repoRoot = repoPath.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        let prefix = repoRoot.hasSuffix("/") ? repoRoot : repoRoot + "/"
        guard filePath.hasPrefix(prefix) else {
            throw GitError.pathOutsideRepo(filePath)
        }
        return String(filePath.dropFirst(prefix.count))
    }
}

public enum GitError: Error, Sendable, LocalizedError {
    case commandFailed(args: [String], status: Int32)
    case missingAuthorIdentity
    case pathOutsideRepo(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let args, let status):
            return "Git command failed (\(status)): git \(args.joined(separator: " "))"
        case .missingAuthorIdentity:
            return "Autosave commit skipped because git user.name and user.email are not configured for this workspace."
        case .pathOutsideRepo(let path):
            return "Cannot commit a file outside the workspace repo: \(path)"
        }
    }
}
