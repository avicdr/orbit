import Foundation
import SwiftData

@Model
public final class Goal {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var notes: String
    public var priorityValue: Int
    public var targetDate: Date?
    public var progress: Double
    public var statusRawValue: String
    public var createdAt: Date
    public var completedAt: Date?
    public var orbit: Orbit?

    @Relationship(deleteRule: .nullify, inverse: \Project.goal)
    public var projects: [Project]

    @Relationship(deleteRule: .nullify, inverse: \OrbitTask.goal)
    public var tasks: [OrbitTask]

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityValue) ?? .normal }
        set { priorityValue = newValue.rawValue }
    }

    public var status: GoalStatus {
        get { GoalStatus(rawValue: statusRawValue) ?? .active }
        set { statusRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        orbit: Orbit? = nil,
        priority: TaskPriority = .normal,
        targetDate: Date? = nil,
        progress: Double = 0,
        status: GoalStatus = .active,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.orbit = orbit
        self.priorityValue = priority.rawValue
        self.targetDate = targetDate
        self.progress = progress
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.projects = []
        self.tasks = []
    }
}
