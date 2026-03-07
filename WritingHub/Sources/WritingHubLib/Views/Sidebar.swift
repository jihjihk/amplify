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
                            onSelect: selectFile
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
        viewModel.selectedFile = piece
    }
}

// MARK: - WorkspaceItemRow

public struct WorkspaceItemRow: View {
    public let item: WorkspaceItem
    public let selectedPath: URL?
    public let onSelect: (URL) -> Void
    @State private var isExpanded = true

    private var isSelected: Bool { selectedPath == item.path }

    public var body: some View {
        if item.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(item.children) { child in
                    WorkspaceItemRow(item: child, selectedPath: selectedPath, onSelect: onSelect)
                }
            } label: {
                Label(item.name, systemImage: isExpanded ? "folder.open" : "folder")
                    .font(.callout)
                    .foregroundStyle(AmplifyColors.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isExpanded.toggle() }
            }
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
                }
            }
        }
    }

    private func fileIcon(for name: String) -> String {
        if name.hasSuffix(".md") { return "doc.text" }
        return "doc"
    }
}
