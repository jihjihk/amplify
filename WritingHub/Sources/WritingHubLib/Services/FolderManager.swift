import Foundation
import Yams

public class FolderManager: ObservableObject {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    // MARK: - Scaffold

    /// Creates `.writinghub/`, skill folders, and a personalized CLAUDE.md.
    public func scaffold(skill: SkillPack = .founder, name: String = "you", useCase: String = "") throws {
        let fm = FileManager.default

        try fm.createDirectory(
            at: root.appendingPathComponent(".writinghub"),
            withIntermediateDirectories: true
        )

        for folder in skill.folders {
            try fm.createDirectory(
                at: root.appendingPathComponent(folder),
                withIntermediateDirectories: true
            )
        }

        let claudePath = root.appendingPathComponent("CLAUDE.md")
        try skill.claudeTemplate(name: name, useCase: useCase)
            .write(to: claudePath, atomically: true, encoding: .utf8)
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

    // MARK: - Workspace Files

    /// Directories to exclude from the workspace listing.
    private static let excludedNames: Set<String> = [
        ".git", ".writinghub", ".DS_Store",
    ]

    /// Scans the root directory and returns a tree of files and folders.
    public func loadWorkspaceFiles() -> [WorkspaceItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let filtered = contents
            .filter { !Self.excludedNames.contains($0.lastPathComponent) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        return filtered.compactMap { url in
            buildWorkspaceItem(at: url, fm: fm)
        }
    }

    private func buildWorkspaceItem(at url: URL, fm: FileManager) -> WorkspaceItem? {
        let name = url.lastPathComponent
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

        if isDir {
            let children: [WorkspaceItem]
            if let subContents = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                children = subContents
                    .filter { $0.lastPathComponent != ".DS_Store" }
                    .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
                    .compactMap { buildWorkspaceItem(at: $0, fm: fm) }
            } else {
                children = []
            }
            return WorkspaceItem(name: name, path: url, isDirectory: true, children: children)
        } else {
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
