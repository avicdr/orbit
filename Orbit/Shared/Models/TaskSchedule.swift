import Foundation
import SwiftData

/// A task's single intentional placement on the planning timeline.
/// It is separate from a due date: moving a block never changes when the task is due.
@Model
public final class TaskSchedule {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var taskID: UUID
    public var startDate: Date
    public var endDate: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        startDate: Date,
        endDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.taskID = taskID
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
