import SwiftUI
import SwiftData

struct IOSTimeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \OrbitTask.createdAt) private var tasks: [OrbitTask]
    @Query(sort: \DailyState.date) private var dailyStates: [DailyState]
    @State private var availableMinutes = 360
    @State private var energyLevel: EnergyLevel?
    @State private var didLoad = false
    @State private var errorMessage: String?

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var summary: TimeSummary { TimeEngine().summarize(plan) }
    private var plan: TimePlan {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        let window = DateInterval(start: start, duration: 8 * 60 * 60)
        let planned = tasks.filter { task in
            (task.status == .planned || task.status == .inProgress) && task.dueDate.map { Calendar.current.isDate($0, inSameDayAs: today) } == true
        }.reduce(0) { $0 + Int(($1.estimatedDuration ?? 0) / 60) }
        return TimePlan(workingWindow: window, manuallyAvailableMinutes: availableMinutes, unscheduledPlannedMinutes: planned)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Available working time") { Text("\(summary.availableMinutes) min") }
                    LabeledContent("Calendar commitments") { Text("\(summary.calendarCommittedMinutes) min") }
                    LabeledContent("Planned tasks") { Text("\(summary.plannedTaskMinutes) min") }
                    LabeledContent("Free time") { Text("\(summary.freeMinutes) min").foregroundStyle(summary.freeMinutes == 0 ? .secondary : .primary) }
                    if summary.isOverloaded {
                        LabeledContent("Overload") { Text("\(summary.overloadedMinutes) min").foregroundStyle(.red) }
                    }
                } header: { Text("Today") } footer: {
                    Text("Calendar commitments are zero until you connect a calendar. Planned tasks are tasks due today with an estimate.")
                }
                Section("Set available time") {
                    Stepper("\(availableMinutes / 60)h \(availableMinutes % 60)m", value: $availableMinutes, in: 0...960, step: 30)
                    Button("Save available time") { save() }
                }
                Section("Energy check-in") {
                    Picker("How’s your energy?", selection: $energyLevel) {
                        Text("Not set").tag(EnergyLevel?.none)
                        ForEach(EnergyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(Optional(level))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Text("This is productivity context, not a health assessment.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Save energy") { saveEnergy() }
                }
                if !summary.freeWindows.isEmpty {
                    Section("Free windows") {
                        ForEach(Array(summary.freeWindows.enumerated()), id: \.offset) { _, window in
                            Text("\(window.start.formatted(date: .omitted, time: .shortened)) – \(window.end.formatted(date: .omitted, time: .shortened))")
                        }
                    }
                }
            }
            .navigationTitle("Time")
            .onAppear { load() }
            .alert("Couldn’t save availability", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
        }
    }
    private func load() { guard !didLoad else { return }; let state = dailyStates.first { Calendar.current.isDate($0.date, inSameDayAs: today) }; availableMinutes = state?.availableMinutes ?? 360; energyLevel = state?.energyLevel; didLoad = true }
    private func save() { do { _ = try OrbitRepository(context: context).updateDailyState(for: today, availableMinutes: availableMinutes) } catch { errorMessage = error.localizedDescription } }
    private func saveEnergy() { do { _ = try OrbitRepository(context: context).updateDailyEnergy(for: today, energyLevel: energyLevel) } catch { errorMessage = error.localizedDescription } }
}
