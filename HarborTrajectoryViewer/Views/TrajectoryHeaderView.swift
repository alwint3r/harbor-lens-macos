import SwiftUI

struct TrajectoryHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Harbor Lens")
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.isComparing ? "Trajectory comparison" : "Trajectory reader")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, alignment: .leading)

            if let primary = model.primary {
                LoadedFileSummary(trajectory: primary, label: "A", accent: AppTheme.primary)
                    .contextMenu {
                        Button("Replace Trajectory A…") { model.chooseFile(for: .primary) }
                        Button("Show in Finder") { model.reveal(primary) }
                    }
            }

            Image(systemName: model.isComparing ? "arrow.left.arrow.right" : "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            if let comparison = model.comparison {
                LoadedFileSummary(trajectory: comparison, label: "B", accent: AppTheme.comparison)
                    .contextMenu {
                        Button("Replace Trajectory B…") { model.chooseFile(for: .comparison) }
                        Button("Show in Finder") { model.reveal(comparison) }
                        Divider()
                        Button("Remove from Comparison") { model.removeComparison() }
                    }

                Button {
                    model.swapTrajectories()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .help("Swap trajectories")
                .accessibilityLabel("Swap trajectories")

                Button {
                    model.removeComparison()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close comparison")
                .accessibilityLabel("Close comparison")
            } else {
                Button {
                    model.chooseFile(for: .comparison)
                } label: {
                    HStack(spacing: 7) {
                        if model.loadingSlots.contains(.comparison) {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text("Add comparison")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(AppTheme.separator)
                }
                .help("Load a second trajectory")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.bar)
    }
}

private struct LoadedFileSummary: View {
    let trajectory: LoadedTrajectory
    let label: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 23, height: 23)
                .background(accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(trajectory.fileName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(trajectory.displayAgent) · \(trajectory.displayModel)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Text("\(trajectory.trajectory.steps.count) steps")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(accent.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trajectory \(label), \(trajectory.fileName), \(trajectory.trajectory.steps.count) steps")
    }
}
