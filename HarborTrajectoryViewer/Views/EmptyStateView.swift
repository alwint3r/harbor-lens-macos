import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isDropTarget: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                introCard

                if !model.recentTrajectories.isEmpty {
                    recentJobs
                }
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text("Files are read locally and never leave your Mac.")
            }
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .background(AppTheme.canvas)
    }

    private var introCard: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.primary.opacity(isDropTarget ? 0.17 : 0.09))
                    .frame(width: 82, height: 82)
                Image(systemName: isDropTarget ? "arrow.down.doc.fill" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 7) {
                Text(isDropTarget ? "Drop to open" : "Open a Harbor trajectory")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                Text("Inspect prompts, reasoning, tool calls, and results — then add a second run for a step-by-step comparison.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 520)
            }

            Button {
                model.chooseFile(for: .primary)
            } label: {
                Label("Open trajectory.json", systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.primary)

            Text("or drag a JSON file anywhere into this window")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(46)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface.opacity(0.7))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isDropTarget ? AppTheme.primary : AppTheme.separator.opacity(0.75),
                    style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: isDropTarget ? [7, 5] : [])
                )
        }
        .scaleEffect(isDropTarget ? 1.015 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isDropTarget)
    }

    private var recentJobs: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EyebrowLabel(text: "Recent jobs")
                Spacer()
                Button("Clear") {
                    model.clearRecents()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                ForEach(model.recentTrajectories.prefix(4)) { recent in
                    RecentTrajectoryRow(recent: recent) {
                        model.openAsNextAvailable(recent.url)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 520)
        .roundedPanel()
    }
}

private struct RecentTrajectoryRow: View {
    let recent: RecentTrajectory
    let action: () -> Void

    @State private var isHovered = false

    private var isMissing: Bool {
        !FileManager.default.fileExists(atPath: recent.url.path)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: isMissing ? "exclamationmark.triangle.fill" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isMissing ? Color.secondary : AppTheme.primary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(recent.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    subtitle
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                isHovered ? AppTheme.primary.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(isMissing ? 0.65 : 1)
        .help(recent.url.path)
    }

    private var subtitle: some View {
        HStack(spacing: 4) {
            if let jobName = recent.jobName {
                Text(jobName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("·")
            }

            if isMissing {
                Text("File not found")
            } else {
                Text(recent.openedAt, style: .relative)
            }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }
}
