import Foundation
import SwiftData

@Model
public final class FocusSession {
    @Attribute(.unique) public var id: UUID
    public var startDate: Date
    public var endDate: Date?
    public var plannedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var interruptions: Int
    public var completed: Bool
    public var perceivedDifficultyRawValue: String?
    public var task: OrbitTask?

    public var perceivedDifficulty: PerceivedDifficulty? {
        get { perceivedDifficultyRawValue.flatMap(PerceivedDifficulty.init(rawValue:)) }
        set { perceivedDifficultyRawValue = newValue?.rawValue }
    }

    public init(
        id: UUID = UUID(),
        task: OrbitTask? = nil,
        startDate: Date = .now,
        endDate: Date? = nil,
        plannedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        interruptions: Int = 0,
        completed: Bool = false,
        perceivedDifficulty: PerceivedDifficulty? = nil
    ) {
        self.id = id
        self.task = task
        self.startDate = startDate
        self.endDate = endDate
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.interruptions = interruptions
        self.completed = completed
        self.perceivedDifficultyRawValue = perceivedDifficulty?.rawValue
    }
}
