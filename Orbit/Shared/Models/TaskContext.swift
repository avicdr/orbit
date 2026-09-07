import Foundation
import SwiftData

@Model
public final class TaskContext {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var kindRawValue: String
    public var createdAt: Date

    public var kind: ContextKind {
        get { ContextKind(rawValue: kindRawValue) ?? .custom }
        set { kindRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: ContextKind = .custom,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.createdAt = createdAt
    }
}
