import Foundation

public enum EnergyFit: String, Equatable, Sendable {
    case match
    case mismatch
    case unknown
}

/// Productivity-only matching; it makes no health or medical interpretation.
public struct EnergyMatcher: Sendable {
    public init() {}

    public func fit(current: EnergyLevel?, requirement: EnergyLevel?) -> EnergyFit {
        guard let current, let requirement else { return .unknown }
        return current >= requirement ? .match : .mismatch
    }
}
