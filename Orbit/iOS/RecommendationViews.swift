import SwiftUI
import SwiftData

/// The iPhone's focused answer to "what deserves my attention now?".
struct IOSNowView: View {
    @Query(sort: \OrbitTask.createdAt) private var tasks: [OrbitTask]
    @Query(sort: \DailyState.date) private var dailyStates: [DailyState]

    private let engine = RecommendationEngine()
    private let contextEngine = ContextEngine()
    @State private var manualContext: ManualContextSelection?
    @State private var currentWindowMinutes = 30
    @State private var loadedPreferences = false

    private var todayState: DailyState? {
        dailyStates.first { Calendar.current.isDateInToday($0.date) }
    }

    private var snapshot: ContextSnapshot {
        let state = todayState
        let dailyCapacity = state?.availableMinutes
        return contextEngine.resolve(ContextInput(
            now: .now,
            manuallyAvailableMinutes: dailyCapacity.map { min($0, currentWindowMinutes) } ?? currentWindowMinutes,
            energyLevel: state?.energyLevel,
            activeContext: manualContext,
            device: .iPhone
        ))
    }

    private var recommendation: RecommendationResult {
        engine.recommend(
            tasks: tasks.map { RecommendationInputBuilder.make(from: $0) },
            context: contextEngine.recommendationContext(from: snapshot)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let task = recommendation.primary {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("What deserves your attention now?")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(task.task.title)
                                    .font(.title2.weight(.semibold))
                                HStack(spacing: 8) {
                                    if let minutes = task.task.estimatedMinutes {
                                        Label("\(minutes) min", systemImage: "clock")
                                    }
                                    Text("\(task.score.normalized)% fit")
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Recommended now: \(task.task.title), \(task.score.normalized) percent fit")
                        }

                        Section("Why this is a fit") {
                            ForEach(task.explanation, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.circle")
                            }
                        }

                        contextControls

                        Section("Score details") {
                            scoreRow("Priority", task.score.priority)
                            scoreRow("Urgency", task.score.urgency)
                            scoreRow("Goal weight", task.score.goalWeight)
                            scoreRow("Context", task.score.contextMatch)
                            scoreRow("Energy", task.score.energyMatch)
                            scoreRow("Time fit", task.score.timeFit)
                            if task.score.momentum > 0 { scoreRow("Momentum", task.score.momentum) }
                            if task.score.friction > 0 { scoreRow("Friction", -task.score.friction) }
                        }

                        if !recommendation.alternatives.isEmpty {
                            Section("Also ready") {
                                ForEach(recommendation.alternatives) { alternative in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(alternative.task.title)
                                        Text("\(alternative.score.normalized)% fit")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                        }
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Now")
            .onAppear { loadPreferences() }
            .onChange(of: manualContext) { _, selection in
                ContextPreferenceStore.save(selection)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch recommendation.emptyReason {
        case .noAvailableTime:
            List {
                contextControls
                ContentUnavailableView("No time window set", systemImage: "clock.badge.exclamationmark", description: Text("Set today’s available time to receive a recommendation."))
            }
        case .noEligibleTasks, .none:
            List {
                contextControls
                ContentUnavailableView("Nothing ready right now", systemImage: "checkmark.circle", description: Text("Plan an Inbox item or add a task with no unfinished dependencies."))
            }
        }
    }

    private var contextControls: some View {
        Section("Current context") {
            Picker("Where are you?", selection: $manualContext) {
                Text("Not set").tag(ManualContextSelection?.none)
                ForEach(ManualContextSelection.presets) { selection in
                    Text(selection.displayName).tag(Optional(selection))
                }
            }
            .pickerStyle(.navigationLink)
            Picker("Available window", selection: $currentWindowMinutes) {
                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.navigationLink)
            Text(contextFootnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func scoreRow(_ label: String, _ value: Int) -> some View {
        LabeledContent(label) {
            Text(value >= 0 ? "+\(value)" : "\(value)")
                .foregroundStyle(value < 0 ? .secondary : .primary)
                .monospacedDigit()
        }
    }

    private var contextFootnote: String {
        switch snapshot.availabilitySource {
        case .fallback:
            return "Using a 30-minute local planning window. Calendar is not connected."
        case .manual:
            return "Using your local time window. Calendar is not connected."
        case .calendar, .constrainedByCalendar:
            return "Your available window is constrained by calendar availability."
        }
    }

    private func loadPreferences() {
        guard !loadedPreferences else { return }
        manualContext = ContextPreferenceStore.load()
        loadedPreferences = true
    }
}
