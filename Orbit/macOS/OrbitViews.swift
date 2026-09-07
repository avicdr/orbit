import SwiftUI
import SwiftData

struct MacOrbitCommandCenter: View {
    @Query(filter: #Predicate<Orbit> { $0.archivedAt == nil }, sort: \Orbit.createdAt)
    private var activeOrbits: [Orbit]
    @Query(filter: #Predicate<Orbit> { $0.archivedAt != nil }, sort: \Orbit.createdAt)
    private var archivedOrbits: [Orbit]
    @State private var selectedID: UUID?
    @State private var isPresentingCreate = false
    @State private var isShowingInbox = false
    @State private var isShowingTime = false
    @State private var isShowingTimeline = false
    @State private var isPresentingCapture = false

    private var selectedOrbit: Orbit? {
        (activeOrbits + archivedOrbits).first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                Section {
                    Button {
                        selectedID = nil
                        isShowingInbox = true
                    } label: {
                        Label("Inbox", systemImage: "tray")
                    }
                    .buttonStyle(.plain)
                    Button {
                        selectedID = nil
                        isShowingInbox = false
                        isShowingTimeline = false
                        isShowingTime = true
                    } label: {
                        Label("Time", systemImage: "clock")
                    }
                    .buttonStyle(.plain)
                    Button {
                        selectedID = nil
                        isShowingInbox = false
                        isShowingTime = false
                        isShowingTimeline = true
                    } label: {
                        Label("Timeline", systemImage: "rectangle.3.group")
                    }
                    .buttonStyle(.plain)
                }
                Section("Active Orbits") {
                    ForEach(activeOrbits) { orbit in
                        Label(orbit.name, systemImage: orbit.icon).tag(orbit.id)
                    }
                }
                if !archivedOrbits.isEmpty {
                    Section("Archived") {
                        ForEach(archivedOrbits) { orbit in
                            Label(orbit.name, systemImage: "archivebox").tag(orbit.id)
                        }
                    }
                }
            }
            .navigationTitle("Orbit")
            .toolbar {
                Button("Capture", systemImage: "square.and.pencil") { isPresentingCapture = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("New Orbit", systemImage: "plus") { isPresentingCreate = true }
            }
        } detail: {
            if isShowingTimeline {
                MacTimelineView()
            } else if isShowingTime {
                MacTimeView()
            } else if isShowingInbox {
                MacInboxView()
            } else if let selectedOrbit {
                MacOrbitDetailView(orbit: selectedOrbit)
            } else {
                ContentUnavailableView(
                    "Select an Orbit",
                    systemImage: "circle.grid.2x2",
                    description: Text("Choose an area of life to see its work and direction."))
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            MacOrbitEditorView()
        }
        .sheet(isPresented: $isPresentingCapture) { MacQuickCaptureView() }
        .onChange(of: selectedID) { _, newValue in
            if newValue != nil { isShowingInbox = false; isShowingTime = false; isShowingTimeline = false }
        }
    }
}

private struct MacOrbitDetailView: View {
    @Environment(\.modelContext) private var context
    let orbit: Orbit
    @State private var isPresentingEdit = false
    @State private var isConfirmingArchive = false
    @State private var errorMessage: String?
    @State private var isPresentingGoal = false
    @State private var goalForProject: Goal?
    @State private var projectForTask: Project?
    @State private var editingGoal: Goal?
    @State private var editingProject: Project?
    @State private var editingTask: OrbitTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Image(systemName: orbit.icon)
                    .font(.system(size: 34))
                    .foregroundStyle(MacOrbitColor.token(orbit.colorToken))
                VStack(alignment: .leading, spacing: 6) {
                    Text(orbit.name).font(.largeTitle.weight(.semibold))
                    Text(orbit.orbitDescription.isEmpty ? "An area you’ve chosen to keep in balance." : orbit.orbitDescription)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu("Actions") {
                    Button("Edit Orbit") { isPresentingEdit = true }
                    if orbit.archivedAt == nil {
                        Button("Archive Orbit", role: .destructive) { isConfirmingArchive = true }
                    }
                }
            }
            HStack(spacing: 16) {
                MacOrbitMetric(title: "Goals", value: "\(orbit.goals.count)", icon: "target")
                MacOrbitMetric(title: "Projects", value: "\(orbit.projects.count)", icon: "square.stack.3d.up")
                MacOrbitMetric(title: "Tasks", value: "\(orbit.tasks.count)", icon: "checkmark.circle")
                MacOrbitMetric(title: "Weight", value: orbit.weight.formatted(.number.precision(.fractionLength(2))), icon: "scale.3d")
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goals, projects, and actions").font(.title3.weight(.semibold))
                    Text("Every action stays connected to the outcome it serves.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("New Goal", systemImage: "plus") { isPresentingGoal = true }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if orbit.goals.isEmpty { ContentUnavailableView("No goals yet", systemImage: "target", description: Text("Start with an outcome for this Orbit.")) }
                    ForEach(orbit.goals.sorted { $0.createdAt < $1.createdAt }) { goal in
                        MacGoalOutline(goal: goal, editGoal: { editingGoal = goal }, addProject: { goalForProject = goal }, editProject: { editingProject = $0 }, addTask: { projectForTask = $0 }, editTask: { editingTask = $0 })
                    }
                }
                .padding(.vertical, 4)
            }
            Spacer()
        }
        .padding(32)
        .frame(minWidth: 500, minHeight: 360, alignment: .topLeading)
        .sheet(isPresented: $isPresentingEdit) { MacOrbitEditorView(orbit: orbit) }
        .sheet(isPresented: $isPresentingGoal) { MacGoalEditor(goal: nil, orbit: orbit) }
        .sheet(item: $goalForProject) { MacProjectEditor(project: nil, goal: $0, orbit: orbit) }
        .sheet(item: $projectForTask) { MacTaskEditor(task: nil, project: $0, goal: $0.goal, orbit: orbit) }
        .sheet(item: $editingGoal) { MacGoalEditor(goal: $0, orbit: orbit) }
        .sheet(item: $editingProject) { MacProjectEditor(project: $0, goal: $0.goal, orbit: orbit) }
        .sheet(item: $editingTask) { MacTaskEditor(task: $0, project: $0.project, goal: $0.goal, orbit: $0.orbit) }
        .confirmationDialog("Archive \(orbit.name)?", isPresented: $isConfirmingArchive) {
            Button("Archive Orbit", role: .destructive) { archive() }
        } message: { Text("Its goals, projects, and tasks will stay stored.") }
        .alert("Couldn’t update Orbit", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func archive() {
        do {
            try OrbitRepository(context: context).archive(orbit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MacGoalOutline: View {
    let goal: Goal; let editGoal: () -> Void; let addProject: () -> Void; let editProject: (Project) -> Void; let addTask: (Project) -> Void; let editTask: (OrbitTask) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "target").foregroundStyle(.tint); Text(goal.title).font(.headline); Spacer(); Button("Edit", action: editGoal); Button("Add Project", action: addProject) }
            if !goal.notes.isEmpty { Text(goal.notes).font(.subheadline).foregroundStyle(.secondary) }
            ForEach(goal.projects.sorted { $0.createdAt < $1.createdAt }) { project in
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary); Text(project.title).font(.subheadline.weight(.medium)); Spacer(); Button("Edit") { editProject(project) }; Button("Add Task") { addTask(project) } }
                    ForEach(project.tasks.sorted { $0.createdAt < $1.createdAt }) { task in
                        Button { editTask(task) } label: { HStack { Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle").foregroundStyle(task.status == .completed ? .green : .secondary); Text(task.title).strikethrough(task.status == .completed); Spacer(); Text(task.priority.label).font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain)
                    }
                }.padding(.leading, 24)
            }
        }.padding(16).background(.quaternary, in: .rect(cornerRadius: 12))
    }
}

private struct MacOrbitMetric: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title.weight(.medium))
        }.frame(minWidth: 100, alignment: .leading).padding(16).background(.quaternary, in: .rect(cornerRadius: 12))
    }
}

