import Foundation
import SwiftData

/// Explicit fixtures for previews, manual development, and tests. Production launch never seeds them.
@MainActor
public enum OrbitDevelopmentData {
    public static func seedIfNeeded(into context: ModelContext) throws {
        let repository = OrbitRepository(context: context)
        guard try repository.fetchOrbits(includeArchived: true).isEmpty else { return }

        let career = try repository.createOrbit(
            name: "Career",
            icon: "briefcase.fill",
            colorToken: "blue",
            description: "Professional growth"
        )
        let goal = try repository.createGoal(title: "Ship a thoughtful app", orbit: career, priority: .high)
        let project = try repository.createProject(title: "Foundation", goal: goal, priority: .high)
        _ = try repository.createTask(
            title: "Review the data model",
            project: project,
            status: .planned,
            priority: .high,
            estimatedDuration: 30 * 60,
            energyRequirement: .good
        )
    }
}
