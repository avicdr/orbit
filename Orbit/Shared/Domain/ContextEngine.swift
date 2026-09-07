import Foundation

/// The platform the context was assembled on. It is an input, never inferred from task data.
public enum ContextDevice: String, Codable, CaseIterable, Sendable, Hashable {
    case iPhone
    case mac
    case watch
    case unknown
}

/// Location access is represented explicitly so an unavailable permission never becomes fake context.
public enum LocationAuthorizationState: String, Codable, CaseIterable, Sendable, Hashable {
    case notRequested
    case denied
    case restricted
    case authorized
}

/// Calendar is optional context. EventKit will supply `.available` in Milestone 16.
public enum CalendarContextAvailability: Equatable, Sendable {
    case notConnected
    case unavailable
    case available(freeMinutes: Int)

    public var freeMinutes: Int? {
        if case let .available(minutes) = self { return max(0, minutes) }
        return nil
    }
}

public enum ActiveContextSource: String, Codable, Sendable, Hashable {
    case manual
    case oneShotLocation
}

/// A deliberately small, user-understandable context label. It is not a coordinate history.
public struct ManualContextSelection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let kind: ContextKind
    public let source: ActiveContextSource

    public var id: String { "\(kind.rawValue):\(name.lowercased())" }
    public var displayName: String { name.capitalized }

    public init(name: String, kind: ContextKind, source: ActiveContextSource = .manual) {
        self.name = name
        self.kind = kind
        self.source = source
    }

    public static let presets: [ManualContextSelection] = [
        .init(name: "Home", kind: .home),
        .init(name: "Office", kind: .office),
        .init(name: "Campus", kind: .campus),
        .init(name: "Commute", kind: .commute),
        .init(name: "Outdoors", kind: .outdoors),
        .init(name: "Anywhere", kind: .anywhere)
    ]
}

public struct ContextInput: Equatable, Sendable {
    public let now: Date
    public let manuallyAvailableMinutes: Int?
    public let calendarAvailability: CalendarContextAvailability
    public let energyLevel: EnergyLevel?
    public let activeContext: ManualContextSelection?
    public let locationAuthorization: LocationAuthorizationState
    public let device: ContextDevice

    public init(
        now: Date,
        manuallyAvailableMinutes: Int?,
        calendarAvailability: CalendarContextAvailability = .notConnected,
        energyLevel: EnergyLevel?,
        activeContext: ManualContextSelection? = nil,
        locationAuthorization: LocationAuthorizationState = .notRequested,
        device: ContextDevice
    ) {
        self.now = now
        self.manuallyAvailableMinutes = manuallyAvailableMinutes.map { max(0, $0) }
        self.calendarAvailability = calendarAvailability
        self.energyLevel = energyLevel
        self.activeContext = activeContext
        self.locationAuthorization = locationAuthorization
        self.device = device
    }
}

public enum ContextAvailabilitySource: Equatable, Sendable {
    case fallback
    case manual
    case calendar
    case constrainedByCalendar
}

public struct ContextSnapshot: Equatable, Sendable {
    public let now: Date
    public let availableMinutes: Int
    public let availabilitySource: ContextAvailabilitySource
    public let energyLevel: EnergyLevel?
    public let activeContext: ManualContextSelection?
    public let calendarAvailability: CalendarContextAvailability
    public let locationAuthorization: LocationAuthorizationState
    public let device: ContextDevice
}

/// Local context assembly. It does not ask for permission, access sensors, or retain locations.
public struct ContextEngine: Sendable {
    public init() {}

    public func resolve(_ input: ContextInput) -> ContextSnapshot {
        let availability = resolvedAvailability(
            manuallyAvailableMinutes: input.manuallyAvailableMinutes,
            calendarAvailability: input.calendarAvailability
        )
        return ContextSnapshot(
            now: input.now,
            availableMinutes: availability.minutes,
            availabilitySource: availability.source,
            energyLevel: input.energyLevel,
            activeContext: input.activeContext,
            calendarAvailability: input.calendarAvailability,
            locationAuthorization: input.locationAuthorization,
            device: input.device
        )
    }

    public func recommendationContext(from snapshot: ContextSnapshot) -> RecommendationContext {
        RecommendationContext(
            now: snapshot.now,
            availableMinutes: snapshot.availableMinutes,
            energyLevel: snapshot.energyLevel,
            contextName: snapshot.activeContext?.name,
            calendarIsAvailable: snapshot.calendarAvailability.freeMinutes != nil
        )
    }

    private func resolvedAvailability(
        manuallyAvailableMinutes: Int?,
        calendarAvailability: CalendarContextAvailability
    ) -> (minutes: Int, source: ContextAvailabilitySource) {
        let calendarMinutes = calendarAvailability.freeMinutes
        switch (manuallyAvailableMinutes, calendarMinutes) {
        case let (.some(manual), .some(calendar)):
            return (min(manual, calendar), .constrainedByCalendar)
        case let (.some(manual), .none):
            return (manual, .manual)
        case let (.none, .some(calendar)):
            return (calendar, .calendar)
        case (.none, .none):
            // A short, explicit planning window keeps the app useful without integrations.
            return (30, .fallback)
        }
    }
}
