import SwiftData

/// Schema versions are additive. New persisted fields or semantic changes must introduce a
/// new version and an explicit migration stage rather than silently changing V1.
public enum OrbitSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [
            Orbit.self,
            Goal.self,
            Project.self,
            OrbitTask.self,
            FocusSession.self,
            DailyState.self,
            TaskContext.self
        ]
    }
}

/// Adds task placement without mutating the original task schema.
public enum OrbitSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }
    public static var models: [any PersistentModel.Type] {
        [
            Orbit.self,
            Goal.self,
            Project.self,
            OrbitTask.self,
            FocusSession.self,
            DailyState.self,
            TaskContext.self,
            TaskSchedule.self
        ]
    }
}

public enum OrbitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [OrbitSchemaV1.self, OrbitSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: OrbitSchemaV1.self, toVersion: OrbitSchemaV2.self)]
    }
}
