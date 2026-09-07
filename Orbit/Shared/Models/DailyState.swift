import Foundation
import SwiftData

@Model
public final class DailyState {
    @Attribute(.unique) public var date: Date
    public var energyLevelRawValue: String?
    public var availableMinutes: Int?
    public var notes: String

    public var energyLevel: EnergyLevel? {
        get { energyLevelRawValue.flatMap(EnergyLevel.init(rawValue:)) }
        set { energyLevelRawValue = newValue?.rawValue }
    }

    public init(
        date: Date,
        energyLevel: EnergyLevel? = nil,
        availableMinutes: Int? = nil,
        notes: String = ""
    ) {
        self.date = date
        self.energyLevelRawValue = energyLevel?.rawValue
        self.availableMinutes = availableMinutes
        self.notes = notes
    }
}
