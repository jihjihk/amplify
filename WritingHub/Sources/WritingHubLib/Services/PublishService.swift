import AppKit
import Foundation

public struct PublishService {
    public static let platformURLs: [String: String] = [
        "x": "https://twitter.com/compose/tweet",
        "linkedin": "https://www.linkedin.com/feed/?shareActive=true",
        "substack": ""  // no compose URL
    ]

    /// Copy the platform-specific section (or main body) to the clipboard
    /// and open the platform's compose URL in the default browser.
    public static func publish(piece: WritingPiece, platform: String) {
        // Extract platform section content, fall back to main body
        let content: String
        if let section = piece.platformSections[platform], !section.isEmpty {
            content = section
        } else {
            content = piece.body
        }

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        // Open platform URL in browser (if one exists)
        if let urlString = platformURLs[platform.lowercased()],
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
