import SwiftUI
import MarkupEditor
import Combine

/// A WYSIWYG editor panel that displays and edits a selected WritingPiece.
///
/// The MarkupEditorView (WKWebView) is kept always-mounted to avoid the cold-start
/// lag from recreating the web content process on every file selection.
/// The placeholder is shown as an overlay when no file is selected.
public struct EditorView: View {
    @ObservedObject var viewModel: HubViewModel
    @StateObject private var editorDelegate = EditorInputDelegate()

    @State private var htmlContent: String = ""
    @State private var saveSubject = PassthroughSubject<String, Never>()
    @State private var saveCancellable: AnyCancellable?
    @State private var isSaving = false

    public init(viewModel: HubViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Always-mounted editor — WKWebView persists across file selections
            VStack(spacing: 0) {
                if let piece = viewModel.selectedFile {
                    titleBar(for: piece)
                    Divider().overlay(AmplifyColors.barBg.opacity(0.5))
                }
                MarkupEditorView(
                    markupDelegate: editorDelegate,
                    userScripts: [Self.editorStyleScript],
                    html: $htmlContent
                )
            }

            // Placeholder overlay — shown when no file is selected
            if viewModel.selectedFile == nil {
                placeholderView()
                    .background(AmplifyColors.surface)
            }
        }
        .background(AmplifyColors.surface)
        .onAppear {
            setupDebouncedSave()
        }
        .onChange(of: editorDelegate.capturedHTML) { _, html in
            guard !isSaving else { return }
            saveSubject.send(html)
        }
        .onChange(of: viewModel.selectedFile?.filePath) {
            if let piece = viewModel.selectedFile {
                loadContent(from: piece)
            } else {
                htmlContent = ""
            }
        }
        .onChange(of: viewModel.selectedFile?.body) {
            guard !isSaving, let piece = viewModel.selectedFile else { return }
            loadContent(from: piece)
        }
    }

    // MARK: - Title Bar

    @ViewBuilder
    private func titleBar(for piece: WritingPiece) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(piece.frontMatter.title
                     ?? piece.filePath?.deletingPathExtension().lastPathComponent
                     ?? "Untitled")
                    .font(AmplifyFonts.title2)
                    .foregroundStyle(AmplifyColors.inkPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let version = piece.frontMatter.version {
                        Label("v\(version)", systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                    if let edited = piece.frontMatter.edited {
                        Label(edited, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(AmplifyColors.inkTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AmplifyColors.barBg)
    }

    // MARK: - Placeholder

    @ViewBuilder
    private func placeholderView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Get started")
                        .font(AmplifyFonts.title2)
                        .foregroundStyle(AmplifyColors.inkPrimary)
                    Text("Type any of these into the Claude Code terminal →")
                        .font(.body)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                }

                let commands = viewModel.skillPack.starterCommands
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(commands, id: \.command) { item in
                        StarterCommandRow(item: item)
                    }
                }

                Text("Then select a file from the sidebar to edit it here.")
                    .font(.callout)
                    .foregroundStyle(AmplifyColors.inkTertiary)
            }
            .padding(40)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Content Loading

    private func loadContent(from piece: WritingPiece) {
        htmlContent = markdownToHTML(piece.body)
    }

    // MARK: - Debounced Save

    private func setupDebouncedSave() {
        saveCancellable?.cancel()
        saveCancellable = saveSubject
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak viewModel] newHTML in
                guard let viewModel, var piece = viewModel.selectedFile else { return }
                let newBody = htmlToMarkdown(newHTML)
                guard newBody != piece.body else { return }
                piece.body = newBody
                piece.frontMatter.edited = FolderManager.todayString()
                isSaving = true
                viewModel.savePiece(piece)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isSaving = false
                }
            }
    }

    // MARK: - Editor Style Injection

    /// JavaScript injected into MarkupEditor's WKWebView at document-end.
    /// Applies the Amplify Parchment Editorial theme.
    static let editorStyleScript: String = {
        let css = """
            /* Amplify Parchment Editorial Theme */

            /* ── Design tokens ──────────────────────────────── */
            :root {
                --bg:           #F7F4EF;
                --ink:          #1A1713;
                --ink-2:        #2C2520;
                --ink-3:        #6B6157;
                --ink-4:        #9C9188;
                --toolbar-bg:   #F2EDE4;
                --sep:          rgba(26,23,19,0.09);
                --mark-warm:    rgba(212,165,80,0.26);
                --mark-red:     rgba(198,82,82,0.20);
                --mark-green:   rgba(72,156,92,0.22);
                --code-bg:      rgba(26,23,19,0.07);
                --btn-hover:    rgba(26,23,19,0.07);
                --btn-active:   rgba(26,23,19,0.12);
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg:         #201D19;
                    --ink:        #EDE8DF;
                    --ink-2:      #D4CEC7;
                    --ink-3:      #9C9188;
                    --ink-4:      #6B6157;
                    --toolbar-bg: #1A1713;
                    --sep:        rgba(237,232,223,0.09);
                    --mark-warm:  rgba(212,165,80,0.22);
                    --mark-red:   rgba(198,82,82,0.18);
                    --mark-green: rgba(72,156,92,0.18);
                    --code-bg:    rgba(237,232,223,0.08);
                    --btn-hover:  rgba(237,232,223,0.08);
                    --btn-active: rgba(237,232,223,0.13);
                }
            }

            /* ── Editor surface ──────────────────────────────── */
            #editor, .editor {
                font-family: Georgia, 'Times New Roman', serif !important;
                background: var(--bg) !important;
                color: var(--ink) !important;
            }
            .ProseMirror {
                max-width: 640px !important;
                margin: 0 auto !important;
                padding: 56px 40px 120px !important;
                font-size: 17px !important;
                line-height: 1.85 !important;
                caret-color: var(--ink) !important;
                outline: none !important;
            }

            /* ── Headings ─────────────────────────────────────── */
            h1 {
                font-family: 'Instrument Serif', Georgia, serif !important;
                font-size: 2.1em !important;
                font-weight: 400 !important;
                line-height: 1.2 !important;
                margin: 0 0 0.6em !important;
                color: var(--ink) !important;
                letter-spacing: -0.02em !important;
            }
            h2 {
                font-family: 'Instrument Serif', Georgia, serif !important;
                font-size: 1.5em !important;
                font-weight: 400 !important;
                line-height: 1.3 !important;
                margin: 2.2em 0 0.4em !important;
                color: var(--ink) !important;
                letter-spacing: -0.01em !important;
            }
            h3 {
                font-family: 'Instrument Serif', Georgia, serif !important;
                font-size: 1.15em !important;
                font-weight: 400 !important;
                font-style: italic !important;
                line-height: 1.4 !important;
                margin: 1.8em 0 0.3em !important;
                color: var(--ink-2) !important;
            }

            /* ── Body ─────────────────────────────────────────── */
            p, ul, ol {
                margin: 0 0 1.1em !important;
                color: var(--ink-2) !important;
                font-size: 17px !important;
                line-height: 1.85 !important;
            }
            li { margin-bottom: 0.3em !important; }
            a {
                color: var(--ink-3) !important;
                text-decoration-color: var(--sep) !important;
            }
            blockquote {
                border-left: 2px solid var(--sep) !important;
                margin: 1.5em 0 !important;
                padding: 0.2em 0 0.2em 1.2em !important;
                color: var(--ink-3) !important;
                font-style: italic !important;
            }
            p code, li code {
                font-family: 'SF Mono', 'Fira Code', 'Menlo', monospace !important;
                background: var(--code-bg) !important;
                border-radius: 3px !important;
                padding: 0.05em 0.35em !important;
                font-size: 0.87em !important;
                color: var(--ink) !important;
            }

            /* ── Highlights ──────────────────────────────────── */
            mark {
                background: var(--mark-warm) !important;
                border-radius: 2px !important;
                padding: 0.05em 0.1em !important;
                color: inherit !important;
            }
            mark.red   { background: var(--mark-red) !important; }
            mark.green { background: var(--mark-green) !important; }

            :host {
                display: flex !important;
                flex-direction: column !important;
                background: var(--bg) !important;
            }

            /* ── Toolbar ─────────────────────────────────────── */
            .Markup-toolbar {
                position: sticky !important;
                top: 0 !important;
                z-index: 100 !important;
                background: var(--toolbar-bg) !important;
                backdrop-filter: none !important;
                -webkit-backdrop-filter: none !important;
                border-bottom: 1px solid var(--sep) !important;
                padding: 4px 8px !important;
                gap: 4px !important;
                align-items: center !important;
                color: var(--ink-4) !important;
                fill: var(--ink-4) !important;
            }
            .Markup-menuitem {
                width: 28px !important;
                height: 28px !important;
                min-width: 28px !important;
                border-radius: 6px !important;
                background: transparent !important;
                border: none !important;
                color: var(--ink-4) !important;
                fill: var(--ink-4) !important;
                font-size: 13px !important;
                font-weight: 500 !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                cursor: pointer !important;
                transition: background 0.12s ease, color 0.12s ease, fill 0.12s ease !important;
            }
            .Markup-menuitem:hover {
                background: var(--btn-hover) !important;
                color: var(--ink-3) !important;
                fill: var(--ink-3) !important;
            }
            .Markup-menuitem-active {
                background: var(--btn-active) !important;
                color: var(--ink-2) !important;
                fill: var(--ink-2) !important;
            }
            .Markup-menuitem svg, .Markup-icon svg {
                fill: inherit !important;
            }
            .Markup-menuseparator {
                display: inline-block !important;
                width: 1px !important;
                min-height: 16px !important;
                height: 16px !important;
                background: var(--sep) !important;
                border: none !important;
                border-right: none !important;
                margin: 0 4px !important;
                align-self: center !important;
                vertical-align: middle !important;
            }
            .Markup-icon {
                width: 24px !important;
                height: 24px !important;
                flex-shrink: 0 !important;
                fill: inherit !important;
            }
        """

        // MarkupEditor renders as a `<markup-editor>` web component with an open shadow root.
        // Styles must be injected into shadowRoot.adoptedStyleSheets — document-level styles
        // and document.head <style> tags have zero effect inside the shadow DOM.
        return """
        (function() {
            var css = \(escapeJSString(css));

            function injectIntoShadow() {
                var host = document.querySelector('markup-editor');
                if (!host || !host.shadowRoot) return false;
                var sr = host.shadowRoot;
                // Remove any prior amplify sheet, keep MarkupEditor's built-in sheets
                var kept = [];
                for (var i = 0; i < sr.adoptedStyleSheets.length; i++) {
                    if (!sr.adoptedStyleSheets[i].__amplify) kept.push(sr.adoptedStyleSheets[i]);
                }
                var sheet = new CSSStyleSheet();
                sheet.__amplify = true;
                sheet.replaceSync(css);
                // Append at end → wins cascade over MarkupEditor's sheets
                sr.adoptedStyleSheets = kept.concat([sheet]);
                return true;
            }

            // Try immediately — connectedCallback may have already run
            if (!injectIntoShadow()) {
                // Custom element not yet upgraded; wait for it
                var obs = new MutationObserver(function(_, o) {
                    if (injectIntoShadow()) o.disconnect();
                });
                obs.observe(document.documentElement, { childList: true, subtree: true });
            }

            // Re-apply after MarkupEditor's async init (it resets adoptedStyleSheets in connectedCallback)
            setTimeout(injectIntoShadow, 300);
        })();
        """
    }()

    // MARK: - Markdown <-> HTML Conversion

    private func markdownToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html: [String] = []
        for var line in lines {
            if line.hasPrefix("### ") {
                line = "<h3>\(applyInlineFormatting(String(line.dropFirst(4))))</h3>"
            } else if line.hasPrefix("## ") {
                line = "<h2>\(applyInlineFormatting(String(line.dropFirst(3))))</h2>"
            } else if line.hasPrefix("# ") {
                line = "<h1>\(applyInlineFormatting(String(line.dropFirst(2))))</h1>"
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                html.append("")
                continue
            } else {
                line = "<p>\(applyInlineFormatting(line))</p>"
            }
            html.append(line)
        }
        return html.joined(separator: "\n")
    }

    private func htmlToMarkdown(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<h1>", with: "# ")
        text = text.replacingOccurrences(of: "</h1>", with: "")
        text = text.replacingOccurrences(of: "<h2>", with: "## ")
        text = text.replacingOccurrences(of: "</h2>", with: "")
        text = text.replacingOccurrences(of: "<h3>", with: "### ")
        text = text.replacingOccurrences(of: "</h3>", with: "")
        text = text.replacingOccurrences(of: "<b>", with: "**")
        text = text.replacingOccurrences(of: "</b>", with: "**")
        text = text.replacingOccurrences(of: "<strong>", with: "**")
        text = text.replacingOccurrences(of: "</strong>", with: "**")
        text = text.replacingOccurrences(of: "<i>", with: "*")
        text = text.replacingOccurrences(of: "</i>", with: "*")
        text = text.replacingOccurrences(of: "<em>", with: "*")
        text = text.replacingOccurrences(of: "</em>", with: "*")
        text = text.replacingOccurrences(of: "<p>", with: "")
        text = text.replacingOccurrences(of: "</p>", with: "\n")
        text = text.replacingOccurrences(of: "<br>", with: "\n")
        text = text.replacingOccurrences(of: "<br/>", with: "\n")
        text = text.replacingOccurrences(of: "<br />", with: "\n")
        while let startRange = text.range(of: "<"),
              let endRange = text.range(of: ">", range: startRange.upperBound..<text.endIndex) {
            text.removeSubrange(startRange.lowerBound...endRange.lowerBound)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applyInlineFormatting(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*", with: "<b>$1</b>", options: .regularExpression)
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*", with: "<i>$1</i>", options: .regularExpression)
        return result
    }
}

// MARK: - EditorInputDelegate

/// Receives `markupInput` from MarkupEditor on every user keystroke,
/// async-fetches the current HTML, and publishes it for the save pipeline.
final class EditorInputDelegate: ObservableObject, MarkupDelegate {
    @Published var capturedHTML: String = ""

    func markupInput(_ view: MarkupWKWebView) {
        view.getHtml(pretty: false, clean: true) { [weak self] html in
            guard let self, let html else { return }
            DispatchQueue.main.async { self.capturedHTML = html }
        }
    }
}

// MARK: - JS Escape Helper

/// Escapes a Swift string for embedding in a JavaScript template literal.
private func escapeJSString(_ s: String) -> String {
    let escaped = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
        .replacingOccurrences(of: "$", with: "\\$")
    return "`\(escaped)`"
}

// MARK: - StarterCommandRow

struct StarterCommandRow: View {
    let item: StarterCommand

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.command)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AmplifyColors.inkPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AmplifyColors.barBg)
                )
                .frame(minWidth: 200, alignment: .leading)

            Text(item.description)
                .font(.callout)
                .foregroundStyle(AmplifyColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
