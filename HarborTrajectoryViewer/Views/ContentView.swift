import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isDropTarget = false

    var body: some View {
        ZStack {
            if model.primary == nil {
                EmptyStateView(isDropTarget: isDropTarget)
            } else {
                WorkspaceView()
            }

            if model.loadingSlots.contains(.primary) {
                loadingOverlay
            }
        }
        .frame(minWidth: 920, minHeight: 650)
        .overlay {
            if isDropTarget, model.primary != nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.primary, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .padding(8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.loadDroppedURLs(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
        .onOpenURL { url in
            model.openAsNextAvailable(url)
        }
        .alert(item: $model.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.chooseFile(for: .primary)
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .help(model.primary == nil ? "Open a trajectory" : "Replace trajectory A")

                if model.primary != nil {
                    Button {
                        model.chooseFile(for: .comparison)
                    } label: {
                        Label(
                            model.comparison == nil ? "Compare" : "Replace B",
                            systemImage: "rectangle.split.2x1"
                        )
                    }
                    .help(model.comparison == nil ? "Open a second trajectory" : "Replace trajectory B")
                }
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading trajectory…")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading trajectory")
    }
}
