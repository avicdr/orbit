import SwiftUI
import SwiftData

struct IOSOrbitOverviewView: View {
    @Query(filter: #Predicate<Orbit> { $0.archivedAt == nil }, sort: \Orbit.createdAt)
    private var orbits: [Orbit]
    @State private var isPresentingCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if orbits.isEmpty {
                    ContentUnavailableView(
                        "Create your first Orbit",
                        systemImage: "circle.grid.2x2",
                        description: Text("Orbits keep the parts of your life that matter in view."))
                } else {
                    List(orbits) { orbit in
                        NavigationLink(value: orbit) {
                            IOSOrbitRow(orbit: orbit)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Orbits")
            .navigationDestination(for: Orbit.self) { orbit in
                IOSOrbitDetailView(orbit: orbit)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Create Orbit", systemImage: "plus") {
                        isPresentingCreate = true
                    }
                    .accessibilityHint("Creates a new life area")
                }
            }
            .sheet(isPresented: $isPresentingCreate) {
                IOSOrbitEditorView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct IOSOrbitRow: View {
    let orbit: Orbit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: orbit.icon)
                .font(.title3)
                .foregroundStyle(OrbitColor.token(orbit.colorToken))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(orbit.name).font(.headline)
                Text(orbitSummary(orbit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(orbit.name), \(orbitSummary(orbit))")
    }
}

private struct IOSOrbitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let orbit: Orbit
    @State private var isPresentingEdit = false
    @State private var isPresentingGoalCreate = false
    @State private var isConfirmingArchive = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: orbit.icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(OrbitColor.token(orbit.colorToken))
                        .frame(width: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(orbit.name).font(.title2.weight(.semibold))
                        if !orbit.orbitDescription.isEmpty {
                            Text(orbit.orbitDescription).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            Section("In this Orbit") {
                OrbitCountRow(title: "Goals", count: orbit.goals.count, icon: "target")
                OrbitCountRow(title: "Projects", count: orbit.projects.count, icon: "square.stack.3d.up")
                OrbitCountRow(title: "Tasks", count: orbit.tasks.count, icon: "checkmark.circle")
            }

            Section("Goals") {
                if orbit.goals.isEmpty {
                    Text("Start with an outcome this Orbit should move forward.")
                        .foregroundStyle(.secondary)
                }
                ForEach(orbit.goals.sorted { $0.createdAt < $1.createdAt }) { goal in
                    NavigationLink { IOSGoalDetailView(goal: goal) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.title)
                            Text("\(goal.projects.count) projects · \(goal.tasks.count) direct tasks")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Add Goal", systemImage: "plus") { isPresentingGoalCreate = true }
            }

            Section("Attention") {
                LabeledContent("Weight") {
                    Text(orbit.weight, format: .number.precision(.fractionLength(1)))
                }
                Text("Weight helps Orbit later balance attention across the areas you care about.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Archive Orbit", role: .destructive) {
                    isConfirmingArchive = true
                }
            }
        }
        .navigationTitle(orbit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu("Actions") {
                Button("Add Goal", systemImage: "target") { isPresentingGoalCreate = true }
                Button("Edit Orbit") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            IOSOrbitEditorView(orbit: orbit)
        }
        .sheet(isPresented: $isPresentingGoalCreate) { IOSGoalEditorView(orbit: orbit) }
        .confirmationDialog(
            "Archive \(orbit.name)?",
            isPresented: $isConfirmingArchive,
            titleVisibility: .visible
        ) {
            Button("Archive Orbit", role: .destructive) { archive() }
        } message: {
            Text("Its goals, projects, and tasks will remain safely stored.")
        }
        .alert("Couldn’t update Orbit", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func archive() {
        do {
            try OrbitRepository(context: context).archive(orbit)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct OrbitCountRow: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        Label {
            LabeledContent(title) { Text(count, format: .number) }
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(count) \(title)")
    }
}

private struct IOSOrbitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let orbit: Orbit?
    @State private var name: String
    @State private var icon: String
    @State private var colorToken: String
    @State private var description: String
    @State private var weight: Double
    @State private var errorMessage: String?

    init(orbit: Orbit? = nil) {
        self.orbit = orbit
        _name = State(initialValue: orbit?.name ?? "")
        _icon = State(initialValue: orbit?.icon ?? "circle.grid.2x2")
        _colorToken = State(initialValue: orbit?.colorToken ?? "accent")
        _description = State(initialValue: orbit?.orbitDescription ?? "")
        _weight = State(initialValue: orbit?.weight ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                orbitDetailsSection
                appearanceSection
                attentionSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(orbit == nil ? "New Orbit" : "Edit Orbit")
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isNameEmpty)
                }
            }
            .alert("Couldn’t save Orbit", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private var orbitDetailsSection: some View {
        Section("Orbit") {
            TextField("Name", text: $name, prompt: Text("e.g. Learning"))
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Orbit name")
            TextField("Description", text: $description, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...5)
                .accessibilityLabel("Orbit description")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Icon", selection: $icon) {
                Label("Orbit", systemImage: "circle.grid.2x2").tag("circle.grid.2x2")
                Label("Career", systemImage: "briefcase.fill").tag("briefcase.fill")
                Label("Health", systemImage: "heart.fill").tag("heart.fill")
                Label("Creative", systemImage: "paintbrush.fill").tag("paintbrush.fill")
            }
            Picker("Color", selection: $colorToken) {
                ForEach(OrbitColor.tokens, id: \.self) { token in
                    Text(token.capitalized).tag(token)
                }
            }
        }
    }

    private var attentionSection: some View {
        Section("Attention") {
            Slider(value: $weight, in: 0.5...2, step: 0.25) {
                Text("Weight")
            } minimumValueLabel: { Text("0.5") } maximumValueLabel: { Text("2") }
            Text("\(weight, format: .number.precision(.fractionLength(2)))× relative weight")
                .foregroundStyle(.secondary)
        }
    }

    private var isNameEmpty: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            let repository = OrbitRepository(context: context)
            if let orbit {
                try repository.update(orbit, name: name, icon: icon, colorToken: colorToken, description: description, weight: weight)
            } else {
                _ = try repository.createOrbit(name: name, icon: icon, colorToken: colorToken, description: description, weight: weight)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum OrbitColor {
    static let tokens = ["accent", "blue", "purple", "pink", "green", "orange"]

    static func token(_ value: String) -> Color {
        switch value {
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "green": .green
        case "orange": .orange
        default: .accentColor
        }
    }
}

private func orbitSummary(_ orbit: Orbit) -> String {
    "\(orbit.goals.count) goals · \(orbit.projects.count) projects · \(orbit.tasks.count) tasks"
}
