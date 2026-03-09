import SwiftUI
import MarkupEditor

// MARK: - ContentView

public struct ContentView: View {
    @StateObject private var viewModel = HubViewModel()
    @State private var showSidebar: Bool = true
    @State private var showTerminal: Bool = true

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isHubOpen {
                VStack(spacing: 0) {
                    BrandingHeader(config: viewModel.config, showSidebar: $showSidebar, showTerminal: $showTerminal)

                    HSplitView {
                        if showSidebar {
                            Sidebar(viewModel: viewModel)
                                .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                        }

                        VStack(spacing: 0) {
                            if !viewModel.openTabs.isEmpty {
                                TabBar(viewModel: viewModel)
                            }
                            EditorView(viewModel: viewModel)
                        }
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
                        .frame(minWidth: showTerminal ? 300 : 0,
                               idealWidth: 380,
                               maxWidth: showTerminal ? 500 : 0)
                        .opacity(showTerminal ? 1 : 0)
                        .clipped()
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
        .background(
            Button("") { viewModel.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
                .hidden()
        )
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
        let existing = HubConfig.load(from: url)
        let useCase = existing?.useCase ?? ""
        let resolvedName = existing?.name ?? name
        try? viewModel.openFolder(url, skill: skill, name: resolvedName, useCase: useCase)
        let config = HubConfig(name: resolvedName, skillPack: skill, useCase: useCase)
        config.save(to: url)
        viewModel.config = config
        viewModel.skillPack = skill
    }
}

// MARK: - BrandingHeader

struct BrandingHeader: View {
    let config: HubConfig
    @Binding var showSidebar: Bool
    @Binding var showTerminal: Bool

    var body: some View {
        HStack {
            Text("amplifying ")
                .font(AmplifyFonts.instrumentSerif(size: 22))
                .foregroundStyle(AmplifyColors.inkSecondary)
            + Text(config.name)
                .font(AmplifyFonts.instrumentSerifItalic(size: 22))
                .foregroundStyle(AmplifyColors.inkPrimary)

            Spacer()

            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                        .foregroundStyle(showSidebar ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)
                }
                .buttonStyle(.plain)
                .help("Toggle Sidebar (⌘\\)")
                .keyboardShortcut("\\", modifiers: .command)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showTerminal.toggle() }
                } label: {
                    Image(systemName: "terminal")
                        .font(.system(size: 13))
                        .foregroundStyle(showTerminal ? AmplifyColors.inkSecondary : AmplifyColors.inkTertiary)
                }
                .buttonStyle(.plain)
                .help("Toggle Terminal (⌘⌥T)")
                .keyboardShortcut("t", modifiers: [.command, .option])
            }
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
    case enterUseCase(URL, String)       // url, name
    case scaffolded(URL, SkillPack, String)
}

// MARK: - WelcomeView

public struct WelcomeView: View {
    public let onOpenFolder: (URL, SkillPack, String) -> Void
    @State private var showPicker = false
    @State private var step: OnboardingStep = .pickFolder
    @State private var userName: String = ""
    @State private var useCase: String = ""
    @State private var placeholderIndex: Int = 0
    @FocusState private var nameFieldFocused: Bool

    private static let useCasePlaceholders = [
        "e.g. I'm a founder who wants a second brain — somewhere to dump raw ideas, spar on strategy, and turn half-thoughts into sharp writing for LinkedIn and Substack...",
        "e.g. I'm trying to establish authority online by writing consistently about my field. I want to build an audience on Substack and LinkedIn, but I struggle to find my voice and stay consistent...",
        "e.g. I want to journal regularly, reflect on what I'm learning, and use AI to help me spot patterns in my thinking and turn insights into essays or threads...",
    ]

    private var useCasePlaceholder: String {
        Self.useCasePlaceholders[placeholderIndex % Self.useCasePlaceholders.count]
    }

    public init(onOpenFolder: @escaping (URL, SkillPack, String) -> Void) {
        self.onOpenFolder = onOpenFolder
    }

    public var body: some View {
        switch step {
        case .pickFolder:
            pickFolderView
        case .enterName(let url):
            enterNameView(url: url)
        case .enterUseCase(let url, let name):
            enterUseCaseView(url: url, name: name)
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

                Text("The writing app for AI native writers")
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
                    .focused($nameFieldFocused)
            }
            .onAppear { nameFieldFocused = true }

            Spacer().frame(height: 52)

            Button("Continue") {
                let name = userName.trimmingCharacters(in: .whitespaces)
                let finalName = name.isEmpty ? "you" : name
                step = .enterUseCase(url, finalName)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 3: Enter Use Case

    private func enterUseCaseView(url: URL, name: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you write?")
                        .font(AmplifyFonts.instrumentSerif(size: 28))
                        .foregroundStyle(AmplifyColors.inkPrimary)

                    Text("Who's your audience, what topics, what's the goal? A few sentences is enough.")
                        .font(.body)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                }

                ZStack(alignment: .topLeading) {
                    // Placeholder hint — rotates through common use cases
                    if useCase.isEmpty {
                        Text(useCasePlaceholder)
                            .font(.body)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .onTapGesture { placeholderIndex += 1 }
                    }

                    TextEditor(text: $useCase)
                        .font(.body)
                        .foregroundStyle(AmplifyColors.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 120, maxHeight: 200)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AmplifyColors.barBg)
                )

                HStack {
                    Button("Skip") {
                        scaffold(url: url, name: name, useCase: "")
                    }
                    .foregroundStyle(AmplifyColors.inkTertiary)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Continue") {
                        scaffold(url: url, name: name, useCase: useCase.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(useCase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(maxWidth: 520)

            Spacer()
        }
        .padding(40)
    }

    private func scaffold(url: URL, name: String, useCase: String) {
        let manager = FolderManager(root: url)
        try? manager.scaffold(skill: .founder, name: name, useCase: useCase)
        // Persist so reopening the workspace restores name + use case
        HubConfig(name: name, skillPack: .founder, useCase: useCase).save(to: url)
        step = .scaffolded(url, .founder, name)
    }

    // MARK: - Step 4: Scaffolded Confirmation

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
