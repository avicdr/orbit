import Foundation

/// Persists only the user's deliberate context label locally. No coordinates or movement history are stored.
public enum ContextPreferenceStore {
    private static let activeContextKey = "orbit.active-manual-context"

    public static func load(from defaults: UserDefaults = .standard) -> ManualContextSelection? {
        guard let data = defaults.data(forKey: activeContextKey) else { return nil }
        return try? JSONDecoder().decode(ManualContextSelection.self, from: data)
    }

    public static func save(_ selection: ManualContextSelection?, in defaults: UserDefaults = .standard) {
        guard let selection else {
            defaults.removeObject(forKey: activeContextKey)
            return
        }
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: activeContextKey)
    }
}
