import SwiftUI
import Combine

private struct EditorSaveRequest: Sendable {
    let fileURL: URL
    let text: String
    let baseText: String
}

/// A markdown editor that preserves the exact file formatting on disk.
public struct EditorView: View {
    @ObservedObject var viewModel: HubViewModel

    @State private var draftText: String = ""
    @State private var loadedFileURL: URL?
    @State private var loadedDiskText: String = ""
    @State private var saveSubject = PassthroughSubject<EditorSaveRequest, Never>()
    @State private var saveCancellable: AnyCancellable?
    @State private var isProgrammaticChange = false
    @State private var editorNotice: String?

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                if let piece = viewModel.selectedFile {
                    titleBar(for: piece)
                    Divider().overlay(AmplifyColors.barBg.opacity(0.5))
                }

                if let editorNotice, loadedFileURL != nil {
                    noticeBar(editorNotice)
                }

                if viewModel.selectedFile != nil {
                    TextEditor(text: $draftText)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(AmplifyColors.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AmplifyColors.surface)
                        .onChange(of: draftText) { _, newValue in
                            handleDraftChange(newValue)
                        }
                }
            }
            .background(AmplifyColors.surface)

            if viewModel.selectedFile == nil {
                placeholderView()
                    .background(AmplifyColors.surface)
            }
        }
        .onAppear {
            setupDebouncedSave()
            syncSelectedFileFromDisk(forceReload: true)
        }
        .onChange(of: viewModel.selectedFile?.filePath) {
            syncSelectedFileFromDisk(forceReload: true)
        }
        .onChange(of: viewModel.reloadRevision) { _, _ in
            syncSelectedFileFromDisk(forceReload: false)
        }
    }

    // MARK: - Title Bar

    @ViewBuilder
    private func titleBar(for piece: WritingPiece) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.frontMatter.title
                     ?? piece.filePath?.deletingPathExtension().lastPathComponent
                     ?? "Untitled")
                    .font(AmplifyFonts.title2)
                    .foregroundStyle(AmplifyColors.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let version = piece.frontMatter.version {
                        Label("v\(version)", systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    if let edited = piece.frontMatter.edited {
                        Label(edited, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AmplifyColors.barBg)
    }

    private func noticeBar(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(AmplifyColors.inkSecondary)
                .lineLimit(2)

            Spacer()

            Button("Reload") {
                reloadSelectedFileFromDisk()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AmplifyColors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AmplifyColors.barBg)
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholderView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Get started")
                        .font(AmplifyFonts.title2)
                        .foregroundStyle(AmplifyColors.inkPrimary)
                    Text("Type any of these into the Claude Code terminal →")
                        .font(.body)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                }

                let commands = viewModel.skillPack.starterCommands
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(commands, id: \.command) { item in
                        StarterCommandRow(item: item)
                    }
                }

                Text("Then select a file from the sidebar to edit it here.")
                    .font(.callout)
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }
            .padding(40)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Draft Sync

    private func setupDebouncedSave() {
        saveCancellable?.cancel()
        saveCancellable = saveSubject
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
            .sink { request in
                do {
                    let savedText = try viewModel.saveRawDocument(
                        request.text,
                        at: request.fileURL,
                        expectedBaseText: request.baseText
                    )

                    if loadedFileURL == request.fileURL {
                        editorNotice = nil
                        replaceDraftText(savedText, fileURL: request.fileURL, diskText: savedText)
                    }
                } catch {
                    if loadedFileURL == request.fileURL {
                        editorNotice = error.localizedDescription
                    } else {
                        viewModel.noticeMessage = error.localizedDescription
                    }
                }
            }
    }

    private func handleDraftChange(_ newValue: String) {
        guard !isProgrammaticChange, let fileURL = loadedFileURL else { return }
        editorNotice = nil
        let isDirty = newValue != loadedDiskText
        viewModel.setDirty(fileURL, isDirty: isDirty)
        guard isDirty else { return }
        saveSubject.send(EditorSaveRequest(fileURL: fileURL, text: newValue, baseText: loadedDiskText))
    }

    private func syncSelectedFileFromDisk(forceReload: Bool) {
        guard let fileURL = viewModel.selectedFile?.filePath else {
            loadedFileURL = nil
            loadedDiskText = ""
            draftText = ""
            editorNotice = nil
            return
        }

        guard let diskText = try? String(contentsOf: fileURL, encoding: .utf8) else {
            editorNotice = "Couldn't read \(fileURL.lastPathComponent)."
            return
        }

        let switchedFiles = loadedFileURL != fileURL
        if switchedFiles || forceReload {
            editorNotice = nil
            replaceDraftText(diskText, fileURL: fileURL, diskText: diskText)
            return
        }

        if draftText == loadedDiskText {
            editorNotice = nil
            replaceDraftText(diskText, fileURL: fileURL, diskText: diskText)
        } else if diskText != loadedDiskText {
            editorNotice = "\(fileURL.lastPathComponent) changed on disk while you had local edits."
        }
    }

    private func reloadSelectedFileFromDisk() {
        guard let fileURL = loadedFileURL,
              let diskText = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return }

        editorNotice = nil
        replaceDraftText(diskText, fileURL: fileURL, diskText: diskText)
    }

    private func replaceDraftText(_ text: String, fileURL: URL, diskText: String) {
        isProgrammaticChange = true
        loadedFileURL = fileURL
        loadedDiskText = diskText
        draftText = text
        viewModel.setDirty(fileURL, isDirty: false)
        DispatchQueue.main.async {
            isProgrammaticChange = false
        }
    }
}

// MARK: - StarterCommandRow

struct StarterCommandRow: View {
    let item: StarterCommand

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.command)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AmplifyColors.inkPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AmplifyColors.barBg)
                )
                .frame(minWidth: 200, alignment: .leading)

            Text(item.description)
                .font(.callout)
                .foregroundStyle(AmplifyColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
