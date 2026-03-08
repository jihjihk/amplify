import SwiftUI

// MARK: - Sidebar

public struct Sidebar: View {
    @ObservedObject var viewModel: HubViewModel

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                if viewModel.workspaceFiles.isEmpty {
                    Text("No files yet")
                        .foregroundStyle(AmplifyColors.inkTertiary)
                        .font(.callout)
                        .italic()
                        .padding(.vertical, 2)
                } else {
                    ForEach(viewModel.workspaceFiles) { item in
                        WorkspaceItemRow(
                            item: item,
                            selectedPath: viewModel.selectedFile?.filePath,
                            onSelect: selectFile,
                            onReload: { viewModel.reload() }
                        )
                    }
                }
            } header: {
                sectionHeader()
            }
            .textCase(nil)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AmplifyColors.sidebarBg)
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader() -> some View {
        HStack {
            Text("Files")
                .font(AmplifyFonts.headline)
                .foregroundStyle(AmplifyColors.inkSecondary)
            Spacer()
            Button {
                if let root = viewModel.folderManager?.root {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: root.path)
                }
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }
            .buttonStyle(.plain)
            .help("Open in Finder")
        }
    }

    // MARK: - Select File

    private func selectFile(at url: URL) {
        guard url.pathExtension == "md",
              let content = try? String(contentsOf: url, encoding: .utf8),
              var piece = try? WritingPiece.parse(from: content)
        else { return }
        piece.filePath = url
        viewModel.openTab(piece)
    }
}

// MARK: - WorkspaceItemRow

public struct WorkspaceItemRow: View {
    public let item: WorkspaceItem
    public let selectedPath: URL?
    public let onSelect: (URL) -> Void
    public let onReload: () -> Void

    @State private var isExpanded = true
    @State private var isHovered = false
    @State private var creationMode: CreationMode? = nil
    @State private var newItemName = ""
    @FocusState private var newItemFieldFocused: Bool

    enum CreationMode { case file, folder }

    private var isSelected: Bool { selectedPath == item.path }

    public init(
        item: WorkspaceItem,
        selectedPath: URL?,
        onSelect: @escaping (URL) -> Void,
        onReload: @escaping () -> Void
    ) {
        self.item = item
        self.selectedPath = selectedPath
        self.onSelect = onSelect
        self.onReload = onReload
    }

    public var body: some View {
        if item.isDirectory {
            folderRow
        } else {
            fileRow
        }
    }

    // MARK: - Folder Row

    private var folderRow: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Inline creation field appears at top of folder contents
            if let mode = creationMode {
                HStack(spacing: 6) {
                    Image(systemName: mode == .file ? "doc.text" : "folder")
                        .font(.callout)
                        .foregroundStyle(AmplifyColors.inkTertiary)
                    TextField(mode == .file ? "filename.md" : "folder name", text: $newItemName)
                        .font(.callout)
                        .textFieldStyle(.plain)
                        .focused($newItemFieldFocused)
                        .onSubmit { commitCreation() }
                        .onExitCommand { cancelCreation() }
                }
                .padding(.vertical, 2)
            }

            ForEach(item.children) { child in
                WorkspaceItemRow(
                    item: child,
                    selectedPath: selectedPath,
                    onSelect: onSelect,
                    onReload: onReload
                )
            }
        } label: {
            HStack(spacing: 0) {
                Label(item.name, systemImage: isExpanded ? "folder.open" : "folder")
                    .font(.callout)
                    .foregroundStyle(AmplifyColors.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isExpanded.toggle() }

                if isHovered {
                    Button {
                        startCreation(.file)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("New file in \(item.name)")
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
            .contextMenu { folderContextMenu }
        }
    }

    @ViewBuilder
    private var folderContextMenu: some View {
        Button("New File") { startCreation(.file) }
        Button("New Folder") { startCreation(.folder) }
        Divider()
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.path])
        }
    }

    // MARK: - File Row

    private var fileRow: some View {
        Button {
            onSelect(item.path)
        } label: {
            Label(item.name, systemImage: fileIcon(for: item.name))
                .font(.callout)
                .foregroundStyle(isSelected ? AmplifyColors.inkPrimary : AmplifyColors.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 6).fill(AmplifyColors.selectionTint)
                : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
        )
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            }
            Divider()
            Button("Delete", role: .destructive) {
                try? FileManager.default.removeItem(at: item.path)
                onReload()
            }
        }
    }

    // MARK: - Creation Helpers

    private func startCreation(_ mode: CreationMode) {
        newItemName = ""
        creationMode = mode
        isExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            newItemFieldFocused = true
        }
    }

    private func commitCreation() {
        guard let mode = creationMode else { return }
        var name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelCreation(); return }

        if mode == .file && !name.hasSuffix(".md") { name += ".md" }

        let target = item.path.appendingPathComponent(name)
        do {
            if mode == .file {
                let template = "---\ntitle: \"\"\ncreated: \(FolderManager.todayString())\n---\n\n"
                try template.write(to: target, atomically: true, encoding: .utf8)
            } else {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            }
        } catch {
            // silently ignore — file may already exist
        }
        cancelCreation()
        onReload()
    }

    private func cancelCreation() {
        creationMode = nil
        newItemName = ""
        newItemFieldFocused = false
    }

    private func fileIcon(for name: String) -> String {
        name.hasSuffix(".md") ? "doc.text" : "doc"
    }
}
