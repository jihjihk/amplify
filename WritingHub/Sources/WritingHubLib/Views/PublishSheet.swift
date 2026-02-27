import SwiftUI

public struct PublishSheet: View {
    public let piece: WritingPiece
    public let onPublish: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(piece: WritingPiece, onPublish: @escaping (String) -> Void) {
        self.piece = piece
        self.onPublish = onPublish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Publish to...")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            let platforms = piece.frontMatter.platforms ?? []

            if platforms.isEmpty {
                Text("No platforms configured in frontmatter.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(platforms, id: \.self) { platform in
                    Button {
                        onPublish(platform)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(iconFor(platform))
                                .font(.title3)
                                .frame(width: 28, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(platform.capitalized)
                                    .fontWeight(.medium)

                                if piece.platformSections[platform] != nil {
                                    Text("Ready")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("No section \u{2014} will copy main body")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    // MARK: - Helpers

    private func iconFor(_ platform: String) -> String {
        switch platform.lowercased() {
        case "x":
            return "\u{1D54F}"  // mathematical double-struck capital X
        case "linkedin":
            return "in"
        case "substack":
            return "\u{2709}\u{FE0F}"  // envelope emoji
        default:
            return "\u{1F4DD}"  // memo emoji
        }
    }
}
