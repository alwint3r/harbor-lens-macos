import Foundation

/// A trajectory the user opened before, kept so it can be reopened from the
/// start screen, the toolbar, or the File menu.
struct RecentTrajectory: Identifiable, Hashable, Codable, Sendable {
    let url: URL
    let displayName: String
    let jobName: String?
    let openedAt: Date

    var id: String { url.standardizedFileURL.path }

    /// Menu-friendly title that distinguishes same-named trials in different jobs.
    var menuTitle: String {
        guard let jobName else { return displayName }
        return "\(displayName) — \(jobName)"
    }

    init(url: URL, openedAt: Date = Date()) {
        self.url = url
        self.openedAt = openedAt

        let parent = url.deletingLastPathComponent()
        if parent.lastPathComponent == "agent" || parent.lastPathComponent == "artifacts" {
            let trial = parent.deletingLastPathComponent()
            displayName = trial.lastPathComponent
            jobName = trial.deletingLastPathComponent().lastPathComponent
        } else {
            displayName = url.lastPathComponent
            jobName = nil
        }
    }
}
