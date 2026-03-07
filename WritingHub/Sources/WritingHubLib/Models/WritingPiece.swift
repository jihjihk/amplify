import Foundation
import Yams

public struct WritingPiece: Sendable {
    public var frontMatter: FrontMatter
    public var body: String
    public var platformSections: [String: String]
    public var filePath: URL?

    public init(
        frontMatter: FrontMatter = FrontMatter(),
        body: String = "",
        platformSections: [String: String] = [:],
        filePath: URL? = nil
    ) {
        self.frontMatter = frontMatter
        self.body = body
        self.platformSections = platformSections
        self.filePath = filePath
    }

    // MARK: - Parsing

    public static func parse(from content: String) throws -> WritingPiece {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        var frontMatter = FrontMatter()
        var bodyContent = trimmed
        var platformSections: [String: String] = [:]

        // Check for frontmatter delimiters
        if trimmed.hasPrefix("---") {
            let lines = trimmed.components(separatedBy: "\n")
            // Find the closing --- (skip the first line which is the opening ---)
            if let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) {
                // Extract YAML between the two --- markers
                let yamlLines = lines[1..<closingIndex]
                let yamlString = yamlLines.joined(separator: "\n")

                let decoder = YAMLDecoder()
                frontMatter = try decoder.decode(FrontMatter.self, from: yamlString)

                // Everything after the closing --- is the rest of the content
                let afterFrontmatter = lines[(closingIndex + 1)...].joined(separator: "\n")
                bodyContent = afterFrontmatter.trimmingCharacters(in: .newlines)
            }
        }

        // Split body into main content and platform sections
        // Platform sections are separated by --- followed by ## Platform Name
        let sectionParts = splitPlatformSections(from: bodyContent)
        let mainBody = sectionParts.body
        platformSections = sectionParts.platforms

        return WritingPiece(
            frontMatter: frontMatter,
            body: mainBody,
            platformSections: platformSections
        )
    }

    // MARK: - Platform Section Splitting

    private static func splitPlatformSections(from content: String) -> (body: String, platforms: [String: String]) {
        var platforms: [String: String] = [:]
        let lines = content.components(separatedBy: "\n")

        // Find the "## Platform Versions" marker — only content after this marker
        // is treated as platform sections. This avoids misinterpreting normal markdown
        // horizontal rules (---) followed by ## headings as platform sections.
        var markerIndex: Int? = nil
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "## Platform Versions" {
                markerIndex = i
                break
            }
        }

        guard let marker = markerIndex else {
            // No platform versions section — everything is body
            return (body: content, platforms: [:])
        }

        // Body is everything before the marker
        let bodyLines = Array(lines[0..<marker])
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse platform sub-sections after the marker
        var currentPlatformName: String? = nil
        var currentPlatformLines: [String] = []

        for i in (marker + 1)..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                // Save previous platform section
                if let name = currentPlatformName {
                    platforms[name] = currentPlatformLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentPlatformName = String(trimmed.dropFirst(3))
                currentPlatformLines = []
            } else if trimmed == "---" {
                // Section divider between platforms — skip
                continue
            } else if currentPlatformName != nil {
                currentPlatformLines.append(line)
            }
        }

        // Save the last platform section
        if let name = currentPlatformName {
            platforms[name] = currentPlatformLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (body: body, platforms: platforms)
    }

    // MARK: - Serialization

    public func serialize() -> String {
        var result = ""

        // Serialize frontmatter
        let encoder = YAMLEncoder()
        if let yamlString = try? encoder.encode(frontMatter) {
            let trimmedYaml = yamlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedYaml.isEmpty {
                result += "---\n"
                result += trimmedYaml + "\n"
                result += "---\n"
            }
        }

        // Add body
        if !body.isEmpty {
            result += "\n" + body + "\n"
        }

        // Add platform sections under a marker heading
        if !platformSections.isEmpty {
            result += "\n## Platform Versions\n"
            for (name, content) in platformSections.sorted(by: { $0.key < $1.key }) {
                result += "\n## \(name)\n\n"
                result += content + "\n"
            }
        }

        return result
    }
}
