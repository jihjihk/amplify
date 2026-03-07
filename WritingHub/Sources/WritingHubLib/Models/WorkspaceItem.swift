import Foundation

public struct WorkspaceItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let path: URL
    public let isDirectory: Bool
    public var children: [WorkspaceItem]

    public init(name: String, path: URL, isDirectory: Bool, children: [WorkspaceItem] = []) {
        self.id = path.path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.children = children
    }
}
