import Combine
import Foundation
import SwiftUI

@MainActor
public class HubViewModel: ObservableObject {
    @Published public var folderManager: FolderManager?
    @Published public var selectedFile: WritingPiece?
    @Published public var workspaceFiles: [WorkspaceItem] = []
    @Published public var isHubOpen: Bool = false
    @Published public var config: HubConfig = HubConfig()
    @Published public var skillPack: SkillPack = .founder

    private var fileWatcher: FileWatcher?
    private var gitService: GitService?
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    // MARK: - Open Folder

    /// Scaffold the folder structure, initialize git, start the file watcher, and load files.
    public func openFolder(_ url: URL, skill: SkillPack = .founder) throws {
        self.skillPack = skill

        let manager = FolderManager(root: url)
        try manager.scaffold(skill: skill)
        self.folderManager = manager

        let git = GitService(repoPath: url)
        try git.initRepo()
        self.gitService = git

        let watcher = FileWatcher(path: url.path)
        watcher.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
        watcher.start()
        self.fileWatcher = watcher

        // Write .writinghub/context.md whenever the selected file changes
        $selectedFile
            .sink { [weak self] piece in
                self?.writeContextFile(for: piece)
            }
            .store(in: &cancellables)

        // Load config — restores name and skill pack for existing workspaces
        if let saved = HubConfig.load(from: url) {
            config = saved
            self.skillPack = saved.skillPack
        }

        reload()
        isHubOpen = true
    }

    // MARK: - Reload

    /// Reload workspace files from disk. Refreshes selectedFile if content changed.
    public func reload() {
        guard let folderManager else { return }

        // Refresh selectedFile from disk if it still exists
        if let currentPath = selectedFile?.filePath {
            if FileManager.default.fileExists(atPath: currentPath.path) {
                if let content = try? String(contentsOf: currentPath, encoding: .utf8),
                   var freshPiece = try? WritingPiece.parse(from: content) {
                    freshPiece.filePath = currentPath
                    selectedFile = freshPiece
                }
            } else {
                selectedFile = nil
            }
        }

        workspaceFiles = folderManager.loadWorkspaceFiles()
        objectWillChange.send()
    }

    // MARK: - Save Piece

    /// Save a piece to disk, mark the write so the watcher ignores it, and auto-commit.
    public func savePiece(_ piece: WritingPiece) {
        guard let folderManager else { return }
        do {
            if let path = piece.filePath?.path {
                fileWatcher?.markSelfWrite(path)
            }
            try folderManager.savePiece(piece)
            try gitService?.autoCommit(
                message: "Update \(piece.filePath?.lastPathComponent ?? "piece")"
            )
            reload()
        } catch {
            print("[HubViewModel] save error: \(error.localizedDescription)")
        }
    }

    // MARK: - File Count

    /// Returns total count of files in workspace.
    public func fileCount() -> Int {
        countFiles(in: workspaceFiles)
    }

    private func countFiles(in items: [WorkspaceItem]) -> Int {
        items.reduce(0) { count, item in
            if item.isDirectory {
                return count + countFiles(in: item.children)
            }
            return count + 1
        }
    }

    // MARK: - Context File

    /// Writes `.writinghub/context.md` so Claude Code knows which file is currently open.
    private func writeContextFile(for piece: WritingPiece?) {
        guard let folderManager else { return }
        let contextURL = folderManager.root
            .appendingPathComponent(".writinghub")
            .appendingPathComponent("context.md")

        fileWatcher?.markSelfWrite(contextURL.path)

        if let piece, let filePath = piece.filePath {
            let relativePath = filePath.path
                .replacingOccurrences(of: folderManager.root.path + "/", with: "")
            let title = piece.frontMatter.title ?? filePath.deletingPathExtension().lastPathComponent
            let content = """
                # Active File
                - path: \(relativePath)
                - title: \(title)
                """
            try? content.write(to: contextURL, atomically: true, encoding: .utf8)
        } else {
            try? "".write(to: contextURL, atomically: true, encoding: .utf8)
        }
    }
}
