import Foundation
import SwiftData

@Model
public final class OrbitTask {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var notes: String
    public var statusRawValue: String
    public var priorityValue: Int
    public var dueDate: Date?
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var energyRequirementRawValue: String?
    public var locationRequirement: String?
    public var recurrenceRawValue: String?
    public var createdAt: Date
    public var completedAt: Date?
    public var project: Project?
    public var goal: Goal?
    public var orbit: Orbit?
    public var context: TaskContext?

    @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
    public var focusSessions: [FocusSession]

    // Dependency enforcement is handled by the domain service in later milestones.
    @Relationship(deleteRule: .nullify)
    public var dependencies: [OrbitTask]

    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .inbox }
        set { statusRawValue = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityValue) ?? .normal }
        set { priorityValue = newValue.rawValue }
    }

    public var energyRequirement: EnergyLevel? {
        get { energyRequirementRawValue.flatMap(EnergyLevel.init(rawValue:)) }
        set { energyRequirementRawValue = newValue?.rawValue }
    }

    public var recurrence: TaskRecurrence? {
        get { recurrenceRawValue.flatMap(TaskRecurrence.init(rawValue:)) }
        set { recurrenceRawValue = newValue?.rawValue }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        status: TaskStatus = .inbox,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        energyRequirement: EnergyLevel? = nil,
        context: TaskContext? = nil,
        locationRequirement: String? = nil,
        project: Project? = nil,
        goal: Goal? = nil,
        orbit: Orbit? = nil,
        recurrence: TaskRecurrence? = nil,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.statusRawValue = status.rawValue
        self.priorityValue = priority.rawValue
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.energyRequirementRawValue = energyRequirement?.rawValue
        self.context = context
        self.locationRequirement = locationRequirement
        self.project = project
        self.goal = project?.goal ?? goal
        self.orbit = project?.orbit ?? project?.goal?.orbit ?? goal?.orbit ?? orbit
        self.recurrenceRawValue = recurrence?.rawValue
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.focusSessions = []
        self.dependencies = []
    }
}
