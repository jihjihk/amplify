import Foundation

public struct FrontMatter: Codable, Sendable {
    public var title: String?
    public var created: String?
    public var edited: String?
    public var version: Int?
    public var platforms: [String]?

    public init(
        title: String? = nil,
        created: String? = nil,
        edited: String? = nil,
        version: Int? = nil,
        platforms: [String]? = nil
    ) {
        self.title = title
        self.created = created
        self.edited = edited
        self.version = version
        self.platforms = platforms
    }
}
