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
                            onReload: { viewModel.reload() },
                            viewModel: viewModel
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
    public let viewModel: HubViewModel

    @State private var isExpanded = true
    @State private var isHovered = false
    @State private var creationMode: CreationMode? = nil
    @State private var newItemName = ""
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var newItemFieldFocused: Bool
    @FocusState private var renameFocused: Bool

    enum CreationMode { case file, folder }

    private var isSelected: Bool { selectedPath == item.path }
    private var isCut: Bool {
        viewModel.fileClipboard?.isCut == true && viewModel.fileClipboard?.url == item.path
    }

    public init(
        item: WorkspaceItem,
        selectedPath: URL?,
        onSelect: @escaping (URL) -> Void,
        onReload: @escaping () -> Void,
        viewModel: HubViewModel
    ) {
        self.item = item
        self.selectedPath = selectedPath
        self.onSelect = onSelect
        self.onReload = onReload
        self.viewModel = viewModel
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
                WorkspaceItemRow(item: child, selectedPath: selectedPath, onSelect: onSelect, onReload: onReload, viewModel: viewModel)
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
                    Button { startCreation(.file) } label: {
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
        .dropDestination(for: URL.self) { droppedURLs, _ in
            guard let source = droppedURLs.first else { return false }
            let dest = item.path.appendingPathComponent(source.lastPathComponent)
            guard source != dest else { return false }
            do {
                try FileManager.default.moveItem(at: source, to: dest)
                onReload()
                return true
            } catch { return false }
        }
    }

    @ViewBuilder
    private var folderContextMenu: some View {
        Button("New File") { startCreation(.file) }
        Button("New Folder") { startCreation(.folder) }
        if viewModel.fileClipboard != nil {
            Divider()
            Button("Paste") { viewModel.pasteFile(into: item.path) }
        }
        Divider()
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.path]) }
    }

    // MARK: - File Row

    private var fileRow: some View {
        Group {
            if isRenaming {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
                    .padding(.leading, 4)
            } else {
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
                .opacity(isCut ? 0.4 : 1.0)
                .onDrag { NSItemProvider(object: item.path as NSURL) }
            }
        }
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 6).fill(AmplifyColors.selectionTint)
                : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
        )
        .contextMenu { fileContextMenu }
    }

    @ViewBuilder
    private var fileContextMenu: some View {
        Button("Rename") {
            renameText = item.name
            isRenaming = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocused = true }
        }
        Button("Duplicate") { duplicateFile() }
        Divider()
        Button("Copy") { viewModel.copyFile(item.path) }
        Button("Cut") { viewModel.cutFile(item.path) }
        Divider()
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.path]) }
        Divider()
        Button("Delete", role: .destructive) {
            try? FileManager.default.removeItem(at: item.path)
            onReload()
        }
    }

    // MARK: - Creation Helpers

    private func startCreation(_ mode: CreationMode) {
        newItemName = ""
        creationMode = mode
        isExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { newItemFieldFocused = true }
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
        } catch {}
        cancelCreation()
        onReload()
    }

    private func cancelCreation() {
        creationMode = nil
        newItemName = ""
    }

    private func commitRename() {
        let newName = renameText.trimmingCharacters(in: .whitespaces)
        guard !newName.isEmpty else { isRenaming = false; return }
        let dest = item.path.deletingLastPathComponent().appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: item.path, to: dest)
        isRenaming = false
        onReload()
    }

    private func duplicateFile() {
        let ext = item.path.pathExtension
        let base = item.path.deletingPathExtension().lastPathComponent
        let dir = item.path.deletingLastPathComponent()
        var dest = dir.appendingPathComponent(ext.isEmpty ? "\(base)-copy" : "\(base)-copy.\(ext)")
        var i = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent(ext.isEmpty ? "\(base)-copy-\(i)" : "\(base)-copy-\(i).\(ext)")
            i += 1
        }
        try? FileManager.default.copyItem(at: item.path, to: dest)
        onReload()
    }

    private func fileIcon(for name: String) -> String {
        name.hasSuffix(".md") ? "doc.text" : "doc"
    }
}
