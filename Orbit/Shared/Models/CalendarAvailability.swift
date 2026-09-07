import Foundation

/// A read-only, app-owned representation of usable time. EventKit remains the source of truth.
public struct CalendarAvailability: Identifiable, Equatable, Sendable {
    public let id: String
    public let startDate: Date
    public let endDate: Date
    public let source: Source

    public enum Source: String, Equatable, Sendable {
        case manual
        case calendar
        case scheduledTask
    }

    public init(id: String, startDate: Date, endDate: Date, source: Source) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
    }
}
