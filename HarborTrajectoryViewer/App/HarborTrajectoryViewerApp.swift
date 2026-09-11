import SwiftUI

@main
struct HarborTrajectoryViewerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Harbor Lens", id: "main") {
            ContentView()
                .environmentObject(model)
                .tint(AppTheme.primary)
        }
        .defaultSize(width: 1180, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Trajectory…") {
                    model.chooseFile(for: .primary)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open for Comparison…") {
                    model.chooseFile(for: .comparison)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model.primary == nil)
            }

            CommandMenu("Trajectory") {
                Button("Swap A and B") {
                    model.swapTrajectories()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(model.comparison == nil)

                Button("Close Comparison") {
                    model.removeComparison()
                }
                .disabled(model.comparison == nil)

                Divider()

                Button("Close All Trajectories") {
                    model.closeAll()
                }
                .disabled(model.primary == nil)
            }
        }
    }
}
