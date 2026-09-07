import SwiftUI
import SwiftData

struct MacTimeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \OrbitTask.createdAt) private var tasks: [OrbitTask]
    @Query(sort: \DailyState.date) private var dailyStates: [DailyState]
    @State private var availableMinutes = 360
    @State private var energyLevel: EnergyLevel?
    @State private var didLoad = false
    @State private var errorMessage: String?
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var summary: TimeSummary {
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        let planned = tasks.filter { ($0.status == .planned || $0.status == .inProgress) && $0.dueDate.map { Calendar.current.isDate($0, inSameDayAs: today) } == true }.reduce(0) { $0 + Int(($1.estimatedDuration ?? 0) / 60) }
        return TimeEngine().summarize(TimePlan(workingWindow: DateInterval(start: start, duration: 8 * 60 * 60), manuallyAvailableMinutes: availableMinutes, unscheduledPlannedMinutes: planned))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) { Text("Time").font(.largeTitle.weight(.semibold)); Text("A clear view of today’s real capacity.").foregroundStyle(.secondary) }
            HStack(spacing: 16) {
                MacTimeMetric(title: "Available", minutes: summary.availableMinutes, icon: "clock")
                MacTimeMetric(title: "Calendar", minutes: summary.calendarCommittedMinutes, icon: "calendar")
                MacTimeMetric(title: "Planned", minutes: summary.plannedTaskMinutes, icon: "checkmark.circle")
                MacTimeMetric(title: summary.isOverloaded ? "Overload" : "Free", minutes: summary.isOverloaded ? summary.overloadedMinutes : summary.freeMinutes, icon: summary.isOverloaded ? "exclamationmark.triangle" : "sun.max", emphasized: summary.isOverloaded)
            }
            Form { Stepper("Available working time: \(availableMinutes / 60)h \(availableMinutes % 60)m", value: $availableMinutes, in: 0...960, step: 30); Button("Save available time") { save() }; Picker("Energy", selection: $energyLevel) { Text("Not set").tag(EnergyLevel?.none); ForEach(EnergyLevel.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }; Button("Save energy") { saveEnergy() } }
                .frame(maxWidth: 460)
            Text("Calendar commitments will appear here when Calendar integration is enabled. Until then, Orbit uses your manually entered availability and estimated tasks due today.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(32).onAppear { load() }
        .alert("Couldn’t save availability", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
    private func load() { guard !didLoad else { return }; let state = dailyStates.first { Calendar.current.isDate($0.date, inSameDayAs: today) }; availableMinutes = state?.availableMinutes ?? 360; energyLevel = state?.energyLevel; didLoad = true }
    private func save() { do { _ = try OrbitRepository(context: context).updateDailyState(for: today, availableMinutes: availableMinutes) } catch { errorMessage = error.localizedDescription } }
    private func saveEnergy() { do { _ = try OrbitRepository(context: context).updateDailyEnergy(for: today, energyLevel: energyLevel) } catch { errorMessage = error.localizedDescription } }
}

private struct MacTimeMetric: View {
    let title: String; let minutes: Int; let icon: String; var emphasized = false
    var body: some View { VStack(alignment: .leading, spacing: 8) { Label(title, systemImage: icon).font(.subheadline).foregroundStyle(emphasized ? .red : .secondary); Text("\(minutes) min").font(.title.weight(.medium)) }.frame(minWidth: 110, alignment: .leading).padding(16).background(.quaternary, in: .rect(cornerRadius: 12)) }
}
