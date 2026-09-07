import Foundation
import SwiftData

public enum OrbitModelContainer {
    public static let schema = Schema([
        Orbit.self,
        Goal.self,
        Project.self,
        OrbitTask.self,
        FocusSession.self,
        DailyState.self,
        TaskContext.self,
        TaskSchedule.self
    ])

    /// Creates Orbit's local store. A caller may provide a URL for integration tests or
    /// an explicitly managed store location; production uses SwiftData's default location.
    public static func make(inMemory: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "Orbit",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "Orbit",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: OrbitMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
