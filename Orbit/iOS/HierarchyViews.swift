import SwiftUI
import SwiftData

struct IOSGoalDetailView: View {
    @Environment(\.modelContext) private var context
    let goal: Goal
    @State private var showProjectEditor = false
    @State private var showGoalEditor = false

    var body: some View {
        List {
            Section {
                Text(goal.notes.isEmpty ? "An outcome this work is meant to advance." : goal.notes)
                    .foregroundStyle(goal.notes.isEmpty ? .secondary : .primary)
                LabeledContent("Priority", value: goal.priority.label)
                if let targetDate = goal.targetDate { LabeledContent("Target", value: targetDate.formatted(date: .abbreviated, time: .omitted)) }
            }
            Section("Projects") {
                if goal.projects.isEmpty { Text("Break this outcome into a project when you’re ready.").foregroundStyle(.secondary) }
                ForEach(goal.projects.sorted { $0.createdAt < $1.createdAt }) { project in
                    NavigationLink { IOSProjectDetailView(project: project) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(project.title)
                            Text("\(project.tasks.count) tasks").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Add Project", systemImage: "plus") { showProjectEditor = true }
            }
            if !goal.tasks.filter({ $0.project == nil }).isEmpty {
                Section("Direct actions") {
                    ForEach(goal.tasks.filter { $0.project == nil }) { task in
                        NavigationLink { IOSTaskDetailView(task: task) } label: { IOSTaskRow(task: task) }
                    }
                }
            }
        }
        .navigationTitle(goal.title)
        .toolbar { Menu("Actions") { Button("Add Project", systemImage: "plus") { showProjectEditor = true }; Button("Edit Goal") { showGoalEditor = true } } }
        .sheet(isPresented: $showProjectEditor) { IOSProjectEditorView(goal: goal, orbit: goal.orbit) }
        .sheet(isPresented: $showGoalEditor) { IOSGoalEditorView(goal: goal, orbit: goal.orbit) }
    }
}

private struct IOSProjectDetailView: View {
    @Environment(\.modelContext) private var context
    let project: Project
    @State private var showTaskEditor = false
    @State private var showProjectEditor = false

    var body: some View {
        List {
            Section {
                Text(project.notes.isEmpty ? "A focused body of work in service of \(project.goal?.title ?? "this Orbit")." : project.notes)
                    .foregroundStyle(project.notes.isEmpty ? .secondary : .primary)
                LabeledContent("Goal", value: project.goal?.title ?? "Unassigned")
                LabeledContent("Priority", value: project.priority.label)
                if let deadline = project.deadline { LabeledContent("Deadline", value: deadline.formatted(date: .abbreviated, time: .omitted)) }
            }
            Section("Actions") {
                if project.tasks.isEmpty { Text("Add the smallest useful next action.").foregroundStyle(.secondary) }
                ForEach(project.tasks.sorted { $0.createdAt < $1.createdAt }) { task in
                    NavigationLink { IOSTaskDetailView(task: task) } label: { IOSTaskRow(task: task) }
                        .swipeActions {
                            if task.status != .completed {
                                Button("Complete") { try? complete(task) }.tint(.green)
                            }
                        }
                }
                Button("Add Task", systemImage: "plus") { showTaskEditor = true }
            }
        }
        .navigationTitle(project.title)
        .toolbar { Menu("Actions") { Button("Add Task", systemImage: "plus") { showTaskEditor = true }; Button("Edit Project") { showProjectEditor = true } } }
        .sheet(isPresented: $showTaskEditor) { IOSTaskEditorView(project: project, goal: project.goal, orbit: project.orbit) }
        .sheet(isPresented: $showProjectEditor) { IOSProjectEditorView(project: project, goal: project.goal, orbit: project.orbit) }
    }

    private func complete(_ task: OrbitTask) throws {
        try OrbitRepository(context: context).complete(task)
    }
}

struct IOSTaskRow: View {
    let task: OrbitTask
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.status == .completed ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title).strikethrough(task.status == .completed)
                Text(taskMeta(task)).font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct IOSTaskDetailView: View {
    @Environment(\.modelContext) private var context
    let task: OrbitTask
    @State private var showEditor = false
    @State private var errorMessage: String?
    var body: some View {
        List {
            Section("Why this matters") {
                LabeledContent("Project", value: task.project?.title ?? "Not assigned")
                LabeledContent("Goal", value: task.goal?.title ?? "Not assigned")
                LabeledContent("Orbit", value: task.orbit?.name ?? "Not assigned")
            }
            Section("Details") {
                if !task.notes.isEmpty { Text(task.notes) }
                LabeledContent("Status", value: task.status.rawValue.capitalized)
                LabeledContent("Priority", value: task.priority.label)
                if let dueDate = task.dueDate { LabeledContent("Due", value: dueDate.formatted(date: .abbreviated, time: .omitted)) }
                if let estimate = task.estimatedDuration { LabeledContent("Estimate", value: estimate.formattedMinutes) }
                if let energy = task.energyRequirement { LabeledContent("Energy", value: energy.rawValue.capitalized) }
                if let location = task.locationRequirement, !location.isEmpty { LabeledContent("Location", value: location) }
            }
            Section {
                Button(task.status == .completed ? "Reopen Task" : "Complete Task", systemImage: task.status == .completed ? "arrow.uturn.backward" : "checkmark.circle") { transition() }
            }
        }
        .navigationTitle(task.title)
        .toolbar { Button("Edit") { showEditor = true } }
        .sheet(isPresented: $showEditor) { IOSTaskEditorView(task: task, project: task.project, goal: task.goal, orbit: task.orbit) }
        .alert("Couldn’t update task", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
    private func transition() { do { let repository = OrbitRepository(context: context); if task.status == .completed { try repository.reopen(task) } else { try repository.complete(task) } } catch { errorMessage = error.localizedDescription } }
}

struct IOSGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let goal: Goal?; let orbit: Orbit?
    @State private var title: String; @State private var notes: String; @State private var priority: TaskPriority; @State private var hasDate: Bool; @State private var date: Date
    init(goal: Goal? = nil, orbit: Orbit?) { self.goal = goal; self.orbit = orbit; _title = State(initialValue: goal?.title ?? ""); _notes = State(initialValue: goal?.notes ?? ""); _priority = State(initialValue: goal?.priority ?? .normal); _hasDate = State(initialValue: goal?.targetDate != nil); _date = State(initialValue: goal?.targetDate ?? .now) }
    var body: some View {
        NavigationStack {
            Form {
                goalDetails
                targetDateSection
            }
            .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isTitleEmpty)
                }
            }
        }
    }

