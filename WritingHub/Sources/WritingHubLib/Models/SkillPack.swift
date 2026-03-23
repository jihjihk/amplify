import Foundation

public struct StarterCommand: Sendable {
    public let command: String
    public let description: String
}

/// A skill pack defines the folder structure, CLAUDE.md template, and onboarding
/// next-steps tailored to a specific type of writing workflow.
public enum SkillPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case founder
    case gstack
    case blank

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .founder: return "Founder / Audience Builder"
        case .gstack: return "gstack"
        case .blank: return "Blank Workspace"
        }
    }

    public var tagline: String {
        switch self {
        case .founder:
            return "Content strategy, thought leadership, multi-platform publishing"
        case .gstack:
            return "Garry Tan's Claude Code workflow — CEO, designer, eng manager, QA, and shipping in one"
        case .blank:
            return "Empty workspace with CLAUDE.md — bring your own structure"
        }
    }

    public var icon: String {
        switch self {
        case .founder: return "chart.line.uptrend.xyaxis"
        case .gstack: return "hammer.fill"
        case .blank: return "doc.text"
        }
    }

    /// Whether this boilerplate is writing-focused (shows the use-case question).
    public var asksForUseCase: Bool {
        switch self {
        case .founder: return true
        case .gstack, .blank: return false
        }
    }

    /// Folders to create during scaffolding.
    public var folders: [String] {
        switch self {
        case .founder:
            return ["ideas", "drafts", "published", "references"]
        case .gstack:
            return []
        case .blank:
            return []
        }
    }

    /// Next steps shown after scaffolding.
    public var nextSteps: [String] {
        switch self {
        case .founder:
            return [
                "1. Drop past writing into references/",
                "2. Run \"create voice dna\" in the terminal",
                "3. Run \"create content strategy\" to plan your content",
            ]
        case .gstack:
            return [
                "1. Run: claude install-skill garrytan/gstack",
                "2. Type /office-hours to brainstorm",
                "3. Type /ship when you're ready to land a PR",
            ]
        case .blank:
            return [
                "1. Create your first .md file",
                "2. Start writing in the terminal with Claude",
            ]
        }
    }

    /// Commands shown on the getting-started placeholder in the editor.
    public var starterCommands: [StarterCommand] {
        switch self {
        case .founder:
            return [
                StarterCommand(command: "create voice dna", description: "Analyze your reference writing and build a voice profile"),
                StarterCommand(command: "create content strategy", description: "Build a structured strategy: content lanes, platforms, cadence"),
                StarterCommand(command: "brainstorm [topic]", description: "Generate 10 angles and hooks for any topic"),
                StarterCommand(command: "draft [file]", description: "Write a full first draft in your voice"),
                StarterCommand(command: "edit [file]", description: "Tighten a draft — shows before/after diffs"),
                StarterCommand(command: "replicate [file]", description: "Adapt a piece for X, LinkedIn, Substack"),
            ]
        case .gstack:
            return [
                StarterCommand(command: "claude install-skill garrytan/gstack", description: "Install gstack (run this first)"),
                StarterCommand(command: "/office-hours", description: "Brainstorm and validate ideas"),
                StarterCommand(command: "/plan-ceo-review", description: "CEO-level strategy review of your plan"),
                StarterCommand(command: "/review", description: "Pre-landing code review"),
                StarterCommand(command: "/ship", description: "Create PR, bump version, push"),
                StarterCommand(command: "/qa", description: "Automated QA testing"),
            ]
        case .blank:
            return [
                StarterCommand(command: "help me write about [topic]", description: "Start a conversation about any topic"),
                StarterCommand(command: "create voice dna", description: "Build a voice profile from your writing samples"),
            ]
        }
    }

    /// Generates a personalized CLAUDE.md for this skill pack.
    public func claudeTemplate(name: String, useCase: String) -> String {
        switch self {
        case .founder:
            return CLAUDETemplate.generate(name: name, useCase: useCase)
        case .gstack:
            return CLAUDETemplate.generateGstack(name: name)
        case .blank:
            return CLAUDETemplate.generateBlank(name: name)
        }
    }
}
