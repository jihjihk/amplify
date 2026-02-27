import Foundation

public enum PipelineStage: String, Codable, CaseIterable, Sendable {
    case ideas, drafts, ready, published

    public var displayName: String { rawValue.capitalized }
    public var folderName: String { rawValue }
    public var next: PipelineStage? {
        switch self {
        case .ideas: return .drafts
        case .drafts: return .ready
        case .ready: return .published
        case .published: return nil
        }
    }
}