    private var goalDetails: some View {
        Group {
            TextField("Outcome", text: $title)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
            Picker("Priority", selection: $priority) {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Text(priority.label).tag(priority)
                }
            }
        }
    }

    private var targetDateSection: some View {
        Group {
            Toggle("Target date", isOn: $hasDate)
            if hasDate {
                DatePicker("Target", selection: $date, displayedComponents: .date)
            }
        }
    }

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private func save() { do { let repo = OrbitRepository(context: context); if let goal { try repo.update(goal, title: title, notes: notes, priority: priority, targetDate: hasDate ? date : nil, status: goal.status) } else { _ = try repo.createGoal(title: title, orbit: orbit, notes: notes, priority: priority, targetDate: hasDate ? date : nil) }; dismiss() } catch {} }
}

private struct IOSProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let project: Project?; let goal: Goal?; let orbit: Orbit?
    @State private var title: String; @State private var notes: String; @State private var priority: TaskPriority; @State private var hasDate: Bool; @State private var date: Date
    init(project: Project? = nil, goal: Goal?, orbit: Orbit?) { self.project = project; self.goal = goal; self.orbit = orbit; _title = State(initialValue: project?.title ?? ""); _notes = State(initialValue: project?.notes ?? ""); _priority = State(initialValue: project?.priority ?? .normal); _hasDate = State(initialValue: project?.deadline != nil); _date = State(initialValue: project?.deadline ?? .now) }
    var body: some View { NavigationStack { Form { TextField("Project", text: $title); TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4); Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } }; Toggle("Deadline", isOn: $hasDate); if hasDate { DatePicker("Deadline", selection: $date, displayedComponents: .date) } }.navigationTitle(project == nil ? "New Project" : "Edit Project").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
    private func save() { do { let repo = OrbitRepository(context: context); if let project { try repo.update(project, title: title, notes: notes, priority: priority, deadline: hasDate ? date : nil, status: project.status, goal: goal, orbit: orbit) } else { _ = try repo.createProject(title: title, goal: goal, orbit: orbit, notes: notes, priority: priority, deadline: hasDate ? date : nil) }; dismiss() } catch {} }
}

