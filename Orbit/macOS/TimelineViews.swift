import SwiftUI
import SwiftData

struct MacTimelineView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \OrbitTask.createdAt) private var tasks: [OrbitTask]
    @Query(sort: \TaskSchedule.startDate) private var schedules: [TaskSchedule]

    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var editingTask: OrbitTask?
    @State private var pendingChange: PendingTimelineChange?
    @State private var errorMessage: String?

    private let engine = TimelineEngine()

    private var window: DateInterval {
        let start = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: day) ?? day
        return DateInterval(start: start, duration: 12 * 60 * 60)
    }

    private var activeTasks: [OrbitTask] {
        tasks.filter { $0.status == .planned || $0.status == .inProgress }
    }

    private var taskByID: [UUID: OrbitTask] {
        Dictionary(uniqueKeysWithValues: activeTasks.map { ($0.id, $0) })
    }

    private var scheduleByTaskID: [UUID: TaskSchedule] {
        Dictionary(uniqueKeysWithValues: schedules.map { ($0.taskID, $0) })
    }

    private var timelineTasks: [TimelineScheduledTask] {
        schedules.compactMap { schedule in
            guard let task = taskByID[schedule.taskID] else { return nil }
            return TimelineScheduledTask(taskID: task.id, title: task.title, startDate: schedule.startDate, endDate: schedule.endDate)
        }
    }

    private var timeline: TimelineDay {
        engine.day(window: window, scheduledTasks: timelineTasks)
    }

    private var unscheduledTasks: [OrbitTask] {
        activeTasks.filter { scheduleByTaskID[$0.id] == nil }
    }

    private var hourSlots: [Date] {
        (0..<12).compactMap { Calendar.current.date(byAdding: .hour, value: $0, to: window.start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeline").font(.largeTitle.weight(.semibold))
                    Text("Place work deliberately. Orbit never moves other work without asking.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DatePicker("Day", selection: $day, displayedComponents: .date)
                    .labelsHidden()
            }

            if !timeline.conflicts.isEmpty {
                Label("\(timeline.conflicts.count) scheduling conflict\(timeline.conflicts.count == 1 ? "" : "s") need attention.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("\(timeline.conflicts.count) scheduling conflicts need attention")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(hourSlots, id: \.self) { slot in
                        timelineHour(slot)
                    }

                    if !unscheduledTasks.isEmpty {
                        Divider().padding(.vertical, 16)
                        Text("Unscheduled").font(.headline)
                        Text("Drag an action onto an hour, or use Schedule to choose a precise start and duration.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(unscheduledTasks) { task in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                    Text(task.estimatedDuration.map { "\(Int($0 / 60)) min" } ?? "No estimate")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Schedule") { editingTask = task }
                            }
                            .padding(10)
                            .background(.quaternary, in: .rect(cornerRadius: 8))
                            .draggable(task.id.uuidString)
                            .accessibilityLabel("\(task.title), unscheduled task")
                            .accessibilityHint("Drag to an hour or choose Schedule")
                        }
                    }
                }
            }
        }
        .padding(32)
        .sheet(item: $editingTask) { task in
            MacTimelineScheduleEditor(
                task: task,
                existingSchedule: scheduleByTaskID[task.id],
                defaultStart: defaultStart(for: task),
                onSave: { start, duration in requestChange(task, start: start, duration: duration) },
                onUnschedule: { unschedule(task) }
            )
        }
        .confirmationDialog(
            "Schedule conflict",
            isPresented: Binding(get: { pendingChange != nil }, set: { if !$0 { pendingChange = nil } })
        ) {
            Button("Schedule Anyway") {
                if let pendingChange { commit(pendingChange) }
            }
            Button("Cancel", role: .cancel) { pendingChange = nil }
        } message: {
            Text(pendingChange?.conflictDescription ?? "This placement overlaps existing work.")
        }
        .alert("Couldn’t update timeline", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func timelineHour(_ slot: Date) -> some View {
        let hourEnd = Calendar.current.date(byAdding: .hour, value: 1, to: slot) ?? slot.addingTimeInterval(60 * 60)
        let hour = DateInterval(start: slot, end: hourEnd)
        let entries = timeline.entries.filter { $0.interval.start >= hour.start && $0.interval.start < hour.end }
        return HStack(alignment: .top, spacing: 16) {
            Text(slot.formatted(date: .omitted, time: .shortened))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
            VStack(alignment: .leading, spacing: 6) {
                if entries.isEmpty {
                    Text("Free")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                } else {
                    ForEach(entries) { entry in
                        timelineEntry(entry)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(.quaternary.opacity(entries.isEmpty ? 0.45 : 0.9), in: .rect(cornerRadius: 8))
            .dropDestination(for: String.self) { identifiers, _ in
                guard let identifier = identifiers.first, let taskID = UUID(uuidString: identifier), let task = taskByID[taskID] else { return false }
                let duration = scheduleByTaskID[taskID].map { $0.endDate.timeIntervalSince($0.startDate) } ?? task.estimatedDuration ?? 30 * 60
                requestChange(task, start: slot, duration: duration)
                return true
            }
            .accessibilityLabel("\(slot.formatted(date: .omitted, time: .shortened)) timeline slot")
            .accessibilityHint("Drop a task here to schedule it")
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func timelineEntry(_ entry: TimelineEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.kind == .task ? "checkmark.circle" : "calendar")
                .foregroundStyle(entry.kind == .task ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.subheadline.weight(.medium))
                Text("\(entry.interval.start.formatted(date: .omitted, time: .shortened)) – \(entry.interval.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let taskID = entry.taskID, let task = taskByID[taskID] {
                Button("Edit") { editingTask = task }
                    .buttonStyle(.borderless)
                    .draggable(task.id.uuidString)
            }
        }
        .padding(8)
        .background(entry.kind == .task ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1), in: .rect(cornerRadius: 7))
        .accessibilityElement(children: .combine)
    }

    private func defaultStart(for task: OrbitTask) -> Date {
        scheduleByTaskID[task.id]?.startDate ?? (Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day)
    }

    private func requestChange(_ task: OrbitTask, start: Date, duration: TimeInterval) {
        guard let proposal = engine.proposeMove(taskID: task.id, startDate: start, duration: duration, scheduledTasks: timelineTasks) else {
            errorMessage = "Choose a duration greater than zero."
            return
        }
        let change = PendingTimelineChange(task: task, proposal: proposal)
        if proposal.requiresConfirmation {
            pendingChange = change
        } else {
            commit(change)
        }
    }

    private func commit(_ change: PendingTimelineChange) {
        do {
            _ = try OrbitRepository(context: context).schedule(
                change.task,
                startDate: change.proposal.interval.start,
                endDate: change.proposal.interval.end
            )
            pendingChange = nil
            editingTask = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unschedule(_ task: OrbitTask) {
        do {
            try OrbitRepository(context: context).unschedule(task)
            editingTask = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PendingTimelineChange {
    let task: OrbitTask
    let proposal: TimelineMoveProposal

    var conflictDescription: String {
        let names = proposal.conflicts.map(\.conflictingTitle).joined(separator: ", ")
        return "\(task.title) overlaps \(names). Orbit will not move or resize those items automatically."
    }
}

private struct MacTimelineScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let task: OrbitTask
    let existingSchedule: TaskSchedule?
    let onSave: (Date, TimeInterval) -> Void
    let onUnschedule: () -> Void
    @State private var startDate: Date
    @State private var minutes: Int

    init(
        task: OrbitTask,
        existingSchedule: TaskSchedule?,
        defaultStart: Date,
        onSave: @escaping (Date, TimeInterval) -> Void,
        onUnschedule: @escaping () -> Void
    ) {
        self.task = task
        self.existingSchedule = existingSchedule
        self.onSave = onSave
        self.onUnschedule = onUnschedule
        _startDate = State(initialValue: existingSchedule?.startDate ?? defaultStart)
        _minutes = State(initialValue: max(15, Int((existingSchedule.map { $0.endDate.timeIntervalSince($0.startDate) } ?? task.estimatedDuration ?? 30 * 60) / 60)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existingSchedule == nil ? "Schedule task" : "Edit placement")
                .font(.title2.weight(.semibold))
            Text(task.title).foregroundStyle(.secondary)
            Form {
                DatePicker("Start", selection: $startDate)
                Stepper("Duration: \(minutes) min", value: $minutes, in: 15...480, step: 15)
            }
            HStack {
                if existingSchedule != nil {
                    Button("Remove from Timeline", role: .destructive) { onUnschedule(); dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(startDate, TimeInterval(minutes * 60)); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430)
    }
}
