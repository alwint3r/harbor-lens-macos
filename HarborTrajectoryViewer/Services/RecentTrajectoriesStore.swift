import Foundation

/// Persists the recently opened trajectories in UserDefaults as JSON.
enum RecentTrajectoriesStore {
    private static let key = "recentTrajectories"

    static func load(from defaults: UserDefaults = .standard) -> [RecentTrajectory] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentTrajectory].self, from: data)) ?? []
    }

    static func save(_ recentTrajectories: [RecentTrajectory], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(recentTrajectories) else { return }
        defaults.set(data, forKey: key)
    }
}