struct IOSTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    @Query(sort: \Orbit.createdAt) private var orbits: [Orbit]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    let task: OrbitTask?
    @State private var title: String; @State private var notes: String; @State private var status: TaskStatus; @State private var priority: TaskPriority; @State private var due: Date; @State private var hasDue: Bool; @State private var minutes: Int; @State private var energy: EnergyLevel?; @State private var location: String; @State private var orbitID: UUID?; @State private var goalID: UUID?; @State private var projectID: UUID?
    init(task: OrbitTask? = nil, project: Project?, goal: Goal?, orbit: Orbit?) { self.task = task; _title = State(initialValue: task?.title ?? ""); _notes = State(initialValue: task?.notes ?? ""); _status = State(initialValue: task?.status ?? .planned); _priority = State(initialValue: task?.priority ?? .normal); _due = State(initialValue: task?.dueDate ?? .now); _hasDue = State(initialValue: task?.dueDate != nil); _minutes = State(initialValue: Int((task?.estimatedDuration ?? 0) / 60)); _energy = State(initialValue: task?.energyRequirement); _location = State(initialValue: task?.locationRequirement ?? ""); _orbitID = State(initialValue: task?.orbit?.id ?? orbit?.id); _goalID = State(initialValue: task?.goal?.id ?? goal?.id); _projectID = State(initialValue: task?.project?.id ?? project?.id) }
    var body: some View { NavigationStack { Form { Section("Action") { TextField("Task", text: $title); TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...4); Picker("Status", selection: $status) { ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }; Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } } }; Section("Why it matters") { Picker("Orbit", selection: $orbitID) { Text("None").tag(UUID?.none); ForEach(orbits) { Text($0.name).tag(Optional($0.id)) } }; Picker("Goal", selection: $goalID) { Text("None").tag(UUID?.none); ForEach(goals) { Text($0.title).tag(Optional($0.id)) } }; Picker("Project", selection: $projectID) { Text("None").tag(UUID?.none); ForEach(projects) { Text($0.title).tag(Optional($0.id)) } } }; Section("Context") { Toggle("Due date", isOn: $hasDue); if hasDue { DatePicker("Due", selection: $due, displayedComponents: .date) }; Stepper("Estimate: \(minutes) min", value: $minutes, in: 0...480, step: 5); Picker("Energy", selection: $energy) { Text("Unspecified").tag(EnergyLevel?.none); ForEach(EnergyLevel.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }; TextField("Location requirement", text: $location) } }.navigationTitle(task == nil ? "New Task" : "Edit Task").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
    private func save() { do { let project = projects.first { $0.id == projectID }; let goal = goals.first { $0.id == goalID }; let orbit = orbits.first { $0.id == orbitID }; let repo = OrbitRepository(context: context); if let task { try repo.update(task, title: title, notes: notes, status: status, priority: priority, dueDate: hasDue ? due : nil, estimatedDuration: minutes == 0 ? nil : TimeInterval(minutes * 60), energyRequirement: energy, locationRequirement: location.isEmpty ? nil : location, project: project, goal: goal, orbit: orbit, recurrence: task.recurrence) } else { _ = try repo.createTask(title: title, project: project, goal: goal, orbit: orbit, notes: notes, status: status, priority: priority, dueDate: hasDue ? due : nil, estimatedDuration: minutes == 0 ? nil : TimeInterval(minutes * 60), energyRequirement: energy, locationRequirement: location.isEmpty ? nil : location) }; dismiss() } catch {} }
}

private extension TaskPriority { var label: String { switch self { case .low: "Low"; case .normal: "Normal"; case .high: "High"; case .critical: "Critical" } } }
private extension TimeInterval { var formattedMinutes: String { "\(Int(self / 60)) min" } }
private func taskMeta(_ task: OrbitTask) -> String { [task.priority.label, task.estimatedDuration.map { $0.formattedMinutes }].compactMap { $0 }.joined(separator: " · ") }
