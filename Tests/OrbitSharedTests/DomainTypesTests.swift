import Testing
import Foundation
import SwiftData
@testable import OrbitShared

@Test func energyLevelsAreOrderedByDemand() {
    #expect(EnergyLevel.drained < .okay)
    #expect(EnergyLevel.good < .high)
}

@Test func taskUsesStronglyTypedStoredValues() {
    let task = OrbitTask(title: "Draft architecture", status: .planned, priority: .high, energyRequirement: .good)
    #expect(task.status == .planned)
    #expect(task.priority == .high)
    #expect(task.energyRequirement == .good)
}

@Test @MainActor func hierarchyPersistsAndCanBeReloaded() throws {
    let storeURL = FileManager.default.temporaryDirectory
        .appending(path: "OrbitTests")
        .appending(path: "\(UUID().uuidString).store")
    defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
    try FileManager.default.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let firstContainer = try OrbitModelContainer.make(storeURL: storeURL)
    let firstRepository = OrbitRepository(context: firstContainer.mainContext)
    let orbit = try firstRepository.createOrbit(name: "Learning", weight: 1.5)
    let goal = try firstRepository.createGoal(title: "Finish course", orbit: orbit, priority: .high)
    let project = try firstRepository.createProject(title: "Module one", goal: goal)
    let task = try firstRepository.createTask(
        title: "Watch lesson",
        project: project,
        estimatedDuration: 25 * 60,
        recurrence: .weekly
    )
    let session = try firstRepository.createFocusSession(task: task, plannedDuration: 25 * 60)

    #expect(task.goal?.id == goal.id)
    #expect(task.orbit?.id == orbit.id)
    #expect(session.task?.id == task.id)

    let secondContainer = try OrbitModelContainer.make(storeURL: storeURL)
    let reloadedRepository = OrbitRepository(context: secondContainer.mainContext)
    let reloadedTasks = try reloadedRepository.fetchTasks()
    let reloadedTask = try #require(reloadedTasks.first)
    #expect(reloadedTask.title == "Watch lesson")
    #expect(reloadedTask.project?.title == "Module one")
    #expect(reloadedTask.focusSessions.count == 1)
    #expect(reloadedTask.recurrence == .weekly)
}

@Test @MainActor func updatesArchivesAndSafeDeletionPreserveWork() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let orbit = try repository.createOrbit(name: "Creative")
    try repository.update(
        orbit,
        name: "Creative practice",
        icon: "paintbrush.fill",
        colorToken: "purple",
        description: "Make time to create.",
        weight: 1.25
    )
    #expect(orbit.name == "Creative practice")
    #expect(orbit.weight == 1.25)
    let goal = try repository.createGoal(title: "Publish essays", orbit: orbit)
    let project = try repository.createProject(title: "Draft collection", goal: goal)
    let task = try repository.createTask(title: "Outline essay", project: project)
    let dependent = try repository.createTask(title: "Edit essay")
    _ = try repository.createFocusSession(task: task, plannedDuration: 20 * 60)
    dependent.dependencies = [task]
    task.title = "Outline first essay"
    task.status = .completed
    try repository.save()

    try repository.archive(orbit)
    #expect(try repository.fetchOrbits().isEmpty)
    #expect(try repository.fetchOrbits(includeArchived: true).count == 1)

    try repository.delete(goal)
    #expect(project.goal == nil)
    #expect(task.goal == nil)
    #expect(task.project?.id == project.id)

    try repository.delete(project)
    #expect(task.project == nil)
    #expect(task.title == "Outline first essay")

    try repository.delete(task)
    #expect(dependent.dependencies.isEmpty)
    #expect(try repository.fetchTasks().count == 1)
    #expect(try container.mainContext.fetch(FetchDescriptor<FocusSession>()).isEmpty)
}

@Test @MainActor func projectAssignmentKeepsTaskHierarchyConsistent() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let learning = try repository.createOrbit(name: "Learning")
    let personal = try repository.createOrbit(name: "Personal")
    let goal = try repository.createGoal(title: "Learn Swift", orbit: learning)
    let project = try repository.createProject(title: "Build Orbit", goal: goal)
    let task = try repository.createTask(title: "Write persistence tests", orbit: personal)

    try repository.update(
        task,
        title: "Write persistence tests",
        notes: "Cover hierarchy and deletion.",
        status: .inProgress,
        priority: .critical,
        dueDate: .now,
        estimatedDuration: 45 * 60,
        energyRequirement: .good,
        locationRequirement: "Office",
        project: project,
        goal: nil,
        orbit: personal,
        recurrence: nil
    )
    #expect(task.project?.id == project.id)
    #expect(task.goal?.id == goal.id)
    #expect(task.orbit?.id == learning.id)
    #expect(task.status == .inProgress)

    try repository.complete(task)
    #expect(task.status == .completed)
    #expect(task.completedAt != nil)
    try repository.reopen(task)
    #expect(task.status == .planned)
    #expect(task.completedAt == nil)
}

