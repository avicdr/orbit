import SwiftUI
import SwiftData

struct IOSAppRootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            IOSNowView()
                .tabItem { Label("Now", systemImage: "scope") }
            IOSOrbitOverviewView()
                .tabItem { Label("Orbits", systemImage: "circle.grid.2x2") }
            IOSInboxView()
                .tabItem { Label("Inbox", systemImage: "tray") }
            IOSTimeView()
                .tabItem { Label("Time", systemImage: "clock") }
        }
        #if targetEnvironment(simulator)
        .task {
            try? OrbitDevelopmentData.seedIfNeeded(into: context)
        }
        #endif
    }
}

struct IOSInboxView: View {
    @Query(filter: #Predicate<OrbitTask> { $0.statusRawValue == "inbox" }, sort: \OrbitTask.createdAt)
    private var inboxTasks: [OrbitTask]
    @State private var isPresentingCapture = false
    @State private var organizingTask: OrbitTask?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if inboxTasks.isEmpty {
                    ContentUnavailableView(
                        "Inbox zero",
                        systemImage: "tray",
                        description: Text("Capture anything that comes to mind. You can decide what it means later."))
                } else {
                    List(inboxTasks) { task in
                        HStack(spacing: 12) {
                            Image(systemName: "tray")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                Text("Unassigned")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Organize") { organizingTask = task }
                                .buttonStyle(.borderless)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(task.title), Inbox task")
                        .swipeActions(edge: .trailing) {
                            Button("Archive", role: .destructive) { archive(task) }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Delete", role: .destructive) { delete(task) }
                        }
                    }
                }
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Capture", systemImage: "plus") { isPresentingCapture = true }
                        .accessibilityHint("Captures a thought without planning it")
                }
            }
            .sheet(isPresented: $isPresentingCapture) { IOSQuickCaptureView() }
            .sheet(item: $organizingTask) { task in
                IOSTaskEditorView(task: task, project: task.project, goal: task.goal, orbit: task.orbit)
            }
            .alert("Couldn’t update Inbox", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    @Environment(\.modelContext) private var context
    private func archive(_ task: OrbitTask) { do { try OrbitRepository(context: context).archive(task) } catch { errorMessage = error.localizedDescription } }
    private func delete(_ task: OrbitTask) { do { try OrbitRepository(context: context).delete(task) } catch { errorMessage = error.localizedDescription } }
}

private struct IOSQuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var isFocused: Bool
    @State private var title = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What’s on your mind?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($isFocused)
                } footer: {
                    Text("Orbit will keep this in Inbox until you decide where it belongs.")
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { capture() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { isFocused = true }
            .alert("Couldn’t capture task", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }

    private func capture() {
        do {
            _ = try OrbitRepository(context: context).capture(title.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
