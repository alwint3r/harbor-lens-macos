import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    enum Slot: Hashable {
        case primary
        case comparison
    }

    struct PresentedError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published private(set) var primary: LoadedTrajectory?
    @Published private(set) var comparison: LoadedTrajectory?
    @Published private(set) var loadingSlots: Set<Slot> = []
    @Published private(set) var recentTrajectories: [RecentTrajectory]
    @Published var presentedError: PresentedError?

    /// Bumped whenever a slot's load starts or is abandoned, so a read that
    /// finishes after the user closed the slot cannot display a trajectory.
    private var loadGeneration: [Slot: Int] = [:]

    private static let recentLimit = 10
    private let defaults: UserDefaults

    var isComparing: Bool { comparison != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentTrajectories = RecentTrajectoriesStore.load(from: defaults)
    }

    func chooseFile(for slot: Slot) {
        let panel = NSOpenPanel()
        panel.title = slot == .primary ? "Open Harbor Trajectory" : "Choose a Trajectory to Compare"
        panel.prompt = slot == .primary ? "Open" : "Compare"
        panel.message = "Select a trajectory.json file produced by a Harbor trial."
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.load(url, into: slot)
            }
        }
    }

    func load(_ url: URL, into slot: Slot) {
        guard !loadingSlots.contains(slot) else { return }
        loadingSlots.insert(slot)

        let generation = (loadGeneration[slot] ?? 0) + 1
        loadGeneration[slot] = generation

        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
                if loadGeneration[slot] == generation {
                    loadingSlots.remove(slot)
                }
            }

            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try TrajectoryLoader.load(from: url)
                }.value

                guard loadGeneration[slot] == generation else { return }

                switch slot {
                case .primary:
                    primary = loaded
                case .comparison:
                    comparison = loaded
                }
                noteRecent(loaded)
            } catch {
                guard loadGeneration[slot] == generation else { return }
                presentedError = PresentedError(
                    title: "Couldn’t open \(url.lastPathComponent)",
                    message: error.localizedDescription
                )
            }
        }
    }

    func openAsNextAvailable(_ url: URL) {
        let primaryIsAvailable = primary == nil && !loadingSlots.contains(.primary)
        load(url, into: primaryIsAvailable ? .primary : .comparison)
    }

    func loadDroppedURLs(_ urls: [URL]) {
        let jsonFiles = urls.filter { $0.pathExtension.lowercased() == "json" }
        guard !jsonFiles.isEmpty else {
            presentedError = PresentedError(
                title: "No JSON file found",
                message: "Drop a trajectory.json file to open it."
            )
            return
        }

        if primary == nil {
            load(jsonFiles[0], into: .primary)
            if jsonFiles.count > 1 {
                load(jsonFiles[1], into: .comparison)
            }
        } else {
            load(jsonFiles[0], into: .comparison)
        }
    }

    /// Closes a slot and dismisses a load still in flight for it. Closing the
    /// primary trajectory also clears the comparison, since a comparison is
    /// only rendered alongside a primary trajectory.
    func close(_ slot: Slot) {
        switch slot {
        case .primary:
            invalidateLoad(in: .primary)
            invalidateLoad(in: .comparison)
            primary = nil
            comparison = nil
        case .comparison:
            invalidateLoad(in: .comparison)
            comparison = nil
        }
    }

    func removeComparison() {
        close(.comparison)
    }

    func closeAll() {
        close(.primary)
    }

    private func invalidateLoad(in slot: Slot) {
        loadGeneration[slot, default: 0] += 1
        loadingSlots.remove(slot)
    }

    /// Records a successfully loaded trajectory as the most recent one.
    private func noteRecent(_ trajectory: LoadedTrajectory) {
        let entry = RecentTrajectory(url: trajectory.url)
        recentTrajectories.removeAll { $0.id == entry.id }
        recentTrajectories.insert(entry, at: 0)
        if recentTrajectories.count > Self.recentLimit {
            recentTrajectories.removeLast(recentTrajectories.count - Self.recentLimit)
        }
        RecentTrajectoriesStore.save(recentTrajectories, to: defaults)
    }

    func clearRecents() {
        recentTrajectories.removeAll()
        RecentTrajectoriesStore.save(recentTrajectories, to: defaults)
    }

    func swapTrajectories() {
        guard let comparison else { return }
        let oldPrimary = primary
        primary = comparison
        self.comparison = oldPrimary
    }

    func reveal(_ trajectory: LoadedTrajectory) {
        NSWorkspace.shared.activateFileViewerSelecting([trajectory.url])
    }
}
