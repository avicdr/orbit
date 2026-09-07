import Foundation
import SwiftData

@Model
public final class Orbit {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var icon: String
    public var colorToken: String
    public var orbitDescription: String
    public var weight: Double
    public var createdAt: Date
    public var archivedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Goal.orbit)
    public var goals: [Goal]

    @Relationship(deleteRule: .nullify, inverse: \Project.orbit)
    public var projects: [Project]

    @Relationship(deleteRule: .nullify, inverse: \OrbitTask.orbit)
    public var tasks: [OrbitTask]

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "circle.grid.2x2",
        colorToken: String = "accent",
        description: String = "",
        weight: Double = 1,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorToken = colorToken
        self.orbitDescription = description
        self.weight = weight
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.goals = []
        self.projects = []
        self.tasks = []
    }
}