private struct MacOrbitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let orbit: Orbit?
    @State private var name: String
    @State private var description: String
    @State private var icon: String
    @State private var colorToken: String
    @State private var weight: Double
    @State private var errorMessage: String?

    init(orbit: Orbit? = nil) {
        self.orbit = orbit
        _name = State(initialValue: orbit?.name ?? "")
        _description = State(initialValue: orbit?.orbitDescription ?? "")
        _icon = State(initialValue: orbit?.icon ?? "circle.grid.2x2")
        _colorToken = State(initialValue: orbit?.colorToken ?? "accent")
        _weight = State(initialValue: orbit?.weight ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(orbit == nil ? "New Orbit" : "Edit Orbit").font(.title2.weight(.semibold))
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical).lineLimit(2...4)
                Picker("Icon", selection: $icon) {
                    Text("Orbit").tag("circle.grid.2x2"); Text("Career").tag("briefcase.fill"); Text("Health").tag("heart.fill"); Text("Creative").tag("paintbrush.fill")
                }
                Picker("Color", selection: $colorToken) { ForEach(MacOrbitColor.tokens, id: \.self) { Text($0.capitalized).tag($0) } }
                Slider(value: $weight, in: 0.5...2, step: 0.25) { Text("Attention weight") }
            }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .padding(24).frame(width: 420)
        .alert("Couldn’t save Orbit", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        let repository = OrbitRepository(context: context)
        do {
            if let orbit { try repository.update(orbit, name: name, icon: icon, colorToken: colorToken, description: description, weight: weight) }
            else { _ = try repository.createOrbit(name: name, icon: icon, colorToken: colorToken, description: description, weight: weight) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum MacOrbitColor {
    static let tokens = ["accent", "blue", "purple", "pink", "green", "orange"]
    static func token(_ value: String) -> Color { switch value { case "blue": .blue; case "purple": .purple; case "pink": .pink; case "green": .green; case "orange": .orange; default: .accentColor } }
}
