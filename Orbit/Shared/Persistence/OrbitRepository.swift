import Foundation
import SwiftData

public enum OrbitRepositoryError: LocalizedError {
    case invalidScheduleRange

    public var errorDescription: String? {
        switch self {
        case .invalidScheduleRange: "A scheduled task must end after it starts."
        }
    }
}

/// The only mutation boundary for the shared work hierarchy in this milestone.
/// UI layers may render model values but route persistence operations through this type.
@MainActor
public final class OrbitRepository {
    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func createOrbit(
        name: String,
        icon: String = "circle.grid.2x2",
        colorToken: String = "accent",
        description: String = "",
        weight: Double = 1
    ) throws -> Orbit {
        let orbit = Orbit(name: name, icon: icon, colorToken: colorToken, description: description, weight: weight)
        context.insert(orbit)
        try save()
        return orbit
    }

    @discardableResult
    public func createGoal(
        title: String,
        orbit: Orbit?,
        notes: String = "",
        priority: TaskPriority = .normal,
        targetDate: Date? = nil
    ) throws -> Goal {
        let goal = Goal(title: title, notes: notes, orbit: orbit, priority: priority, targetDate: targetDate)
        context.insert(goal)
        try save()
        return goal
    }

    @discardableResult
    public func createProject(
        title: String,
        goal: Goal?,
        orbit: Orbit? = nil,
        notes: String = "",
        priority: TaskPriority = .normal,
        deadline: Date? = nil
    ) throws -> Project {
        let project = Project(title: title, notes: notes, goal: goal, orbit: orbit, priority: priority, deadline: deadline)
        context.insert(project)
        try save()
        return project
    }

    @discardableResult
    public func createTask(
        title: String,
        project: Project? = nil,
        goal: Goal? = nil,
        orbit: Orbit? = nil,
        notes: String = "",
        status: TaskStatus = .planned,
        priority: TaskPriority = .normal,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        energyRequirement: EnergyLevel? = nil,
        context taskContext: TaskContext? = nil,
        locationRequirement: String? = nil,
        recurrence: TaskRecurrence? = nil
    ) throws -> OrbitTask {
        let task = OrbitTask(
            title: title,
            notes: notes,
            status: status,
            priority: priority,
            dueDate: dueDate,
            estimatedDuration: estimatedDuration,
            energyRequirement: energyRequirement,
            context: taskContext,
            locationRequirement: locationRequirement,
            project: project,
            goal: goal,
            orbit: orbit,
            recurrence: recurrence
        )
        context.insert(task)
        try save()
        return task
    }

    @discardableResult
    public func createFocusSession(
        task: OrbitTask,
        plannedDuration: TimeInterval? = nil,
        startDate: Date = .now
    ) throws -> FocusSession {
        let session = FocusSession(task: task, startDate: startDate, plannedDuration: plannedDuration)
        context.insert(session)
        try save()
        return session
    }

    public func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    public func fetchOrbits(includeArchived: Bool = false) throws -> [Orbit] {
        var descriptor = FetchDescriptor<Orbit>(sortBy: [SortDescriptor(\.createdAt)])
        if !includeArchived {
            descriptor.predicate = #Predicate { $0.archivedAt == nil }
        }
        return try context.fetch(descriptor)
    }

