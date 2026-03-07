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

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Style: monospace font 13pt
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Style: warm walnut dark background, parchment foreground
        terminalView.nativeBackgroundColor = AmplifyColors.terminalBg
        terminalView.nativeForegroundColor = AmplifyColors.terminalFg

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

        // Store reference for focus management
        context.coordinator.terminalView = terminalView

        // Schedule focus after the view is fully in the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        return terminalView
    }

    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // No dynamic updates needed
    }

    public class Coordinator {
        var terminalView: LocalProcessTerminalView?
    }
}
