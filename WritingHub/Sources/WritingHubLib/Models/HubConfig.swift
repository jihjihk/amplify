import Foundation

/// Configuration stored in `.writinghub/config.json`.
/// This file is the canonical source of truth for a workspace's identity —
/// name and skill pack — so reopening the folder restores the setup without
/// going through onboarding again.
public struct HubConfig: Codable, Sendable {
    public var name: String
    public var skillPack: SkillPack
    public var useCase: String
    public var didPromptToLinkLegacyClaudeInstructions: Bool

    public init(
        name: String = "you",
        skillPack: SkillPack = .founder,
        useCase: String = "",
        didPromptToLinkLegacyClaudeInstructions: Bool = false
    ) {
        self.name = name
        self.skillPack = skillPack
        self.useCase = useCase
        self.didPromptToLinkLegacyClaudeInstructions = didPromptToLinkLegacyClaudeInstructions
    }

    enum CodingKeys: String, CodingKey {
        case name
        case skillPack
        case useCase
        case didPromptToLinkLegacyClaudeInstructions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "you"
        skillPack = try container.decodeIfPresent(SkillPack.self, forKey: .skillPack) ?? .founder
        useCase = try container.decodeIfPresent(String.self, forKey: .useCase) ?? ""
        didPromptToLinkLegacyClaudeInstructions =
            try container.decodeIfPresent(Bool.self, forKey: .didPromptToLinkLegacyClaudeInstructions) ?? false
    }

    /// Load config from `.writinghub/config.json`. Returns nil if not found.
    public static func load(from root: URL) -> HubConfig? {
        let configPath = root.appendingPathComponent(".writinghub/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(HubConfig.self, from: data)
        else { return nil }
        return config
    }

    /// Save config to `.writinghub/config.json`.
    public func save(to root: URL) {
        let configPath = root.appendingPathComponent(".writinghub/config.json")
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: configPath)
    }
}