@Test @MainActor func captureInboxRequiresNoPlanningAndCanBeOrganizedOrArchived() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let captured = try repository.capture("Call the dentist")
    #expect(captured.status == .inbox)
    #expect(captured.project == nil)
    #expect(captured.goal == nil)
    #expect(captured.orbit == nil)
    #expect(try repository.fetchInboxTasks().map(\.id) == [captured.id])

    try repository.update(
        captured,
        title: captured.title,
        notes: "",
        status: .planned,
        priority: .normal,
        dueDate: nil,
        estimatedDuration: nil,
        energyRequirement: nil,
        locationRequirement: nil,
        project: nil,
        goal: nil,
        orbit: nil,
        recurrence: nil
    )
    #expect(try repository.fetchInboxTasks().isEmpty)

    let archived = try repository.capture("Old idea")
    try repository.archive(archived)
    #expect(archived.status == .cancelled)
    try repository.delete(archived)
    #expect(try repository.fetchTasks().allSatisfy { $0.id != archived.id })
}

@Test func timeEngineCalculatesCapacityFreeWindowsAndOverload() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let window = DateInterval(start: start, duration: 6 * 60 * 60)
    let calendar = TimeBlock(id: "meeting", startDate: start.addingTimeInterval(60 * 60), endDate: start.addingTimeInterval(3 * 60 * 60), kind: .calendarCommitment)
    let scheduled = TimeBlock(id: "deep-work", startDate: start.addingTimeInterval(4 * 60 * 60), endDate: start.addingTimeInterval(5 * 60 * 60), kind: .scheduledTask)
    let summary = TimeEngine().summarize(TimePlan(workingWindow: window, calendarCommitments: [calendar], scheduledTasks: [scheduled], unscheduledPlannedMinutes: 2 * 60))

    #expect(summary.availableMinutes == 360)
    #expect(summary.calendarCommittedMinutes == 120)
    #expect(summary.plannedTaskMinutes == 180)
    #expect(summary.freeMinutes == 60)
    #expect(summary.overloadedMinutes == 0)
    #expect(summary.freeWindows.count == 3)
}

@Test func timeEngineUsesManualCapacityAndMergesOverlappingCommitments() {
    let start = Date(timeIntervalSinceReferenceDate: 2_000_000)
    let window = DateInterval(start: start, duration: 8 * 60 * 60)
    let first = TimeBlock(id: "one", startDate: start, endDate: start.addingTimeInterval(2 * 60 * 60), kind: .calendarCommitment)
    let overlapping = TimeBlock(id: "two", startDate: start.addingTimeInterval(60 * 60), endDate: start.addingTimeInterval(3 * 60 * 60), kind: .calendarCommitment)
    let summary = TimeEngine().summarize(TimePlan(workingWindow: window, manuallyAvailableMinutes: 240, calendarCommitments: [first, overlapping], unscheduledPlannedMinutes: 180))

    #expect(summary.calendarCommittedMinutes == 180)
    #expect(summary.plannedTaskMinutes == 180)
    #expect(summary.freeMinutes == 0)
    #expect(summary.overloadedMinutes == 120)
    #expect(summary.isOverloaded)
}

@Test @MainActor func dailyAvailabilityPersistsByDay() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let date = Date(timeIntervalSinceReferenceDate: 3_000_000)
    let first = try repository.updateDailyState(for: date, availableMinutes: 360, notes: "Workday")
    let second = try repository.updateDailyState(for: date.addingTimeInterval(60 * 60), availableMinutes: 300)
    #expect(first.date == second.date)
    #expect(second.availableMinutes == 300)
}

@Test func energyMatcherHandlesMatchMismatchAndUnknown() {
    let matcher = EnergyMatcher()
    #expect(matcher.fit(current: .good, requirement: .okay) == .match)
    #expect(matcher.fit(current: .low, requirement: .good) == .mismatch)
    #expect(matcher.fit(current: nil, requirement: .good) == .unknown)
    #expect(matcher.fit(current: .high, requirement: nil) == .unknown)
}

