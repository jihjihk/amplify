import SwiftUI
import MarkupEditor
import Combine

/// A WYSIWYG editor panel that displays and edits a selected WritingPiece.
///
/// Shows a title bar with frontmatter info (title, version, edited date),
/// an HTML-based rich text editor via MarkupEditor, and implements debounced
/// auto-save after 1 second of inactivity.
public struct EditorView: View {
    @ObservedObject var viewModel: HubViewModel

    /// The HTML content bound to the MarkupEditorView.
    @State private var htmlContent: String = ""

    /// Publisher used to debounce edits before saving.
    @State private var saveSubject = PassthroughSubject<String, Never>()

    /// Cancellable for the debounce subscription.
    @State private var saveCancellable: AnyCancellable?

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let piece = viewModel.selectedFile {
                VStack(spacing: 0) {
                    titleBar(for: piece)
                    Divider()
                    editorArea()
                }
                .onAppear {
                    loadContent(from: piece)
                    setupDebouncedSave()
                }
                .onChange(of: viewModel.selectedFile?.filePath) {
                    if let piece = viewModel.selectedFile {
                        loadContent(from: piece)
                    }
                }
            } else {
                placeholderView()
            }
        }
    }

    // MARK: - Title Bar

    @ViewBuilder
    private func titleBar(for piece: WritingPiece) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(piece.frontMatter.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let version = piece.frontMatter.version {
                        Label("v\(version)", systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let edited = piece.frontMatter.edited {
                        Label(edited, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let stage = piece.frontMatter.stage {
                        Label(stage.rawValue.capitalized, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Editor Area

    @ViewBuilder
    private func editorArea() -> some View {
        MarkupEditorView(html: $htmlContent)
            .onChange(of: htmlContent) { _, newValue in
                saveSubject.send(newValue)
            }
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholderView() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a file from the sidebar")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content Loading

    /// Load the body of a WritingPiece into the editor as HTML.
    private func loadContent(from piece: WritingPiece) {
        htmlContent = markdownToHTML(piece.body)
    }

    // MARK: - Debounced Save

    /// Set up a Combine pipeline that saves after 1 second of no typing.
    private func setupDebouncedSave() {
        saveCancellable?.cancel()
        saveCancellable = saveSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { newHTML in
                guard var piece = viewModel.selectedFile else { return }
                piece.body = htmlToMarkdown(newHTML)
                piece.frontMatter.edited = ISO8601DateFormatter().string(from: Date())
                piece.frontMatter.version = (piece.frontMatter.version ?? 0) + 1
                viewModel.savePiece(piece)
            }
    }

    // MARK: - Markdown <-> HTML Conversion

    /// Simple markdown to HTML conversion for MVP.
    /// Handles headings, bold, italic, paragraphs, and line breaks.
    private func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html: [String] = []

        for i in 0..<lines.count {
            var line = lines[i]

            // Headings
            if line.hasPrefix("### ") {
                line = "<h3>\(String(line.dropFirst(4)))</h3>"
            } else if line.hasPrefix("## ") {
                line = "<h2>\(String(line.dropFirst(3)))</h2>"
            } else if line.hasPrefix("# ") {
                line = "<h1>\(String(line.dropFirst(2)))</h1>"
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // Empty lines become paragraph breaks
                html.append("")
                continue
            } else {
                // Inline formatting
                line = applyInlineFormatting(line)
                line = "<p>\(line)</p>"
            }

            html.append(line)
        }

        return html.joined(separator: "\n")
    }

    /// Simple HTML to markdown conversion for MVP.
    private func htmlToMarkdown(_ html: String) -> String {
        var text = html

        // Convert headings
        text = text.replacingOccurrences(of: "<h1>", with: "# ")
        text = text.replacingOccurrences(of: "</h1>", with: "")
        text = text.replacingOccurrences(of: "<h2>", with: "## ")
        text = text.replacingOccurrences(of: "</h2>", with: "")
        text = text.replacingOccurrences(of: "<h3>", with: "### ")
        text = text.replacingOccurrences(of: "</h3>", with: "")

        // Convert bold/italic
        text = text.replacingOccurrences(of: "<b>", with: "**")
        text = text.replacingOccurrences(of: "</b>", with: "**")
        text = text.replacingOccurrences(of: "<strong>", with: "**")
        text = text.replacingOccurrences(of: "</strong>", with: "**")
        text = text.replacingOccurrences(of: "<i>", with: "*")
        text = text.replacingOccurrences(of: "</i>", with: "*")
        text = text.replacingOccurrences(of: "<em>", with: "*")
        text = text.replacingOccurrences(of: "</em>", with: "*")

        // Convert paragraphs and line breaks
        text = text.replacingOccurrences(of: "<p>", with: "")
        text = text.replacingOccurrences(of: "</p>", with: "\n")
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n")
        text = text.replacingOccurrences(of: "<br />", with: "\n")

        // Strip remaining HTML tags
        while let startRange = text.range(of: "<"),
              let endRange = text.range(of: ">", range: startRange.upperBound..<text.endIndex) {
            text.removeSubrange(startRange.lowerBound...endRange.lowerBound)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Apply inline markdown formatting (bold, italic).
    private func applyInlineFormatting(_ text: String) -> String {
        var result = text
        // Bold: **text**
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<b>$1</b>",
            options: .regularExpression
        )
        // Italic: *text*
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<i>$1</i>",
            options: .regularExpression
        )
        return result
    }
}
