import SwiftUI

/// Submenu of recently analyzed trajectories, shared by the File menu and the
/// toolbar. Takes the model explicitly because scene commands don't inherit
/// the window's environment objects.
struct RecentTrajectoriesMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            ForEach(model.recentTrajectories) { recent in
                Button(recent.menuTitle) {
                    model.openAsNextAvailable(recent.url)
                }
            }

            if !model.recentTrajectories.isEmpty {
                Divider()
                Button("Clear Menu") {
                    model.clearRecents()
                }
            }
        } label: {
            Label("Open Recent", systemImage: "clock.arrow.circlepath")
        }
        .disabled(model.recentTrajectories.isEmpty)
        .help("Open a recently analyzed trajectory")
    }
}