@Test @MainActor func dailyEnergyPersistsIndependentlyOfAvailability() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let date = Date(timeIntervalSinceReferenceDate: 4_000_000)
    _ = try repository.updateDailyState(for: date, availableMinutes: 420)
    let state = try repository.updateDailyEnergy(for: date, energyLevel: .okay)
    #expect(state.energyLevel == .okay)
    #expect(state.availableMinutes == 420)
}

@Test func recommendationEngineScoresUrgencyPriorityAndTimeFit() {
    let now = Date(timeIntervalSinceReferenceDate: 5_000_000)
    let urgent = RecommendationTask(title: "Submit report", priority: .high, dueDate: now.addingTimeInterval(2 * 60 * 60), estimatedMinutes: 30)
    let later = RecommendationTask(title: "Refactor", priority: .high, dueDate: now.addingTimeInterval(7 * 24 * 60 * 60), estimatedMinutes: 30)
    let tooLong = RecommendationTask(title: "Write spec", priority: .critical, estimatedMinutes: 180)
    let result = RecommendationEngine().recommend(tasks: [later, tooLong, urgent], context: RecommendationContext(now: now, availableMinutes: 45, energyLevel: .good))
    #expect(result.primary?.task.id == urgent.id)
    #expect(result.primary?.explanation.contains("Fits your 45-minute window") == true)
    #expect(result.alternatives.first { $0.task.id == tooLong.id }?.score.timeFit == 0)
}

@Test func recommendationEngineExcludesCompletedBlockedAndMismatchedContextIsPenalized() {
    let now = Date(timeIntervalSinceReferenceDate: 6_000_000)
    let office = RecommendationTask(title: "Office task", priority: .normal, energyRequirement: .good, contextName: "Office")
    let home = RecommendationTask(title: "Home task", priority: .normal, energyRequirement: .good, contextName: "Home")
    let completed = RecommendationTask(title: "Done", status: .completed)
    let blocked = RecommendationTask(title: "Blocked", dependenciesComplete: false)
    let result = RecommendationEngine().recommend(tasks: [home, completed, blocked, office], context: RecommendationContext(now: now, availableMinutes: 30, energyLevel: .low, contextName: "Office"))
    #expect(result.primary?.task.id == office.id)
    #expect(result.primary?.score.energyMatch == 0)
    #expect(result.unavailableTasks.contains { $0.reason == .completed })
    #expect(result.unavailableTasks.contains { $0.reason == .blocked })
    #expect(result.alternatives.first?.task.id == home.id)
}

@Test func recommendationEngineHandlesNoAvailableTasksOrTime() {
    let engine = RecommendationEngine()
    let now = Date(timeIntervalSinceReferenceDate: 7_000_000)
    #expect(engine.recommend(tasks: [RecommendationTask(title: "Done", status: .completed)], context: RecommendationContext(now: now, availableMinutes: 30, energyLevel: nil)).emptyReason == .noEligibleTasks)
    #expect(engine.recommend(tasks: [RecommendationTask(title: "Plan")], context: RecommendationContext(now: now, availableMinutes: 0, energyLevel: nil)).emptyReason == .noAvailableTime)
}

@Test func contextEngineCombinesManualWindowCalendarEnergyAndContext() {
    let now = Date(timeIntervalSinceReferenceDate: 8_000_000)
    let snapshot = ContextEngine().resolve(ContextInput(
        now: now,
        manuallyAvailableMinutes: 90,
        calendarAvailability: .available(freeMinutes: 45),
        energyLevel: .good,
        activeContext: .init(name: "Office", kind: .office),
        locationAuthorization: .notRequested,
        device: .iPhone
    ))

    #expect(snapshot.availableMinutes == 45)
    #expect(snapshot.availabilitySource == .constrainedByCalendar)
    #expect(snapshot.activeContext?.kind == .office)
    #expect(snapshot.energyLevel == .good)
    #expect(snapshot.device == .iPhone)

    let recommendationContext = ContextEngine().recommendationContext(from: snapshot)
    #expect(recommendationContext.contextName == "Office")
    #expect(recommendationContext.calendarIsAvailable)
}

@Test func contextEngineDegradesWithoutPermissionsOrCalendar() {
    let snapshot = ContextEngine().resolve(ContextInput(
        now: Date(timeIntervalSinceReferenceDate: 8_100_000),
        manuallyAvailableMinutes: nil,
        calendarAvailability: .unavailable,
        energyLevel: nil,
        activeContext: nil,
        locationAuthorization: .denied,
        device: .watch
    ))

    #expect(snapshot.availableMinutes == 30)
    #expect(snapshot.availabilitySource == .fallback)
    #expect(snapshot.activeContext == nil)
    #expect(snapshot.locationAuthorization == .denied)
    #expect(!ContextEngine().recommendationContext(from: snapshot).calendarIsAvailable)
}

