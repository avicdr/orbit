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

        let health = try repository.createOrbit(
            name: "Health",
            icon: "heart.fill",
            colorToken: "green",
            description: "Energy for the life I want to live",
            weight: 1.25
        )
        let healthGoal = try repository.createGoal(
            title: "Build a sustainable routine",
            orbit: health,
            notes: "Small practices that make good days easier.",
            priority: .normal
        )
        let movement = try repository.createProject(
            title: "Morning movement",
            goal: healthGoal,
            priority: .normal,
            deadline: Calendar.current.date(byAdding: .day, value: 21, to: .now)
        )
        _ = try repository.createTask(
            title: "Plan three short sessions",
            project: movement,
            status: .completed,
            priority: .normal,
            estimatedDuration: 20 * 60,
            energyRequirement: .okay
        )

        let learning = try repository.createOrbit(
            name: "Learning",
            icon: "book.closed.fill",
            colorToken: "purple",
            description: "Keep curiosity in motion"
        )
        _ = try repository.createGoal(
            title: "Grow the product craft",
            orbit: learning,
            notes: "Make time for deliberate practice.",
            priority: .high
        )
    }
}
