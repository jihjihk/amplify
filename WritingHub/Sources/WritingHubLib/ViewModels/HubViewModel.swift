import Foundation
import SwiftUI

@MainActor
public class HubViewModel: ObservableObject {
    @Published public var folderManager: FolderManager?
    @Published public var selectedFile: WritingPiece?
    @Published public var pieces: [PipelineStage: [WritingPiece]] = [:]
    @Published public var isHubOpen: Bool = false

    private var fileWatcher: FileWatcher?
    private var gitService: GitService?

    public init() {}

    // MARK: - Open Folder

    /// Scaffold the folder structure, initialize git, start the file watcher, and load all pieces.
    public func openFolder(_ url: URL) throws {
        let manager = FolderManager(root: url)
        try manager.scaffold()
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

        reload()
        isHubOpen = true
    }

    // MARK: - Reload

    /// Reload all pieces from the folder manager and store them in the local pieces dictionary.
    public func reload() {
        guard let folderManager else { return }
        do {
            try folderManager.loadAllPieces()
            pieces = folderManager.pieces
        } catch {
            // In a production app we would surface this error to the user.
            print("[HubViewModel] reload error: \(error.localizedDescription)")
        }
    }

    // MARK: - Promote

    /// Promote a piece to the next pipeline stage and auto-commit the change.
    public func promote(_ piece: WritingPiece, from stage: PipelineStage) {
        guard let folderManager, let filePath = piece.filePath else { return }
        let fileName = filePath.lastPathComponent
        do {
            fileWatcher?.markSelfWrite(filePath.path)
            try folderManager.promote(fileName: fileName, from: stage)
            if let nextStage = stage.next {
                let destPath = folderManager.root
                    .appendingPathComponent(nextStage.folderName)
                    .appendingPathComponent(fileName)
                    .path
                fileWatcher?.markSelfWrite(destPath)
            }
            try gitService?.autoCommit(
                message: "Promote \(fileName) from \(stage.rawValue) to \(stage.next?.rawValue ?? "?")"
            )
            reload()
        } catch {
            print("[HubViewModel] promote error: \(error.localizedDescription)")
        }
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

    // MARK: - Pipeline Counts

    /// Returns the count of pieces per stage.
    public func pipelineCounts() -> [PipelineStage: Int] {
        pieces.mapValues { $0.count }
    }
}