    public func fetchGoals() throws -> [Goal] {
        try context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    public func fetchProjects() throws -> [Project] {
        try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    public func fetchTasks() throws -> [OrbitTask] {
        try context.fetch(FetchDescriptor<OrbitTask>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    public func fetchInboxTasks() throws -> [OrbitTask] {
        let inboxRawValue = TaskStatus.inbox.rawValue
        let descriptor = FetchDescriptor<OrbitTask>(
            predicate: #Predicate { $0.statusRawValue == inboxRawValue },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    public func fetchSchedules() throws -> [TaskSchedule] {
        try context.fetch(FetchDescriptor<TaskSchedule>(sortBy: [SortDescriptor(\.startDate)]))
    }

    @discardableResult
    public func schedule(
        _ task: OrbitTask,
        startDate: Date,
        endDate: Date,
        updatedAt: Date = .now
    ) throws -> TaskSchedule {
        guard endDate > startDate else { throw OrbitRepositoryError.invalidScheduleRange }
        let taskID = task.id
        let descriptor = FetchDescriptor<TaskSchedule>(predicate: #Predicate { $0.taskID == taskID })
        let schedule = try context.fetch(descriptor).first ?? TaskSchedule(taskID: task.id, startDate: startDate, endDate: endDate, updatedAt: updatedAt)
        if schedule.modelContext == nil { context.insert(schedule) }
        schedule.startDate = startDate
        schedule.endDate = endDate
        schedule.updatedAt = updatedAt
        try save()
        return schedule
    }

    public func unschedule(_ task: OrbitTask) throws {
        let taskID = task.id
        let descriptor = FetchDescriptor<TaskSchedule>(predicate: #Predicate { $0.taskID == taskID })
        for schedule in try context.fetch(descriptor) { context.delete(schedule) }
        try save()
    }

    @discardableResult
    public func updateDailyState(
        for date: Date,
        calendar: Calendar = .current,
        availableMinutes: Int?,
        notes: String = ""
    ) throws -> DailyState {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyState>(predicate: #Predicate { $0.date == day })
        let state = try context.fetch(descriptor).first ?? DailyState(date: day)
        if state.modelContext == nil { context.insert(state) }
        state.availableMinutes = availableMinutes.map { max(0, $0) }
        state.notes = notes
        try save()
        return state
    }

    @discardableResult
    public func updateDailyEnergy(
        for date: Date,
        calendar: Calendar = .current,
        energyLevel: EnergyLevel?
    ) throws -> DailyState {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyState>(predicate: #Predicate { $0.date == day })
        let state = try context.fetch(descriptor).first ?? DailyState(date: day)
        if state.modelContext == nil { context.insert(state) }
        state.energyLevel = energyLevel
        try save()
        return state
    }

    /// Capture intentionally asks only for the thought itself. Organizing happens later.
    @discardableResult
    public func capture(_ title: String, createdAt: Date = .now) throws -> OrbitTask {
        let task = OrbitTask(title: title, status: .inbox, createdAt: createdAt)
        context.insert(task)
        try save()
        return task
    }

    public func archive(_ orbit: Orbit, at date: Date = .now) throws {
        orbit.archivedAt = date
        try save()
    }

    public func archive(_ task: OrbitTask) throws {
        task.status = .cancelled
        task.completedAt = nil
        try save()
    }

    public func update(
        _ orbit: Orbit,
        name: String,
        icon: String,
        colorToken: String,
        description: String,
        weight: Double
    ) throws {
        orbit.name = name
        orbit.icon = icon
        orbit.colorToken = colorToken
        orbit.orbitDescription = description
        orbit.weight = weight
        try save()
    }

    public func update(
        _ goal: Goal,
        title: String,
        notes: String,
        priority: TaskPriority,
        targetDate: Date?,
        status: GoalStatus
    ) throws {
        goal.title = title
        goal.notes = notes
        goal.priority = priority
        goal.targetDate = targetDate
        goal.status = status
        goal.completedAt = status == .completed ? (goal.completedAt ?? .now) : nil
        try save()
    }

    public func update(
        _ project: Project,
        title: String,
        notes: String,
        priority: TaskPriority,
        deadline: Date?,
        status: ProjectStatus,
        goal: Goal?,
        orbit: Orbit?
    ) throws {
        project.title = title
        project.notes = notes
        project.priority = priority
        project.deadline = deadline
        project.status = status
        project.completedAt = status == .completed ? (project.completedAt ?? .now) : nil
        project.goal = goal
        project.orbit = goal?.orbit ?? orbit
        for task in project.tasks {
            task.goal = project.goal
            task.orbit = project.orbit
        }
        try save()
    }

    public func update(
        _ task: OrbitTask,
        title: String,
        notes: String,
        status: TaskStatus,
        priority: TaskPriority,
        dueDate: Date?,
        estimatedDuration: TimeInterval?,
        energyRequirement: EnergyLevel?,
        locationRequirement: String?,
        project: Project?,
        goal: Goal?,
        orbit: Orbit?,
        recurrence: TaskRecurrence?
    ) throws {
        task.title = title
        task.notes = notes
        task.status = status
        task.priority = priority
        task.dueDate = dueDate
        task.estimatedDuration = estimatedDuration
        task.energyRequirement = energyRequirement
        task.locationRequirement = locationRequirement
        task.project = project
        task.goal = project?.goal ?? goal
        task.orbit = project?.orbit ?? project?.goal?.orbit ?? goal?.orbit ?? orbit
        task.recurrence = recurrence
        task.completedAt = status == .completed ? (task.completedAt ?? .now) : nil
        try save()
    }

    public func complete(_ task: OrbitTask, at date: Date = .now) throws {
        task.status = .completed
        task.completedAt = date
        try save()
    }

    public func reopen(_ task: OrbitTask) throws {
        task.status = .planned
        task.completedAt = nil
        try save()
    }

    /// Removing an Orbit never removes a person's work. Its child records become unassigned.
    public func delete(_ orbit: Orbit) throws {
        for goal in orbit.goals { goal.orbit = nil }
        for project in orbit.projects { project.orbit = nil }
        for task in orbit.tasks { task.orbit = nil }
        context.delete(orbit)
        try save()
    }

    /// Projects remain available when their outcome is removed, preserving work-in-progress.
    public func delete(_ goal: Goal) throws {
        for project in goal.projects { project.goal = nil }
        for task in goal.tasks { task.goal = nil }
        context.delete(goal)
        try save()
    }

    /// Tasks are retained as unassigned inbox work if their project is removed.
    public func delete(_ project: Project) throws {
        for task in project.tasks { task.project = nil }
        context.delete(project)
        try save()
    }

    /// Focus sessions are intentionally cascaded with their task; dependency links are cleared.
    public func delete(_ task: OrbitTask) throws {
        for candidate in try fetchTasks() where candidate.id != task.id {
            candidate.dependencies.removeAll { $0.id == task.id }
        }
        try unschedule(task)
        context.delete(task)
        try save()
    }
}
