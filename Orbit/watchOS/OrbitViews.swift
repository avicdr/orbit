import SwiftUI
import SwiftData

struct WatchOrbitContextView: View {
    @Query(filter: #Predicate<Orbit> { $0.archivedAt == nil }, sort: \Orbit.createdAt)
    private var orbits: [Orbit]

    var body: some View {
        Group {
            if orbits.isEmpty {
                ContentUnavailableView("No Orbits", systemImage: "circle.grid.2x2")
            } else {
                List(orbits.prefix(4)) { orbit in
                    HStack {
                        Image(systemName: orbit.icon).foregroundStyle(WatchOrbitColor.token(orbit.colorToken))
                        VStack(alignment: .leading) {
                            Text(orbit.name).lineLimit(1)
                            Text("\(orbit.tasks.count) tasks").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(orbit.name), \(orbit.tasks.count) tasks")
                }
            }
        }
        .navigationTitle("Orbits")
    }
}

private enum WatchOrbitColor {
    static func token(_ value: String) -> Color { switch value { case "blue": .blue; case "purple": .purple; case "pink": .pink; case "green": .green; case "orange": .orange; default: .accentColor } }
}
