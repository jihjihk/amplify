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

        // Split on --- that act as section dividers (not frontmatter)
        // We look for lines that are just "---" (possibly with whitespace)
        let lines = content.components(separatedBy: "\n")

        var bodyLines: [String] = []
        var currentPlatformName: String? = nil
        var currentPlatformLines: [String] = []
        var foundFirstSeparator = false

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine == "---" {
                // Check if the next non-empty line is a ## heading
                var nextContentIndex = i + 1
                while nextContentIndex < lines.count && lines[nextContentIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nextContentIndex += 1
                }

                if nextContentIndex < lines.count && lines[nextContentIndex].trimmingCharacters(in: .whitespaces).hasPrefix("## ") {
                    // Save any current platform section
                    if let name = currentPlatformName {
                        platforms[name] = currentPlatformLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    // Extract platform name from ## heading
                    let heading = lines[nextContentIndex].trimmingCharacters(in: .whitespaces)
                    let platformName = String(heading.dropFirst(3)) // Remove "## "

                    currentPlatformName = platformName
                    currentPlatformLines = []
                    foundFirstSeparator = true
                    i = nextContentIndex + 1 // Skip past the heading
                    continue
                } else if !foundFirstSeparator {
                    // Not a platform separator, include in body
                    bodyLines.append(line)
                }
            } else if let _ = currentPlatformName {
                currentPlatformLines.append(line)
            } else {
                bodyLines.append(line)
            }

            i += 1
        }

        // Save the last platform section
        if let name = currentPlatformName {
            platforms[name] = currentPlatformLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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

        // Add platform sections
        for (name, content) in platformSections.sorted(by: { $0.key < $1.key }) {
            result += "\n---\n\n"
            result += "## \(name)\n\n"
            result += content + "\n"
        }

        return result
    }
}
