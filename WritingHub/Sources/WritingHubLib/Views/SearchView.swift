import SwiftUI
import AppKit

struct SearchResult: Identifiable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let lineNumber: Int
    let lineText: String
}

struct SearchView: View {
    @ObservedObject var viewModel: HubViewModel
    @Binding var isPresented: Bool
    @Binding var query: String
    @State private var results: [SearchResult] = []
    @State private var selectedResultID: SearchResult.ID?
    @State private var searchNotice: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var keyMonitor: Any?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AmplifyColors.inkTertiary)
                    .font(.system(size: 14))

                TextField("Search workspace...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($searchFocused)
                    .onSubmit {
                        if let selected = selectedResult {
                            openResult(selected)
                        } else {
                            performSearch()
                        }
                    }
                    .onChange(of: query) { _, _ in performSearch() }

                if !query.isEmpty {
                    Button {
                        searchTask?.cancel()
                        query = ""
                        results = []
                        searchNotice = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AmplifyColors.inkTertiary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }

                Text("esc")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AmplifyColors.inkTertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).stroke(AmplifyColors.inkTertiary.opacity(0.3)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AmplifyColors.surface)

            Divider()

            // Results
            if results.isEmpty && !query.isEmpty {
                VStack {
                    Spacer()
                    Text("No results")
                        .font(.callout)
                        .foregroundStyle(AmplifyColors.inkTertiary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(results) { result in
                                SearchResultRow(
                                    result: result,
                                    isSelected: result.id == selectedResultID
                                ) {
                                    openResult(result)
                                }
                                .id(result.id)
                            }
                        }
                    }
                    .onChange(of: selectedResultID) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }

            if let searchNotice {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text(searchNotice)
                        .font(.caption)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AmplifyColors.surface)
            }
        }
        .frame(width: 500, height: 400)
        .background(AmplifyColors.parchment)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            searchFocused = true
            performSearch()
            installKeyMonitor()
        }
        .onDisappear {
            searchTask?.cancel()
            removeKeyMonitor()
        }
        .onExitCommand { isPresented = false }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchTask?.cancel()
            results = []
            searchNotice = nil
            return
        }

        guard let root = viewModel.folderManager?.root else { return }

        searchTask?.cancel()
        let lowered = trimmed.lowercased()
        searchTask = Task {
            let snapshot = await Task.detached(priority: .userInitiated) {
                FolderManager(root: root).searchWorkspace(query: lowered)
            }.value

            guard !Task.isCancelled else { return }

            results = snapshot.matches.map {
                SearchResult(
                    fileURL: $0.fileURL,
                    fileName: $0.fileName,
                    lineNumber: $0.lineNumber,
                    lineText: $0.lineText
                )
            }
            if let selectedResultID, results.contains(where: { $0.id == selectedResultID }) {
                self.selectedResultID = selectedResultID
            } else {
                self.selectedResultID = results.first?.id
            }
            searchNotice = snapshot.warningMessage
        }
    }

    private func openResult(_ result: SearchResult) {
        guard result.fileURL.pathExtension == "md",
              let content = try? String(contentsOf: result.fileURL, encoding: .utf8),
              var piece = try? WritingPiece.parse(from: content)
        else { return }
        piece.filePath = result.fileURL
        viewModel.openTab(piece)
        isPresented = false
    }

    private var selectedResult: SearchResult? {
        guard let selectedResultID else { return results.first }
        return results.first(where: { $0.id == selectedResultID }) ?? results.first
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }

        let currentIndex = selectedResult.flatMap { current in
            results.firstIndex(where: { $0.id == current.id })
        } ?? 0

        switch direction {
        case .down:
            selectedResultID = results[min(currentIndex + 1, results.count - 1)].id
        case .up:
            selectedResultID = results[max(currentIndex - 1, 0)].id
        default:
            break
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isPresented else { return event }
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { return event }

        switch event.keyCode {
        case 125:
            moveSelection(.down)
            return nil
        case 126:
            moveSelection(.up)
            return nil
        case 36, 76:
            if let selected = selectedResult {
                openResult(selected)
                return nil
            }
            return event
        case 53:
            isPresented = false
            return nil
        default:
            return event
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(AmplifyColors.inkTertiary)

                Text(result.fileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AmplifyColors.inkSecondary)

                Text(":\(result.lineNumber)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }

            Text(result.lineText)
                .font(.system(size: 12))
                .foregroundStyle(AmplifyColors.inkPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isSelected || isHovered) ? AmplifyColors.selectionTint : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
    }
}
