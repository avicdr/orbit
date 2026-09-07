import Foundation

public enum GoalStatus: String, CaseIterable, Codable, Sendable {
    case active
    case completed
    case paused
    case cancelled
}

public enum ProjectStatus: String, CaseIterable, Codable, Sendable {
    case active
    case completed
    case onHold
    case cancelled
}

public enum TaskStatus: String, CaseIterable, Codable, Sendable {
    case inbox
    case planned
    case inProgress
    case completed
    case cancelled
}

public enum TaskPriority: Int, CaseIterable, Codable, Sendable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum EnergyLevel: String, CaseIterable, Codable, Sendable, Comparable {
    case drained
    case low
    case okay
    case good
    case high

    public static func < (lhs: EnergyLevel, rhs: EnergyLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    public var rank: Int {
        switch self {
        case .drained: 0
        case .low: 1
        case .okay: 2
        case .good: 3
        case .high: 4
        }
    }
}

public enum ContextKind: String, CaseIterable, Codable, Sendable, Hashable {
    case home
    case office
    case campus
    case commute
    case outdoors
    case anywhere
    case custom
}

public enum TaskRecurrence: String, CaseIterable, Codable, Sendable {
    case daily
    case weekdays
    case weekly
    case monthly
}

public enum PerceivedDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case normal
    case hard
}
