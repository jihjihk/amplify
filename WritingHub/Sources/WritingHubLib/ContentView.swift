import SwiftUI

// MARK: - ContentView

public struct ContentView: View {
    @StateObject private var viewModel = HubViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isHubOpen {
                VStack(spacing: 0) {
                    HSplitView {
                        // Left: Pipeline sidebar
                        PipelineSidebar(viewModel: viewModel)
                            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                        // Center: WYSIWYG editor
                        EditorView(viewModel: viewModel)
                            .frame(minWidth: 400)

                        // Right: Claude Code terminal
                        VStack(spacing: 0) {
                            HStack {
                                Text("Claude Code")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.bar)

                            if let root = viewModel.folderManager?.root {
                                TerminalPanelView(folderPath: root)
                            }
                        }
                        .frame(minWidth: 300, idealWidth: 380, maxWidth: 500)
                    }
                    StatusBar(viewModel: viewModel)
                }
            } else {
                WelcomeView(onOpenFolder: openFolder)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private func openFolder(_ url: URL) {
        try? viewModel.openFolder(url)
    }
}

// MARK: - WelcomeView

public struct WelcomeView: View {
    public let onOpenFolder: (URL) -> Void
    @State private var showPicker = false

    public init(onOpenFolder: @escaping (URL) -> Void) {
        self.onOpenFolder = onOpenFolder
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "pencil.and.outline")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Writing Hub")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose a folder to get started")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Open Folder") {
                showPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onOpenFolder(url)
            }
        }
    }
}
