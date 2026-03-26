import SwiftUI
import AppKit
import MarkupEditor

@MainActor
final class MarkdownTextEditorController: ObservableObject {
    weak var webView: MarkupWKWebView?

    func attach(_ webView: MarkupWKWebView) {
        self.webView = webView
    }

    func findText(_ query: String, forward: Bool = true) {
        guard !query.isEmpty, let webView else { return }
        webView.search(for: query, direction: forward ? .forward : .backward, activate: true, handler: nil)
    }

    func setParagraphStyle() {
        webView?.pStyle()
    }

    func setHeading(level: Int) {
        switch level {
        case 1: webView?.h1Style()
        case 2: webView?.h2Style()
        case 3: webView?.h3Style()
        default: break
        }
    }

    func toggleBold() { webView?.bold(handler: nil) }
    func toggleItalic() { webView?.italic(handler: nil) }
    func toggleCode() { webView?.code(handler: nil) }
    func toggleBullets() { webView?.bullets() }
    func toggleNumbers() { webView?.numbers() }
    func indent() { webView?.indent(handler: nil) }
    func outdent() { webView?.outdent(handler: nil) }
    func undo() { webView?.undo(handler: nil) }
    func redo() { webView?.redo(handler: nil) }
}

@MainActor
final class MarkdownMarkupBridge: NSObject, ObservableObject, MarkupDelegate {
    private weak var session: MarkdownDocumentSession?
    private weak var controller: MarkdownTextEditorController?
    private var didCaptureInitialEditorHTML = false

    func configure(session: MarkdownDocumentSession, controller: MarkdownTextEditorController) {
        self.session = session
        self.controller = controller
        self.didCaptureInitialEditorHTML = false
    }

    func markupDidLoad(_ view: MarkupWKWebView, handler: (() -> Void)?) {
        controller?.attach(view)
        MarkupEditor.selectedWebView = view
        view.getHtml(pretty: true, clean: true, divID: nil) { [weak self] html in
            guard let self, let session, let html else { return }
            Task { @MainActor in
                session.synchronizeLoadedHTML(html)
                self.didCaptureInitialEditorHTML = true
            }
        }
        handler?()
    }

    func markupTookFocus(_ view: MarkupWKWebView) {
        controller?.attach(view)
        MarkupEditor.selectedWebView = view
    }

    func markupInput(_ view: MarkupWKWebView) {
        controller?.attach(view)
        view.getHtml(pretty: true, clean: true, divID: nil) { [weak self] html in
            guard let self, let session else { return }
            Task { @MainActor in
                guard self.didCaptureInitialEditorHTML else {
                    if let html {
                        session.synchronizeLoadedHTML(html)
                        self.didCaptureInitialEditorHTML = true
                    }
                    return
                }
                session.updateHTML(html ?? "")
            }
        }
    }
}

struct MarkdownDocumentEditorPane: View {
    @ObservedObject var session: MarkdownDocumentSession
    @StateObject private var controller = MarkdownTextEditorController()
    @StateObject private var bridge = MarkdownMarkupBridge()
    @State private var showFind = false
    @State private var findQuery = ""
    @FocusState private var findFieldFocused: Bool
    private let markupConfiguration: MarkupWKWebViewConfiguration = {
        let configuration = MarkupWKWebViewConfiguration()
        configuration.userCssFile = "markdown-editor.css"
        configuration.userResourceFiles = [
            "Fonts/InstrumentSerif-Regular.ttf",
            "Fonts/InstrumentSerif-Italic.ttf"
        ]
        return configuration
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                formattingBar

                if let notice = session.notice {
                    noticeBar(notice)
                }

                MarkupEditorBridge(session: session, controller: controller, bridge: bridge, configuration: markupConfiguration)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }

            if showFind {
                FindBar(
                    query: $findQuery,
                    isFocused: $findFieldFocused,
                    onNext: { controller.findText(findQuery, forward: true) },
                    onPrev: { controller.findText(findQuery, forward: false) },
                    onDismiss: {
                        withAnimation { showFind = false }
                        findQuery = ""
                    }
                )
                .padding(.top, 48)
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .background(Color.white)
        .background(
            Button("") {
                withAnimation(.easeInOut(duration: 0.15)) { showFind.toggle() }
                if showFind {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        findFieldFocused = true
                    }
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .hidden()
        )
        .onAppear {
            AmplifyFonts.registerIfNeeded()
            MarkupEditor.toolbarLocation = .none
            bridge.configure(session: session, controller: controller)
            session.startIfNeeded()
        }
    }

    private var formattingBar: some View {
        HStack(spacing: 8) {
            toolbarButton("P") { controller.setParagraphStyle() }
            toolbarButton("H1") { controller.setHeading(level: 1) }
            toolbarButton("H2") { controller.setHeading(level: 2) }
            toolbarButton("H3") { controller.setHeading(level: 3) }
            Divider().frame(height: 16)
            toolbarButton("B") { controller.toggleBold() }
            toolbarButton("I") { controller.toggleItalic() }
            toolbarButton("{ }") { controller.toggleCode() }
            Divider().frame(height: 16)
            toolbarButton("•") { controller.toggleBullets() }
            toolbarButton("1.") { controller.toggleNumbers() }
            toolbarButton("→") { controller.indent() }
            toolbarButton("←") { controller.outdent() }
            Divider().frame(height: 16)
            toolbarButton("↶") { controller.undo() }
            toolbarButton("↷") { controller.redo() }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AmplifyColors.barBg)
    }

    private func toolbarButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AmplifyColors.inkPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AmplifyColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AmplifyColors.inkTertiary.opacity(0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func noticeBar(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(AmplifyColors.inkSecondary)
                .lineLimit(2)

            Spacer()

            Button("Reload") {
                session.reloadFromDisk()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AmplifyColors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AmplifyColors.barBg)
    }
}

private struct MarkupEditorBridge: View {
    @ObservedObject var session: MarkdownDocumentSession
    @ObservedObject var controller: MarkdownTextEditorController
    @ObservedObject var bridge: MarkdownMarkupBridge
    let configuration: MarkupWKWebViewConfiguration

    var body: some View {
        RichMarkupEditorView(
            html: $session.html,
            isDirty: session.isDirty,
            markupDelegate: bridge,
            configuration: configuration,
            placeholder: "Start writing…",
            id: session.fileURL.standardizedFileURL.path
        )
        .background(Color.white)
    }
}

private struct RichMarkupEditorView: NSViewRepresentable {
    @Binding var html: String
    let isDirty: Bool
    let markupDelegate: MarkupDelegate
    let configuration: MarkupWKWebViewConfiguration
    let placeholder: String
    let id: String

    func makeCoordinator() -> MarkupCoordinator {
        MarkupCoordinator(markupDelegate: markupDelegate)
    }

    func makeNSView(context: Context) -> MarkupWKWebView {
        let webView = MarkupWKWebView(
            html: html,
            placeholder: placeholder,
            selectAfterLoad: true,
            resourcesUrl: Bundle.module.resourceURL,
            id: id,
            markupDelegate: markupDelegate,
            configuration: configuration
        )
        webView.setCoordinatorConfiguration(context.coordinator)
        context.coordinator.webView = webView
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 13.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        return webView
    }

    func updateNSView(_ webView: MarkupWKWebView, context: Context) {
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 13.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        // Avoid re-injecting the whole document while the user is actively editing.
        // That resets the browser selection/caret and shows up as the cursor jumping.
        if !isDirty {
            webView.setHtmlIfChanged(html)
        }
    }
}
