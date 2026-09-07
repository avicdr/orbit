import Foundation
import SwiftData

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var notes: String
    public var statusRawValue: String
    public var priorityValue: Int
    public var deadline: Date?
    public var createdAt: Date
    public var completedAt: Date?
    public var goal: Goal?
    public var orbit: Orbit?

    @Relationship(deleteRule: .nullify, inverse: \OrbitTask.project)
    public var tasks: [OrbitTask]

    public var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityValue) ?? .normal }
        set { priorityValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        goal: Goal? = nil,
        orbit: Orbit? = nil,
        status: ProjectStatus = .active,
        priority: TaskPriority = .normal,
        deadline: Date? = nil,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goal = goal
        self.orbit = goal?.orbit ?? orbit
        self.statusRawValue = status.rawValue
        self.priorityValue = priority.rawValue
        self.deadline = deadline
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.tasks = []
    }
}
