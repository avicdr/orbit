import SwiftUI
import SwiftData

private extension TaskPriority {
    var label: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}

struct MacGoalEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let goal: Goal?; let orbit: Orbit
    @State private var title: String; @State private var notes: String; @State private var priority: TaskPriority
    init(goal: Goal?, orbit: Orbit) { self.goal = goal; self.orbit = orbit; _title = State(initialValue: goal?.title ?? ""); _notes = State(initialValue: goal?.notes ?? ""); _priority = State(initialValue: goal?.priority ?? .normal) }
    var body: some View { hierarchySheet(title: goal == nil ? "New Goal" : "Edit Goal") { Form { TextField("Outcome", text: $title); TextField("Notes", text: $notes, axis: .vertical); Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } } } } save: { do { let repo = OrbitRepository(context: context); if let goal { try repo.update(goal, title: title, notes: notes, priority: priority, targetDate: goal.targetDate, status: goal.status) } else { _ = try repo.createGoal(title: title, orbit: orbit, notes: notes, priority: priority) }; dismiss() } catch {} } }
    private func hierarchySheet<Content: View>(title: String, @ViewBuilder content: () -> Content, save: @escaping () -> Void) -> some View { VStack(alignment: .leading) { Text(title).font(.title2); content(); HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save", action: save).keyboardShortcut(.defaultAction).disabled(title.isEmpty) } }.padding(24).frame(width: 420) }
}

struct MacProjectEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let project: Project?; let goal: Goal?; let orbit: Orbit
    @State private var title: String; @State private var notes: String; @State private var priority: TaskPriority
    init(project: Project?, goal: Goal?, orbit: Orbit) { self.project = project; self.goal = goal; self.orbit = orbit; _title = State(initialValue: project?.title ?? ""); _notes = State(initialValue: project?.notes ?? ""); _priority = State(initialValue: project?.priority ?? .normal) }
    var body: some View { VStack(alignment: .leading) { Text(project == nil ? "New Project" : "Edit Project").font(.title2); Form { TextField("Project", text: $title); TextField("Notes", text: $notes, axis: .vertical); Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } } }; HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(title.isEmpty) } }.padding(24).frame(width: 420) }
    private func save() { do { let repo = OrbitRepository(context: context); if let project { try repo.update(project, title: title, notes: notes, priority: priority, deadline: project.deadline, status: project.status, goal: goal, orbit: orbit) } else { _ = try repo.createProject(title: title, goal: goal, orbit: orbit, notes: notes, priority: priority) }; dismiss() } catch {} }
}

struct MacTaskEditor: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    let task: OrbitTask?; let project: Project?; let goal: Goal?; let orbit: Orbit?
    @State private var title: String; @State private var notes: String; @State private var status: TaskStatus; @State private var priority: TaskPriority; @State private var minutes: Int; @State private var energy: EnergyLevel?
    init(task: OrbitTask?, project: Project?, goal: Goal?, orbit: Orbit?) { self.task = task; self.project = project; self.goal = goal; self.orbit = orbit; _title = State(initialValue: task?.title ?? ""); _notes = State(initialValue: task?.notes ?? ""); _status = State(initialValue: task?.status ?? .planned); _priority = State(initialValue: task?.priority ?? .normal); _minutes = State(initialValue: Int((task?.estimatedDuration ?? 0) / 60)); _energy = State(initialValue: task?.energyRequirement) }
    var body: some View { VStack(alignment: .leading) { Text(task == nil ? "New Task" : "Edit Task").font(.title2); Text("Project: \(project?.title ?? "Unassigned") · Goal: \(goal?.title ?? "Unassigned")").foregroundStyle(.secondary); Form { TextField("Action", text: $title); TextField("Notes", text: $notes, axis: .vertical); Picker("Status", selection: $status) { ForEach(TaskStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }; Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } }; Picker("Energy requirement", selection: $energy) { Text("Unspecified").tag(EnergyLevel?.none); ForEach(EnergyLevel.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }; Stepper("Estimate: \(minutes) min", value: $minutes, in: 0...480, step: 5) }; HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(title.isEmpty) } }.padding(24).frame(width: 440) }
    private func save() { do { let repo = OrbitRepository(context: context); if let task { try repo.update(task, title: title, notes: notes, status: status, priority: priority, dueDate: task.dueDate, estimatedDuration: minutes == 0 ? nil : TimeInterval(minutes * 60), energyRequirement: energy, locationRequirement: task.locationRequirement, project: project, goal: goal, orbit: orbit, recurrence: task.recurrence) } else { _ = try repo.createTask(title: title, project: project, goal: goal, orbit: orbit, notes: notes, status: status, priority: priority, estimatedDuration: minutes == 0 ? nil : TimeInterval(minutes * 60), energyRequirement: energy) }; dismiss() } catch {} }
}
