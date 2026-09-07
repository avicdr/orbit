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

struct MacInboxView: View {
    @Query(filter: #Predicate<OrbitTask> { $0.statusRawValue == "inbox" }, sort: \OrbitTask.createdAt)
    private var inboxTasks: [OrbitTask]
    @State private var organizingTask: OrbitTask?
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inbox").font(.largeTitle.weight(.semibold))
                    Text("Captured thoughts waiting for a deliberate decision.").foregroundStyle(.secondary)
                }
                Spacer()
            }
            if inboxTasks.isEmpty {
                ContentUnavailableView("Inbox zero", systemImage: "tray", description: Text("Use Capture to get thoughts out of your head quickly."))
            } else {
                List(inboxTasks) { task in
                    HStack {
                        Image(systemName: "tray").foregroundStyle(.secondary)
                        Text(task.title)
                        Spacer()
                        Button("Organize") { organizingTask = task }
                        Menu("More") {
                            Button("Archive", role: .destructive) { archive(task) }
                            Button("Delete", role: .destructive) { delete(task) }
                        }
                    }
                }
            }
        }
        .padding(32)
        .sheet(item: $organizingTask) { MacInboxOrganizeView(task: $0) }
        .alert("Couldn’t update Inbox", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
    private func archive(_ task: OrbitTask) { do { try OrbitRepository(context: context).archive(task) } catch { errorMessage = error.localizedDescription } }
    private func delete(_ task: OrbitTask) { do { try OrbitRepository(context: context).delete(task) } catch { errorMessage = error.localizedDescription } }
}

private struct MacInboxOrganizeView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    @Query(sort: \Project.createdAt) private var projects: [Project]
    let task: OrbitTask
    @State private var projectID: UUID?
    @State private var priority: TaskPriority
    @State private var estimateMinutes: Int
    init(task: OrbitTask) { self.task = task; _projectID = State(initialValue: task.project?.id); _priority = State(initialValue: task.priority); _estimateMinutes = State(initialValue: Int((task.estimatedDuration ?? 0) / 60)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Organize Inbox Task").font(.title2.weight(.semibold))
            Text(task.title).foregroundStyle(.secondary)
            Form {
                Picker("Project", selection: $projectID) { Text("Keep unassigned").tag(UUID?.none); ForEach(projects) { Text($0.title).tag(Optional($0.id)) } }
                Picker("Priority", selection: $priority) { ForEach(TaskPriority.allCases, id: \.self) { Text($0.label).tag($0) } }
                Stepper("Estimate: \(estimateMinutes) min", value: $estimateMinutes, in: 0...480, step: 5)
            }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Organize") { save() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 420)
    }
    private func save() { do { let project = projects.first { $0.id == projectID }; try OrbitRepository(context: context).update(task, title: task.title, notes: task.notes, status: .planned, priority: priority, dueDate: task.dueDate, estimatedDuration: estimateMinutes == 0 ? nil : TimeInterval(estimateMinutes * 60), energyRequirement: task.energyRequirement, locationRequirement: task.locationRequirement, project: project, goal: task.goal, orbit: task.orbit, recurrence: task.recurrence); dismiss() } catch {} }
}

struct MacQuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var context
    @FocusState private var isFocused: Bool; @State private var title = ""; @State private var errorMessage: String?
    var body: some View { VStack(alignment: .leading, spacing: 16) { Text("Quick Capture").font(.title2.weight(.semibold)); TextField("What needs attention?", text: $title).focused($isFocused); Text("This enters Inbox without a project, date, or estimate.").font(.caption).foregroundStyle(.secondary); HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Capture") { capture() }.keyboardShortcut(.defaultAction).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.padding(24).frame(width: 420).task { isFocused = true }.alert("Couldn’t capture task", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") } }
    private func capture() { do { _ = try OrbitRepository(context: context).capture(title.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() } catch { errorMessage = error.localizedDescription } }
}
