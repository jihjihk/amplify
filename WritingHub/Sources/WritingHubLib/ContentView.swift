import SwiftUI
import MarkupEditor

// MARK: - ContentView

public struct ContentView: View {
    @StateObject private var viewModel = HubViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isHubOpen {
                VStack(spacing: 0) {
                    BrandingHeader(config: viewModel.config)

                    HSplitView {
                        Sidebar(viewModel: viewModel)
                            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                        EditorView(viewModel: viewModel)
                            .frame(minWidth: 400)

                        VStack(spacing: 0) {
                            HStack {
                                Text("Claude Code")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AmplifyColors.inkTertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AmplifyColors.barBg)

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AmplifyColors.parchment)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(AmplifyColors.parchment)
        .tint(AmplifyColors.accent)
        .navigationTitle(viewModel.isHubOpen
            ? viewModel.folderManager?.root.lastPathComponent ?? "Amplify"
            : "Amplify")
        // Pre-warm WKWebView — overlay keeps it alive without affecting background rendering
        .overlay(alignment: .bottomTrailing) {
            MarkupEditorView(html: .constant(""))
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    private func openFolder(_ url: URL, skill: SkillPack, name: String) {
        try? viewModel.openFolder(url, skill: skill)
        let config = HubConfig(name: name, skillPack: skill)
        config.save(to: url)
        viewModel.config = config
        viewModel.skillPack = skill
    }
}

// MARK: - BrandingHeader

struct BrandingHeader: View {
    let config: HubConfig

    var body: some View {
        HStack {
            Text("amplifying ")
                .font(AmplifyFonts.instrumentSerif(size: 22))
                .foregroundStyle(AmplifyColors.inkSecondary)
            + Text(config.name)
                .font(AmplifyFonts.instrumentSerifItalic(size: 22))
                .foregroundStyle(AmplifyColors.inkPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(AmplifyColors.barBg)
    }
}

// MARK: - OnboardingStep

enum OnboardingStep {
    case pickFolder
    case enterName(URL)
    case scaffolded(URL, SkillPack, String)
}

// MARK: - WelcomeView

public struct WelcomeView: View {
    public let onOpenFolder: (URL, SkillPack, String) -> Void
    @State private var showPicker = false
    @State private var step: OnboardingStep = .pickFolder
    @State private var userName: String = ""

    public init(onOpenFolder: @escaping (URL, SkillPack, String) -> Void) {
        self.onOpenFolder = onOpenFolder
    }

    public var body: some View {
        switch step {
        case .pickFolder:
            pickFolderView
        case .enterName(let url):
            enterNameView(url: url)
        case .scaffolded(let url, let skill, let name):
            scaffoldedView(url: url, skill: skill, name: name)
        }
    }

    // MARK: - Step 1: Pick Folder

    private var pickFolderView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Text("Amplify")
                    .font(AmplifyFonts.largeTitle)
                    .foregroundStyle(AmplifyColors.inkPrimary)

                Text("The better, faster and cheaper way to write with agents and amplify your voice")
                    .font(AmplifyFonts.title3)
                    .foregroundStyle(AmplifyColors.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Choose Folder") {
                showPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }

            if let existing = HubConfig.load(from: url) {
                onOpenFolder(url, existing.skillPack, existing.name)
            } else {
                step = .enterName(url)
            }
        }
    }

    // MARK: - Step 2: Enter Name

    private func enterNameView(url: URL) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Large serif name input — the name appears inline with "amplifying"
            ZStack(alignment: .leading) {
                (
                    Text("amplifying ")
                        .font(AmplifyFonts.instrumentSerif(size: 42))
                        .foregroundStyle(AmplifyColors.inkSecondary)
                    + Text(userName.isEmpty ? "your name" : userName)
                        .font(AmplifyFonts.instrumentSerifItalic(size: 42))
                        .foregroundStyle(userName.isEmpty ? AmplifyColors.inkTertiary : AmplifyColors.inkPrimary)
                )
                .frame(maxWidth: 520, alignment: .leading)

                // Invisible text field — captures input, updates userName
                TextField("", text: $userName)
                    .font(AmplifyFonts.instrumentSerifItalic(size: 42))
                    .textFieldStyle(.plain)
                    .opacity(0.01)
                    .frame(maxWidth: 520)
            }

            Spacer().frame(height: 52)

            Button("Continue") {
                let name = userName.trimmingCharacters(in: .whitespaces)
                let finalName = name.isEmpty ? "you" : name
                let manager = FolderManager(root: url)
                try? manager.scaffold(skill: .founder)
                step = .scaffolded(url, .founder, finalName)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 3: Scaffolded Confirmation

    private func scaffoldedView(url: URL, skill: SkillPack, name: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AmplifyColors.accent)

            VStack(spacing: 8) {
                Text("Workspace ready")
                    .font(AmplifyFonts.title2)
                    .foregroundStyle(AmplifyColors.inkPrimary)

                Text(url.lastPathComponent + "/")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Next steps:")
                    .font(AmplifyFonts.headline)
                    .foregroundStyle(AmplifyColors.inkPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Drop past writing into references/")
                    Text("2. Ask Claude to \"create voice dna\" in the terminal")
                    Text("3. Start writing!")
                }
                .font(.body)
                .foregroundStyle(AmplifyColors.inkSecondary)
            }

            Button("Open Workspace") {
                onOpenFolder(url, skill, name)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }
}
