import Foundation

public struct TimeBlock: Identifiable, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable { case calendarCommitment, scheduledTask }
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let kind: Kind

    public init(id: String, startDate: Date, endDate: Date, kind: Kind) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.kind = kind
    }
}

public struct TimePlan: Equatable, Sendable {
    public let workingWindow: DateInterval
    public let manuallyAvailableMinutes: Int?
    public let calendarCommitments: [TimeBlock]
    public let scheduledTasks: [TimeBlock]
    public let unscheduledPlannedMinutes: Int

    public init(
        workingWindow: DateInterval,
        manuallyAvailableMinutes: Int? = nil,
        calendarCommitments: [TimeBlock] = [],
        scheduledTasks: [TimeBlock] = [],
        unscheduledPlannedMinutes: Int = 0
    ) {
        self.workingWindow = workingWindow
        self.manuallyAvailableMinutes = manuallyAvailableMinutes
        self.calendarCommitments = calendarCommitments
        self.scheduledTasks = scheduledTasks
        self.unscheduledPlannedMinutes = max(0, unscheduledPlannedMinutes)
    }
}

public struct TimeSummary: Equatable, Sendable {
    public let availableMinutes: Int
    public let calendarCommittedMinutes: Int
    public let plannedTaskMinutes: Int
    public let freeMinutes: Int
    public let overloadedMinutes: Int
    public let freeWindows: [DateInterval]

    public var isOverloaded: Bool { overloadedMinutes > 0 }
}

/// Deterministic daily capacity math. EventKit, UI, and task persistence stay outside this type.
public struct TimeEngine: Sendable {
    public init() {}

    public func summarize(_ plan: TimePlan) -> TimeSummary {
        let windowDuration = max(0, plan.workingWindow.duration)
        let available = plan.manuallyAvailableMinutes ?? Int((windowDuration / 60).rounded(.down))
        let calendarBlocks = clipped(plan.calendarCommitments, to: plan.workingWindow)
        let scheduledBlocks = clipped(plan.scheduledTasks, to: plan.workingWindow)
        let calendarMinutes = minutes(in: calendarBlocks)
        let scheduledMinutes = minutes(in: scheduledBlocks)
        let plannedMinutes = plan.unscheduledPlannedMinutes + scheduledMinutes
        let occupiedWindows = merged(calendarBlocks + scheduledBlocks)
        let windows = subtract(occupiedWindows, from: plan.workingWindow)
        let load = calendarMinutes + plannedMinutes

        return TimeSummary(
            availableMinutes: max(0, available),
            calendarCommittedMinutes: calendarMinutes,
            plannedTaskMinutes: plannedMinutes,
            freeMinutes: max(0, available - load),
            overloadedMinutes: max(0, load - available),
            freeWindows: windows
        )
    }

    private func clipped(_ blocks: [TimeBlock], to window: DateInterval) -> [DateInterval] {
        blocks.compactMap { block in
            let interval = DateInterval(start: block.startDate, end: block.endDate)
            guard let intersection = interval.intersection(with: window), intersection.duration > 0 else { return nil }
            return intersection
        }
    }

    private func minutes(in intervals: [DateInterval]) -> Int {
        Int((merged(intervals).reduce(0) { $0 + $1.duration } / 60).rounded(.down))
    }

    private func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        return sorted.reduce(into: [DateInterval]()) { result, interval in
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
            if interval.start > cursor { result.append(DateInterval(start: cursor, end: min(interval.start, window.end))) }
            cursor = max(cursor, interval.end)
        }
        if cursor < window.end { result.append(DateInterval(start: cursor, end: window.end)) }
        return result.filter { $0.duration > 0 }
    }
}
