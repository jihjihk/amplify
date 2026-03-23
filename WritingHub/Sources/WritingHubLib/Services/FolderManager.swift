import Foundation
import Yams

public struct WorkspaceLoadLimit: Sendable {
    public let maxEntries: Int
    public let maxDepth: Int

    public init(maxEntries: Int = 2500, maxDepth: Int = 12) {
        self.maxEntries = maxEntries
        self.maxDepth = maxDepth
    }

    public static let `default` = WorkspaceLoadLimit()
}

public struct WorkspaceSnapshot: Sendable {
    public let items: [WorkspaceItem]
    public let fileCount: Int
    public let folderCount: Int
    public let wasLimited: Bool
    public let limit: WorkspaceLoadLimit

    public var warningMessage: String? {
        guard wasLimited else { return nil }
        return "Large workspace detected. Showing the first \(limit.maxEntries) files and folders."
    }
}

public struct WorkspaceSearchLimit: Sendable {
    public let maxFilesToScan: Int
    public let maxResults: Int
    public let maxFileSizeBytes: Int

    public init(maxFilesToScan: Int = 1500, maxResults: Int = 100, maxFileSizeBytes: Int = 262_144) {
        self.maxFilesToScan = maxFilesToScan
        self.maxResults = maxResults
        self.maxFileSizeBytes = maxFileSizeBytes
    }

    public static let `default` = WorkspaceSearchLimit()
}

public struct WorkspaceSearchMatch: Sendable {
    public let fileURL: URL
    public let fileName: String
    public let lineNumber: Int
    public let lineText: String
}

public struct WorkspaceSearchSnapshot: Sendable {
    public let matches: [WorkspaceSearchMatch]
    public let filesScanned: Int
    public let wasLimited: Bool
    public let limit: WorkspaceSearchLimit

    public var warningMessage: String? {
        guard wasLimited else { return nil }
        return "Search limited to the first \(limit.maxFilesToScan) files and \(limit.maxResults) matches."
    }
}

public class FolderManager: ObservableObject {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    // MARK: - Scaffold

    /// Creates `.writinghub/`, optionally skill folders, and a personalized CLAUDE.md.
    public func scaffold(skill: SkillPack = .founder, name: String = "you", useCase: String = "", createFolders: Bool = true) throws {
        let fm = FileManager.default

        try fm.createDirectory(
            at: root.appendingPathComponent(".writinghub"),
            withIntermediateDirectories: true
        )

        if createFolders {
            for folder in skill.folders {
                try fm.createDirectory(
                    at: root.appendingPathComponent(folder),
                    withIntermediateDirectories: true
                )
            }
        }

        let claudePath = root.appendingPathComponent("CLAUDE.md")
        try skill.claudeTemplate(name: name, useCase: useCase)
            .write(to: claudePath, atomically: true, encoding: .utf8)

        if skill == .gstack {
            Self.installGstack()
        }
    }

