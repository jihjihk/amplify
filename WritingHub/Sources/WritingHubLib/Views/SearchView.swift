import SwiftUI

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
    @State private var searchNotice: String?
    @State private var searchTask: Task<Void, Never>?
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
                    .onSubmit { performSearch() }
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { result in
                            SearchResultRow(result: result) {
                                openResult(result)
                            }
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
        }
        .onDisappear { searchTask?.cancel() }
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
}

struct SearchResultRow: View {
    let result: SearchResult
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
        .background(isHovered ? AmplifyColors.selectionTint : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
    }
}
