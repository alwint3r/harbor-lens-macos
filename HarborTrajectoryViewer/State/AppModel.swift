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
    @Published var presentedError: PresentedError?

    var isComparing: Bool { comparison != nil }

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

        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        Task {
            defer {
                if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
                loadingSlots.remove(slot)
            }

            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try TrajectoryLoader.load(from: url)
                }.value

                switch slot {
                case .primary:
                    primary = loaded
                case .comparison:
                    comparison = loaded
                }
            } catch {
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

    func removeComparison() {
        comparison = nil
    }

    func closeAll() {
        primary = nil
        comparison = nil
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
