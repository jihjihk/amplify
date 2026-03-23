import SwiftUI

// MARK: - ContentView

public struct ContentView: View {
    @StateObject private var viewModel = HubViewModel()
    @State private var showSidebar: Bool = true
    @State private var showTerminal: Bool = true
    @State private var showSearch: Bool = false
    @State private var searchQuery: String = ""
    @State private var workspaceError: String?

    public init() {}

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isHubOpen {
            hubView
        } else {
            WelcomeView(onOpenFolder: openFolder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AmplifyColors.parchment)
        }
    }

    @ViewBuilder
    private var hubView: some View {
        VStack(spacing: 0) {
            BrandingHeader(
                config: viewModel.config,
                showTerminal: $showTerminal,
            )

            HSplitView {
                VStack(spacing: 0) {
                    SidebarTopBar(
                        showSidebar: $showSidebar,
                        searchQuery: $searchQuery,
                        onShowSearch: openSearch
                    )

                    if showSidebar {
                        Sidebar(viewModel: viewModel)
                    }
                }
                .frame(minWidth: showSidebar ? 180 : 46,
                       idealWidth: showSidebar ? 220 : 46,
                       maxWidth: showSidebar ? 300 : 46)

                VStack(spacing: 0) {
                    if !viewModel.openTabs.isEmpty {
                        TabBar(viewModel: viewModel)
                    }
                    EditorView(viewModel: viewModel)
                }
                .frame(minWidth: 400)

                VStack(spacing: 0) {
                    if let root = viewModel.folderManager?.root {
                        TerminalTabsView(folderPath: root)
                    }
                }
                .frame(minWidth: showTerminal ? 280 : 0,
                       idealWidth: 380,
                       maxWidth: showTerminal ? .infinity : 0)
                .opacity(showTerminal ? 1 : 0)
                .clipped()
            }
            StatusBar(viewModel: viewModel)
        }
    }

    public var body: some View {
        mainContent
        .frame(minWidth: 900, minHeight: 600)
        .background(AmplifyColors.parchment)
        .overlay {
            if showSearch {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showSearch = false }

                    VStack {
                        SearchView(
                            viewModel: viewModel,
                            isPresented: $showSearch,
                            query: $searchQuery
                        )
                            .padding(.top, 60)
                        Spacer()
                    }
                }
            }
        }
        .background(
            Button("") { viewModel.closeActiveTab() }
                .keyboardShortcut("w", modifiers: .command)
                .hidden()
        )
        .background(
            Button("") { openSearch() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .hidden()
        )
        .tint(AmplifyColors.accent)
        .navigationTitle(viewModel.isHubOpen
            ? viewModel.folderManager?.root.lastPathComponent ?? "Amplify"
            : "Amplify")
        .alert("Couldn't Open Workspace", isPresented: Binding(
            get: { workspaceError != nil },
            set: { if !$0 { workspaceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspaceError ?? "")
        }
    }

    private func openFolder(_ url: URL, skill: SkillPack, name: String) {
        let existing = HubConfig.load(from: url)
        let useCase = existing?.useCase ?? ""
        let resolvedName = existing?.name ?? name
        do {
            try viewModel.openFolder(url, skill: skill, name: resolvedName, useCase: useCase)
        } catch {
            workspaceError = error.localizedDescription
            return
        }
        let config = HubConfig(name: resolvedName, skillPack: skill, useCase: useCase)
        config.save(to: url)
        viewModel.config = config
        viewModel.skillPack = skill
    }

    private func openSearch() {
        showSearch = true
    }
}

// MARK: - BrandingHeader

struct BrandingHeader: View {
    let config: HubConfig
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
    case pickBoilerplate(URL, String)               // url, name
    case enterUseCase(URL, String, SkillPack)       // url, name, skill
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
    @State private var errorMessage: String?
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
        Group {
            switch step {
            case .pickFolder:
                pickFolderView
            case .enterName(let url):
                enterNameView(url: url)
            case .pickBoilerplate(let url, let name):
                pickBoilerplateView(url: url, name: name)
            case .enterUseCase(let url, let name, let skill):
                enterUseCaseView(url: url, name: name, skill: skill)
            case .scaffolded(let url, let skill, let name):
                scaffoldedView(url: url, skill: skill, name: name)
            }
        }
        .alert("Couldn't Create Workspace", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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

                Text("Write with agents. Sound like yourself.")
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
                step = .pickBoilerplate(url, finalName)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 3: Pick Boilerplate

    private func pickBoilerplateView(url: URL, name: String) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start with a boilerplate")
                        .font(AmplifyFonts.instrumentSerif(size: 28))
                        .foregroundStyle(AmplifyColors.inkPrimary)

                    Text("Pick a starter setup, or start blank.")
                        .font(.body)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(SkillPack.allCases) { skill in
                        BoilerplateCard(skill: skill) {
                            if skill.asksForUseCase {
                                step = .enterUseCase(url, name, skill)
                            } else {
                                scaffold(url: url, name: name, skill: skill, useCase: "")
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 520)

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Step 4: Enter Use Case (writing boilerplates only)

    private func enterUseCaseView(url: URL, name: String, skill: SkillPack) -> some View {
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
                        scaffold(url: url, name: name, skill: skill, useCase: "")
                    }
                    .foregroundStyle(AmplifyColors.inkTertiary)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Continue") {
                        scaffold(url: url, name: name, skill: skill, useCase: useCase.trimmingCharacters(in: .whitespacesAndNewlines))
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

    private func scaffold(url: URL, name: String, skill: SkillPack, useCase: String) {
        let manager = FolderManager(root: url)
        let createFolders = !skill.folders.isEmpty
        do {
            try manager.scaffold(skill: skill, name: name, useCase: useCase, createFolders: createFolders)
            HubConfig(name: name, skillPack: skill, useCase: useCase).save(to: url)
            step = .scaffolded(url, skill, name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Step 5: Scaffolded Confirmation

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

                HStack(spacing: 6) {
                    Image(systemName: skill.icon)
                        .font(.system(size: 12))
                    Text(skill.displayName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AmplifyColors.inkTertiary)

                Text(url.lastPathComponent + "/")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Next steps:")
                    .font(AmplifyFonts.headline)
                    .foregroundStyle(AmplifyColors.inkPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(skill.nextSteps, id: \.self) { step in
                        Text(step)
                    }
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

// MARK: - BoilerplateCard

struct BoilerplateCard: View {
    let skill: SkillPack
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: skill.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(AmplifyColors.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AmplifyColors.inkPrimary)

                    Text(skill.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(AmplifyColors.inkSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? AmplifyColors.selectionTint : AmplifyColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AmplifyColors.inkTertiary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
