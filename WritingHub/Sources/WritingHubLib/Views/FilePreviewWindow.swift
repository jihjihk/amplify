import SwiftUI
import AppKit

struct FilePreviewView: View {
    let fileURL: URL
    let session: MarkdownDocumentSession?

    var body: some View {
        Group {
            if let session {
                MarkdownDocumentEditorPane(session: session)
            } else {
                PlainTextPreview(fileURL: fileURL)
            }
        }
        .frame(minWidth: 720, minHeight: 760)
        .background(AmplifyColors.parchment)
    }
}

private struct PlainTextPreview: View {
    let fileURL: URL

    @State private var text: String = ""
    @State private var notice: String?
    @State private var watcher: FileWatcher?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileURL.deletingPathExtension().lastPathComponent)
                        .font(AmplifyFonts.title2)
                        .foregroundStyle(AmplifyColors.inkPrimary)
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AmplifyColors.inkTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AmplifyColors.barBg)

            if let notice {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(AmplifyColors.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(AmplifyColors.barBg)
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(AmplifyColors.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
            .background(AmplifyColors.surface)
        }
        .onAppear {
            reload()
            startWatcher()
        }
        .onDisappear {
            watcher?.stop()
            watcher = nil
        }
    }

    private func reload() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            notice = "\(fileURL.lastPathComponent) was removed from disk."
            return
        }

        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
            notice = nil
        } catch {
            notice = "Couldn't load \(fileURL.lastPathComponent)."
        }
    }

    private func startWatcher() {
        guard watcher == nil else { return }
        let fileWatcher = FileWatcher(path: fileURL.deletingLastPathComponent().path)
        fileWatcher.onChange = { [fileURL] in
            Task { @MainActor in
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    reload()
                }
            }
        }
        fileWatcher.start()
        watcher = fileWatcher
    }
}

@MainActor
enum FilePreviewWindowManager {
    private static var controllers: [String: NSWindowController] = [:]

    static func present(fileURL: URL, session: MarkdownDocumentSession?) {
        let key = fileURL.standardizedFileURL.path

        if let controller = controllers[key], let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = FilePreviewView(fileURL: fileURL, session: session)
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = fileURL.lastPathComponent
        window.setContentSize(NSSize(width: 720, height: 760))
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor.windowBackgroundColor

        let controller = NSWindowController(window: window)
        controllers[key] = controller

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                controllers.removeValue(forKey: key)
            }
        }

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
