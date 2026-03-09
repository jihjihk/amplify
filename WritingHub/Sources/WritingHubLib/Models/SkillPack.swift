import Foundation

/// A single command shown on the getting-started screen.
public struct StarterCommand: Sendable {
    public let command: String
    public let description: String
}

/// A skill pack defines the folder structure and CLAUDE.md template
/// tailored to a specific type of writer.
public enum SkillPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case founder
    case hobbyWriter
    case marketingManager

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .founder: return "Founder / Audience Builder"
        case .hobbyWriter: return "Hobby Writer"
        case .marketingManager: return "Marketing Manager"
        }
    }

    public var description: String {
        switch self {
        case .founder:
            return "Content strategy, thought leadership, audience growth"
        case .hobbyWriter:
            return "Personal essays, blog posts, creative writing"
        case .marketingManager:
            return "Strategy docs, campaign plans, multi-platform content"
        }
    }

    public var icon: String {
        switch self {
        case .founder: return "chart.line.uptrend.xyaxis"
        case .hobbyWriter: return "pencil.line"
        case .marketingManager: return "megaphone"
        }
    }

    /// Folders to create during scaffolding.
    public var folders: [String] {
        switch self {
        case .founder:
            return ["ideas", "drafts", "published", "references"]
        case .hobbyWriter:
            return ["drafts", "published", "references"]
        case .marketingManager:
            return ["strategy", "campaigns", "content", "references"]
        }
    }

    /// Commands shown on the getting-started screen, in suggested order.
    public var starterCommands: [StarterCommand] {
        switch self {
        case .founder:
            return [
                StarterCommand(command: "create voice dna", description: "Analyze your reference writing and build a voice profile Claude will use for everything it writes"),
                StarterCommand(command: "create content strategy", description: "Build a structured strategy: content lanes, platforms, cadence, and success signals"),
                StarterCommand(command: "brainstorm [topic]", description: "Generate 10 angles and hooks for any topic — saved to ideas/"),
                StarterCommand(command: "draft [file]", description: "Write a full first draft from an idea file in your voice"),
                StarterCommand(command: "edit [file]", description: "Tighten and improve a draft — shows before/after diffs"),
                StarterCommand(command: "replicate [file]", description: "Adapt a piece for X, LinkedIn, Substack — all formats at once"),
            ]
        case .hobbyWriter:
            return [
                StarterCommand(command: "create voice dna", description: "Analyze your reference writing and build a voice profile Claude will use for everything it writes"),
                StarterCommand(command: "draft [topic or file]", description: "Write a full first draft in your voice"),
                StarterCommand(command: "edit [file]", description: "Tighten and improve a draft — shows before/after diffs"),
                StarterCommand(command: "critique [file]", description: "Get honest feedback on argument, structure, and voice — no rewriting, just notes"),
            ]
        case .marketingManager:
            return [
                StarterCommand(command: "create content strategy", description: "Build a full strategy doc: positioning, content lanes, platforms, cadence"),
                StarterCommand(command: "create voice dna", description: "Analyze reference material to build a brand voice profile"),
                StarterCommand(command: "brainstorm [topic]", description: "Generate 10 campaign angles or content hooks for any topic"),
                StarterCommand(command: "draft [file]", description: "Write a full piece — brief, post, or strategy section"),
                StarterCommand(command: "replicate [file]", description: "Adapt content for X, LinkedIn, Substack simultaneously"),
            ]
        }
    }

    /// Generates a personalized CLAUDE.md for this skill pack.
    public func claudeTemplate(name: String, useCase: String) -> String {
        CLAUDETemplate.generate(name: name, useCase: useCase)
    }
}
