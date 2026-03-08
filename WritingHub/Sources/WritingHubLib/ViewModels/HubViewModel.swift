import Combine
import Foundation
import SwiftUI

public struct FileClipboard: Sendable {
    public let url: URL
    public let isCut: Bool
}

@MainActor
public class HubViewModel: ObservableObject {
    @Published public var folderManager: FolderManager?
    @Published public var openTabs: [WritingPiece] = []
    @Published public var activeTabIndex: Int = 0
    @Published public var dirtyTabPaths: Set<URL> = []
    @Published public var workspaceFiles: [WorkspaceItem] = []
    @Published public var isHubOpen: Bool = false
    @Published public var config: HubConfig = HubConfig()
    @Published public var skillPack: SkillPack = .founder
    @Published public var fileClipboard: FileClipboard? = nil

    public var selectedFile: WritingPiece? {
        get { openTabs.indices.contains(activeTabIndex) ? openTabs[activeTabIndex] : nil }
        set {
            if let newValue { openTab(newValue) }
        }
    }

    private var fileWatcher: FileWatcher?
    private var gitService: GitService?
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    // MARK: - Open Folder

    /// Scaffold the folder structure, initialize git, start the file watcher, and load files.
    public func openFolder(_ url: URL, skill: SkillPack = .founder, name: String = "you", useCase: String = "") throws {
        self.skillPack = skill

        let manager = FolderManager(root: url)
        let writinghubDir = url.appendingPathComponent(".writinghub")
        if !FileManager.default.fileExists(atPath: writinghubDir.path) {
            try manager.scaffold(skill: skill, name: name, useCase: useCase)
        } else {
            // Always keep CLAUDE.md up to date with current name/useCase
            let claudePath = url.appendingPathComponent("CLAUDE.md")
            try skill.claudeTemplate(name: name, useCase: useCase)
                .write(to: claudePath, atomically: true, encoding: .utf8)
        }
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
        Publishers.CombineLatest($openTabs, $activeTabIndex)
            .map { tabs, idx in tabs.indices.contains(idx) ? tabs[idx] : nil }
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

    // MARK: - Tab Management

    public func openTab(_ piece: WritingPiece) {
        if let idx = openTabs.firstIndex(where: { $0.filePath == piece.filePath }) {
            activeTabIndex = idx
        } else {
            openTabs.append(piece)
            activeTabIndex = openTabs.count - 1
        }
        objectWillChange.send()
    }

    public func closeTab(at index: Int) {
        guard openTabs.indices.contains(index) else { return }
        openTabs.remove(at: index)
        activeTabIndex = openTabs.isEmpty ? 0 : min(activeTabIndex, openTabs.count - 1)
        objectWillChange.send()
    }

    public func closeActiveTab() {
        closeTab(at: activeTabIndex)
    }

    // MARK: - Reload

    /// Reload workspace files from disk. Refreshes open tabs if content changed.
    public func reload() {
        guard let folderManager else { return }

        // Refresh each open tab from disk
        openTabs = openTabs.compactMap { tab in
            guard let path = tab.filePath else { return tab }
            guard FileManager.default.fileExists(atPath: path.path) else { return nil }
            if let content = try? String(contentsOf: path, encoding: .utf8),
               var fresh = try? WritingPiece.parse(from: content) {
                fresh.filePath = path
                return fresh
            }
            return tab
        }
        if !openTabs.isEmpty {
            activeTabIndex = min(activeTabIndex, openTabs.count - 1)
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
            if let path = piece.filePath {
                dirtyTabPaths.remove(path)
            }
            try gitService?.autoCommit(
                message: "Update \(piece.filePath?.lastPathComponent ?? "piece")"
            )
            reload()
        } catch {
            print("[HubViewModel] save error: \(error.localizedDescription)")
        }
    }

    // MARK: - File Clipboard

    public func copyFile(_ url: URL) {
        fileClipboard = FileClipboard(url: url, isCut: false)
    }

    public func cutFile(_ url: URL) {
        fileClipboard = FileClipboard(url: url, isCut: true)
    }

    public func pasteFile(into folderURL: URL) {
        guard let clip = fileClipboard else { return }
        let dest = folderURL.appendingPathComponent(clip.url.lastPathComponent)
        guard clip.url != dest else { return }
        do {
            if clip.isCut {
                try FileManager.default.moveItem(at: clip.url, to: dest)
                fileClipboard = nil
            } else {
                try FileManager.default.copyItem(at: clip.url, to: dest)
            }
            reload()
        } catch {
            print("[HubViewModel] paste error: \(error.localizedDescription)")
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
