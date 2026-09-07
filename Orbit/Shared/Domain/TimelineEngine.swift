import Foundation

public struct TimelineScheduledTask: Identifiable, Equatable, Sendable {
    public let taskID: UUID
    public let title: String
    public let startDate: Date
    public let endDate: Date

    public var id: UUID { taskID }

    public init(taskID: UUID, title: String, startDate: Date, endDate: Date) {
        self.taskID = taskID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}

public enum TimelineEntryKind: String, Equatable, Sendable {
    case calendarCommitment
    case task
}

public struct TimelineEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let interval: DateInterval
    public let kind: TimelineEntryKind
    public let taskID: UUID?
}

public struct TimelineConflict: Identifiable, Equatable, Sendable {
    public let id: String
    public let proposedTaskID: UUID
    public let conflictingEntryID: String
    public let conflictingTitle: String
    public let conflictingKind: TimelineEntryKind

    public init(proposedTaskID: UUID, conflicting: TimelineEntry) {
        self.id = "\(proposedTaskID.uuidString):\(conflicting.id)"
        self.proposedTaskID = proposedTaskID
        self.conflictingEntryID = conflicting.id
        self.conflictingTitle = conflicting.title
        self.conflictingKind = conflicting.kind
    }
}

public struct TimelineDay: Equatable, Sendable {
    public let entries: [TimelineEntry]
    public let freeWindows: [DateInterval]
    public let conflicts: [TimelineConflict]
}

public struct TimelineMoveProposal: Equatable, Sendable {
    public let taskID: UUID
    public let interval: DateInterval
    public let conflicts: [TimelineConflict]

    /// Orbit never automatically shifts other work; overlap is always confirmed by the person.
    public var requiresConfirmation: Bool { !conflicts.isEmpty }
}

/// Deterministic macOS planning math. UI drag/drop and SwiftData writes stay outside this type.
public struct TimelineEngine: Sendable {
    public init() {}

    public func day(
        window: DateInterval,
        scheduledTasks: [TimelineScheduledTask],
        calendarCommitments: [CalendarAvailability] = []
    ) -> TimelineDay {
        let entries = entries(scheduledTasks: scheduledTasks, calendarCommitments: calendarCommitments)
            .compactMap { entry in clipped(entry, to: window) }
            .sorted { $0.interval.start < $1.interval.start }
        return TimelineDay(
            entries: entries,
            freeWindows: subtract(merged(entries.map(\.interval)), from: window),
            conflicts: conflicts(in: entries)
        )
    }

    public func proposeMove(
        taskID: UUID,
        startDate: Date,
        duration: TimeInterval,
        scheduledTasks: [TimelineScheduledTask],
        calendarCommitments: [CalendarAvailability] = []
    ) -> TimelineMoveProposal? {
        guard duration > 0 else { return nil }
        let interval = DateInterval(start: startDate, duration: duration)
        let existing = entries(scheduledTasks: scheduledTasks, calendarCommitments: calendarCommitments)
        let conflicts = existing.compactMap { entry -> TimelineConflict? in
            guard entry.taskID != taskID, overlaps(entry.interval, interval) else { return nil }
            return TimelineConflict(proposedTaskID: taskID, conflicting: entry)
        }
        return TimelineMoveProposal(taskID: taskID, interval: interval, conflicts: conflicts)
    }

    private func entries(
        scheduledTasks: [TimelineScheduledTask],
        calendarCommitments: [CalendarAvailability]
    ) -> [TimelineEntry] {
        let tasks = scheduledTasks.compactMap { task -> TimelineEntry? in
            guard task.endDate > task.startDate else { return nil }
            return TimelineEntry(
                id: "task:\(task.taskID.uuidString)",
                title: task.title,
                interval: DateInterval(start: task.startDate, end: task.endDate),
                kind: .task,
                taskID: task.taskID
            )
        }
        let calendar = calendarCommitments.compactMap { commitment -> TimelineEntry? in
            guard commitment.endDate > commitment.startDate else { return nil }
            return TimelineEntry(
                id: "calendar:\(commitment.id)",
                title: "Calendar commitment",
                interval: DateInterval(start: commitment.startDate, end: commitment.endDate),
                kind: .calendarCommitment,
                taskID: nil
            )
        }
        return tasks + calendar
    }

    private func conflicts(in entries: [TimelineEntry]) -> [TimelineConflict] {
        var result: [TimelineConflict] = []
        for (index, entry) in entries.enumerated() where entry.kind == .task {
            for candidate in entries.dropFirst(index + 1) where overlaps(entry.interval, candidate.interval) {
                guard let taskID = entry.taskID else { continue }
                result.append(TimelineConflict(proposedTaskID: taskID, conflicting: candidate))
            }
        }
        return result
    }

    private func clipped(_ entry: TimelineEntry, to window: DateInterval) -> TimelineEntry? {
        guard let interval = entry.interval.intersection(with: window), interval.duration > 0 else { return nil }
        return TimelineEntry(id: entry.id, title: entry.title, interval: interval, kind: entry.kind, taskID: entry.taskID)
    }

    private func overlaps(_ lhs: DateInterval, _ rhs: DateInterval) -> Bool {
        lhs.start < rhs.end && rhs.start < lhs.end
    }

    private func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        intervals.sorted { $0.start < $1.start }.reduce(into: [DateInterval]()) { result, interval in
            guard let last = result.last else { result.append(interval); return }
            if interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
    }

    private func subtract(_ intervals: [DateInterval], from window: DateInterval) -> [DateInterval] {
        var cursor = window.start
        var result: [DateInterval] = []
        for interval in intervals {
            guard interval.end > cursor else { continue }
            if interval.start > cursor {
                result.append(DateInterval(start: cursor, end: min(interval.start, window.end)))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < window.end { result.append(DateInterval(start: cursor, end: window.end)) }
        return result.filter { $0.duration > 0 }
    }
}
