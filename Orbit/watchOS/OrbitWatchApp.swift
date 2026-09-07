import SwiftUI
import SwiftData

@main
struct OrbitWatchApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try OrbitModelContainer.make()
        } catch {
            fatalError("Unable to create Orbit's local data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchOrbitContextView()
        }
        .modelContainer(modelContainer)
    }
}
