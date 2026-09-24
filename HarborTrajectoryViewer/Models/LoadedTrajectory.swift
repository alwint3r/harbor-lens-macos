import Foundation

struct LoadedTrajectory: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let trajectory: Trajectory
    let byteCount: Int64
    let modifiedAt: Date?
    /// Token and cost totals, computed once per load so views can read them
    /// without walking every step on each render.
    let usage: TrajectoryUsage

    init(
        id: UUID = UUID(),
        url: URL,
        trajectory: Trajectory,
        byteCount: Int64,
        modifiedAt: Date?
    ) {
        self.id = id
        self.url = url
        self.trajectory = trajectory
        self.byteCount = byteCount
        self.modifiedAt = modifiedAt
        usage = trajectory.usage
    }

    var fileName: String { url.lastPathComponent }

    var displayModel: String {
        trajectory.models.first ?? "Model not recorded"
    }

    var displayAgent: String {
        if let version = trajectory.agent.version, !version.isEmpty {
            return "\(trajectory.agent.name) \(version)"
        }
        return trajectory.agent.name
    }

    var shortIdentifier: String? {
        let identifier = trajectory.trajectoryID ?? trajectory.sessionID
        guard let identifier, !identifier.isEmpty else { return nil }
        return identifier.count > 18 ? String(identifier.prefix(15)) + "…" : identifier
    }
}
