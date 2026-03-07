import SwiftUI
import AppKit
import WritingHubLib

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        AmplifyFonts.registerIfNeeded()
        applyWindowBackground()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyWindowBackground()
    }

    @MainActor private func applyWindowBackground() {
        let bg = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 26/255, green: 23/255, blue: 19/255, alpha: 1)
                : NSColor(red: 242/255, green: 237/255, blue: 228/255, alpha: 1)
        }
        for window in NSApp.windows {
            window.backgroundColor = bg
        }
    }
}

@main
struct WritingHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register before SwiftUI computes any view body so .custom() resolves correctly.
        AmplifyFonts.registerIfNeeded()
    }

    var body: some Scene {
        // WindowGroup supports multiple windows on macOS out of the box.
        // Use File > New Window (⌘N) to open a second workspace.
        // Each window gets its own HubViewModel, so multiple workspaces can be open simultaneously.
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    NSApp.sendAction(#selector(NSWindowController.newWindowForTab(_:)), to: nil, from: nil)
                    if let newWindow = NSApp.windows.last {
                        newWindow.makeKeyAndOrderFront(nil)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