    /// Runs `claude install-skill garrytan/gstack` in the background.
    /// Fails silently if `claude` CLI is not on PATH.
    private static func installGstack() {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "claude install-skill garrytan/gstack"]
            process.standardOutput = nil
            process.standardError = nil
            try? process.run()
        }
    }

    // MARK: - Save Piece

    /// Saves a WritingPiece to disk, updating the edited date.
    public func savePiece(_ piece: WritingPiece) throws {
        guard let filePath = piece.filePath else {
            throw FolderManagerError.noFilePath
        }

        var updated = piece
        updated.frontMatter.edited = Self.todayString()

        let serialized = updated.serialize()
        try serialized.write(to: filePath, atomically: true, encoding: .utf8)
    }

    /// Saves raw markdown content while preserving body formatting and blank lines.
    /// If an `edited:` field already exists in frontmatter, only that line is updated.
    @discardableResult
    public func saveMarkdownDocument(_ text: String, to filePath: URL) throws -> String {
        let updated = Self.updatingEditedDate(in: text, to: Self.todayString())
        try updated.write(to: filePath, atomically: true, encoding: .utf8)
        return updated
    }

    // MARK: - Workspace Files

    /// Directories to exclude from the workspace listing.
    private static let excludedNames: Set<String> = [
        ".git", ".writinghub", ".DS_Store",
    ]

    /// Scans the root directory and returns a tree of files and folders.
    public func loadWorkspaceFiles() -> [WorkspaceItem] {
        loadWorkspaceSnapshot().items
    }

    public func loadWorkspaceSnapshot(limit: WorkspaceLoadLimit = .default) -> WorkspaceSnapshot {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return WorkspaceSnapshot(items: [], fileCount: 0, folderCount: 0, wasLimited: false, limit: limit)
        }

        let filtered = contents
            .filter { !Self.excludedNames.contains($0.lastPathComponent) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var state = WorkspaceScanState()
        let items = filtered.compactMap { url in
            buildWorkspaceItem(at: url, fm: fm, depth: 0, state: &state, limit: limit)
        }

        return WorkspaceSnapshot(
            items: items,
            fileCount: state.fileCount,
            folderCount: state.folderCount,
            wasLimited: state.wasLimited,
            limit: limit
        )
    }

    public func searchWorkspace(query: String, limit: WorkspaceSearchLimit = .default) -> WorkspaceSearchSnapshot {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return WorkspaceSearchSnapshot(matches: [], filesScanned: 0, wasLimited: false, limit: limit)
        }

        let fm = FileManager.default
        let excluded: Set<String> = [".git", ".writinghub", ".DS_Store", ".build"]
        var matches: [WorkspaceSearchMatch] = []
        var filesScanned = 0
        var wasLimited = false

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return WorkspaceSearchSnapshot(matches: [], filesScanned: 0, wasLimited: false, limit: limit)
        }

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if excluded.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                continue
            }

            if filesScanned >= limit.maxFilesToScan {
                wasLimited = true
                break
            }

            if let fileSize = values?.fileSize, fileSize > limit.maxFileSizeBytes {
                continue
            }

            filesScanned += 1

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            let relativeName = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            for (index, line) in content.components(separatedBy: .newlines).enumerated() {
                if line.lowercased().contains(normalizedQuery) {
                    matches.append(
                        WorkspaceSearchMatch(
                            fileURL: fileURL,
                            fileName: relativeName,
                            lineNumber: index + 1,
                            lineText: line.trimmingCharacters(in: .whitespaces)
                        )
                    )
                }
                if matches.count >= limit.maxResults {
                    wasLimited = true
                    return WorkspaceSearchSnapshot(matches: matches, filesScanned: filesScanned, wasLimited: wasLimited, limit: limit)
                }
            }
        }

        return WorkspaceSearchSnapshot(matches: matches, filesScanned: filesScanned, wasLimited: wasLimited, limit: limit)
    }

    private func buildWorkspaceItem(
        at url: URL,
        fm: FileManager,
        depth: Int,
        state: inout WorkspaceScanState,
        limit: WorkspaceLoadLimit
    ) -> WorkspaceItem? {
        guard depth <= limit.maxDepth else {
            state.wasLimited = true
            return nil
        }
        guard state.entryCount < limit.maxEntries else {
            state.wasLimited = true
            return nil
        }

        let name = url.lastPathComponent
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        state.entryCount += 1

        if isDir {
            state.folderCount += 1
            let children: [WorkspaceItem]
            if state.wasLimited {
                children = []
            } else if let subContents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                children = subContents
                    .filter { $0.lastPathComponent != ".DS_Store" }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                    .compactMap { buildWorkspaceItem(at: $0, fm: fm, depth: depth + 1, state: &state, limit: limit) }
            } else {
                children = []
            }
            return WorkspaceItem(name: name, path: url, isDirectory: true, children: children)
        } else {
            state.fileCount += 1
            return WorkspaceItem(name: name, path: url, isDirectory: false)
        }
    }

    // MARK: - Helpers

    /// Returns today's date as "yyyy-MM-dd".
    public static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    static func updatingEditedDate(in content: String, to date: String) -> String {
        let newline = content.contains("\r\n") ? "\r\n" : "\n"
        let lines = content.components(separatedBy: newline)
        guard lines.first == "---",
              let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else {
            return content
        }

        var frontMatterLines = Array(lines[1..<closingIndex])
        guard let editedIndex = frontMatterLines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("edited:")
        }) else {
            return content
        }

        let leadingWhitespace = frontMatterLines[editedIndex].prefix(while: { $0 == " " || $0 == "\t" })
        frontMatterLines[editedIndex] = "\(leadingWhitespace)edited: \(date)"

        return ([lines[0]] + frontMatterLines + Array(lines[closingIndex...])).joined(separator: newline)
    }

    private struct WorkspaceScanState {
        var entryCount = 0
        var fileCount = 0
        var folderCount = 0
        var wasLimited = false
    }
}

// MARK: - Errors

public enum FolderManagerError: Error, LocalizedError {
    case fileNotFound(String)
    case noFilePath

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .noFilePath:
            return "WritingPiece has no file path set."
        }
    }
}
