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

// MARK: - OnboardingStep

enum OnboardingStep {
    case pickFolder
    case scaffolded(URL)
}

// MARK: - WelcomeView

public struct WelcomeView: View {
    public let onOpenFolder: (URL) -> Void
    @State private var showPicker = false
    @State private var step: OnboardingStep = .pickFolder

    public init(onOpenFolder: @escaping (URL) -> Void) {
        self.onOpenFolder = onOpenFolder
    }

    public var body: some View {
        switch step {
        case .pickFolder:
            pickFolderView
        case .scaffolded(let url):
            scaffoldedView(url: url)
        }
    }

    // MARK: - Step 1: Pick Folder

    private var pickFolderView: some View {
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

            Button("Choose Folder") {
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
                let manager = FolderManager(root: url)
                try? manager.scaffold()
                step = .scaffolded(url)
            }
        }
    }

    // MARK: - Step 2: Scaffolded Confirmation

    private func scaffoldedView(url: URL) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Hub created at \(url.lastPathComponent)/")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Next steps:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Drop past writing into references/")
                    Text("2. Run /createvoicedna in the terminal")
                    Text("3. Start writing!")
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Button("Open Hub") {
                onOpenFolder(url)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }
}
