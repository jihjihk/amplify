import SwiftUI

// MARK: - PipelineSidebar

public struct PipelineSidebar: View {
    @ObservedObject var viewModel: HubViewModel

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedFile?.filePath },
            set: { url in
                viewModel.selectedFile = url.flatMap { selectedURL in
                    for (_, stagePieces) in viewModel.pieces {
                        if let match = stagePieces.first(where: { $0.filePath == selectedURL }) {
                            return match
                        }
                    }
                    return nil
                }
            }
        )) {
            ForEach(PipelineStage.allCases, id: \.self) { stage in
                Section {
                    let stagePieces = viewModel.pieces[stage] ?? []
                    if stagePieces.isEmpty {
                        Text("No files")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .italic()
                    } else {
                        ForEach(stagePieces, id: \.filePath) { piece in
                            SidebarRow(piece: piece)
                                .tag(piece.filePath)
                                .contextMenu {
                                    contextMenuItems(for: piece, stage: stage)
                                }
                        }
                    }
                } header: {
                    sectionHeader(stage: stage)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(stage: PipelineStage) -> some View {
        HStack {
            Text(stage.displayName)
                .font(.headline)
            Spacer()
            Text("\(viewModel.pieces[stage]?.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(.quaternary)
                )
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for piece: WritingPiece, stage: PipelineStage) -> some View {
        if let nextStage = stage.next {
            Button("Promote to \(nextStage.displayName)") {
                viewModel.promote(piece, from: stage)
            }
        }

        Button("Show in Finder") {
            if let filePath = piece.filePath {
                NSWorkspace.shared.activateFileViewerSelecting([filePath])
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            deletePiece(piece)
        }
    }

    // MARK: - Delete

    private func deletePiece(_ piece: WritingPiece) {
        guard let filePath = piece.filePath else { return }
        do {
            try FileManager.default.removeItem(at: filePath)
            viewModel.reload()
        } catch {
            print("[PipelineSidebar] delete error: \(error.localizedDescription)")
        }
    }
}

// MARK: - SidebarRow

public struct SidebarRow: View {
    public let piece: WritingPiece

    public init(piece: WritingPiece) {
        self.piece = piece
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayTitle)
                .font(.body)
                .lineLimit(1)
            if let edited = piece.frontMatter.edited {
                Text(edited)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var displayTitle: String {
        if let title = piece.frontMatter.title, !title.isEmpty {
            return title
        }
        return piece.filePath?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }
}
