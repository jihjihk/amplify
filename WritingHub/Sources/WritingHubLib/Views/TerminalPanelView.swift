import SwiftUI
import SwiftTerm
import AppKit

/// An NSViewRepresentable that wraps SwiftTerm's LocalProcessTerminalView
/// to provide an embedded terminal panel for running CLI tools such as Claude Code.
public struct TerminalPanelView: NSViewRepresentable {
    public let folderPath: URL

    public init(folderPath: URL) {
        self.folderPath = folderPath
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Style: monospace font 13pt
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Style: dark background, light foreground
        terminalView.nativeBackgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        terminalView.nativeForegroundColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)

        // Start a zsh process, cd to the folder, and clear the screen
        let directory = folderPath.path
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: [],
            environment: Terminal.getEnvironmentVariables(termName: "xterm-256color"),
            execName: nil,
            currentDirectory: directory
        )

        // Send a clear command so the terminal starts clean
        let clearCommand = Array("clear\n".utf8)
        terminalView.send(source: terminalView, data: clearCommand[...])

        return terminalView
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No dynamic updates needed
    }
}