@Test func manualContextPreferencePersistsOnlyExplicitSelection() {
    let suiteName = "Orbit.ContextPreferenceTests.\(UUID().uuidString)"
    let defaults = try! #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let selection = ManualContextSelection(name: "Campus", kind: .campus)
    ContextPreferenceStore.save(selection, in: defaults)
    #expect(ContextPreferenceStore.load(from: defaults) == selection)
    ContextPreferenceStore.save(nil, in: defaults)
    #expect(ContextPreferenceStore.load(from: defaults) == nil)
}

@Test func timelineEngineFindsFreeWindowsAndRequiresConfirmationForConflicts() {
    let start = Date(timeIntervalSinceReferenceDate: 9_000_000)
    let window = DateInterval(start: start, duration: 6 * 60 * 60)
    let existing = TimelineScheduledTask(
        taskID: UUID(),
        title: "Deep work",
        startDate: start.addingTimeInterval(60 * 60),
        endDate: start.addingTimeInterval(2 * 60 * 60)
    )
    let commitment = CalendarAvailability(
        id: "meeting",
        startDate: start.addingTimeInterval(3 * 60 * 60),
        endDate: start.addingTimeInterval(4 * 60 * 60),
        source: .calendar
    )
    let engine = TimelineEngine()
    let day = engine.day(window: window, scheduledTasks: [existing], calendarCommitments: [commitment])

    #expect(day.entries.count == 2)
    #expect(day.freeWindows.count == 3)

    let movingTaskID = UUID()
    let overlapping = try! #require(engine.proposeMove(
        taskID: movingTaskID,
        startDate: start.addingTimeInterval(90 * 60),
        duration: 30 * 60,
        scheduledTasks: [existing],
        calendarCommitments: [commitment]
    ))
    #expect(overlapping.requiresConfirmation)
    #expect(overlapping.conflicts.first?.conflictingKind == .task)

    let clear = try! #require(engine.proposeMove(
        taskID: movingTaskID,
        startDate: start.addingTimeInterval(4 * 60 * 60),
        duration: 30 * 60,
        scheduledTasks: [existing],
        calendarCommitments: [commitment]
    ))
    #expect(!clear.requiresConfirmation)
}

@Test @MainActor func taskSchedulesPersistUpdateAndDeleteSafely() throws {
    let container = try OrbitModelContainer.make(inMemory: true)
    let repository = OrbitRepository(context: container.mainContext)
    let task = try repository.createTask(title: "Plan timeline", estimatedDuration: 30 * 60)
    let start = Date(timeIntervalSinceReferenceDate: 9_100_000)

    let first = try repository.schedule(task, startDate: start, endDate: start.addingTimeInterval(30 * 60))
    let updated = try repository.schedule(task, startDate: start.addingTimeInterval(60 * 60), endDate: start.addingTimeInterval(2 * 60 * 60))
    #expect(first.id == updated.id)
    #expect(try repository.fetchSchedules().count == 1)
    #expect(updated.endDate.timeIntervalSince(updated.startDate) == 60 * 60)

    #expect(throws: OrbitRepositoryError.invalidScheduleRange) {
        try repository.schedule(task, startDate: start, endDate: start)
    }
    try repository.delete(task)
    #expect(try repository.fetchSchedules().isEmpty)
}

@Test @MainActor func v1StoreMigratesToAddTaskSchedules() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "OrbitMigrationTests")
        .appending(path: UUID().uuidString)
    let storeURL = directory.appending(path: "Orbit.store")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let v1Schema = Schema(OrbitSchemaV1.models)
    let v1Configuration = ModelConfiguration("Orbit", schema: v1Schema, url: storeURL, cloudKitDatabase: .none)
    let v1Container = try ModelContainer(for: v1Schema, configurations: [v1Configuration])
    let legacyTask = OrbitTask(title: "Existing task", status: .planned)
    v1Container.mainContext.insert(legacyTask)
    try v1Container.mainContext.save()

    let migratedContainer = try OrbitModelContainer.make(storeURL: storeURL)
    let repository = OrbitRepository(context: migratedContainer.mainContext)
    let task = try #require(repository.fetchTasks().first { $0.title == "Existing task" })
    let start = Date(timeIntervalSinceReferenceDate: 9_200_000)
    _ = try repository.schedule(task, startDate: start, endDate: start.addingTimeInterval(30 * 60))
    #expect(try repository.fetchSchedules().count == 1)
}
