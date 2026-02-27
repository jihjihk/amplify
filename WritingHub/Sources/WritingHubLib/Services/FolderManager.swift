import Foundation
import Yams

public class FolderManager: ObservableObject {
    public let root: URL
    @Published public var pieces: [PipelineStage: [WritingPiece]] = [:]

    public init(root: URL) {
        self.root = root
    }

    // MARK: - Scaffold

    /// Creates all stage directories, references/, .writinghub/, and a placeholder CLAUDE.md.
    public func scaffold() throws {
        let fm = FileManager.default

        // Create stage directories
        for stage in PipelineStage.allCases {
            let dir = root.appendingPathComponent(stage.folderName)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Create references/
        try fm.createDirectory(
            at: root.appendingPathComponent("references"),
            withIntermediateDirectories: true
        )

        // Create .writinghub/
        try fm.createDirectory(
            at: root.appendingPathComponent(".writinghub"),
            withIntermediateDirectories: true
        )

        // Create CLAUDE.md placeholder
        let claudePath = root.appendingPathComponent("CLAUDE.md")
        if !fm.fileExists(atPath: claudePath.path) {
            let placeholder = "# Writing Hub\n\nSee the full CLAUDE.md template for instructions.\n"
            try placeholder.write(to: claudePath, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Load Pieces

    /// Loads all WritingPiece files from the given stage's folder.
    public func loadPieces(for stage: PipelineStage) throws -> [WritingPiece] {
        let fm = FileManager.default
        let stageDir = root.appendingPathComponent(stage.folderName)

        guard fm.fileExists(atPath: stageDir.path) else {
            return []
        }

        let contents = try fm.contentsOfDirectory(
            at: stageDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let markdownFiles = contents.filter { $0.pathExtension == "md" }

        return try markdownFiles.map { fileURL in
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            var piece = try WritingPiece.parse(from: content)
            piece.filePath = fileURL
            return piece
        }
    }

    /// Loads pieces from all stages and populates the pieces dictionary.
    public func loadAllPieces() throws {
        var allPieces: [PipelineStage: [WritingPiece]] = [:]
        for stage in PipelineStage.allCases {
            allPieces[stage] = try loadPieces(for: stage)
        }
        pieces = allPieces
    }

    // MARK: - Promote

    /// Moves a file from one stage folder to the next and updates frontmatter.
    public func promote(fileName: String, from stage: PipelineStage) throws {
        guard let nextStage = stage.next else {
            throw FolderManagerError.noNextStage(stage)
        }

        let sourceURL = root
            .appendingPathComponent(stage.folderName)
            .appendingPathComponent(fileName)
        let destURL = root
            .appendingPathComponent(nextStage.folderName)
            .appendingPathComponent(fileName)

        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceURL.path) else {
            throw FolderManagerError.fileNotFound(sourceURL.path)
        }

        // Read, update frontmatter, write to new location, remove old
        let content = try String(contentsOf: sourceURL, encoding: .utf8)
        var piece = try WritingPiece.parse(from: content)
        piece.frontMatter.stage = nextStage
        piece.frontMatter.edited = Self.todayString()
        piece.filePath = destURL

        let serialized = piece.serialize()
        try serialized.write(to: destURL, atomically: true, encoding: .utf8)
        try fm.removeItem(at: sourceURL)
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
    case noNextStage(PipelineStage)
    case fileNotFound(String)
    case noFilePath

    public var errorDescription: String? {
        switch self {
        case .noNextStage(let stage):
            return "Cannot promote from '\(stage.rawValue)' — it is the final stage."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .noFilePath:
            return "WritingPiece has no file path set."
        }
    }
}
