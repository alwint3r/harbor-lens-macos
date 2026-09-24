import SwiftUI

struct TrajectoryTimelineView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trajectory: LoadedTrajectory
    @Binding var selectedStepID: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    timelineHeading

                    ForEach(trajectory.trajectory.steps) { step in
                        StepCardView(step: step, trajectory: trajectory)
                            .id(step.stepID)
                    }
                }
                .frame(maxWidth: 880)
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas)
            .onChange(of: selectedStepID) { _, stepID in
                guard let stepID else { return }
                if reduceMotion {
                    proxy.scrollTo(stepID, anchor: .top)
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        proxy.scrollTo(stepID, anchor: .top)
                    }
                }
            }
        }
    }

    private var timelineHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text("Interaction timeline")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(trajectory.trajectory.steps.count) steps · \(trajectory.trajectory.toolCallCount) tool calls")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("Prompts, reasoning, responses, and environment activity in turn order.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }
}

struct TrajectoryComparisonView: View {
    let primary: LoadedTrajectory
    let comparison: LoadedTrajectory

    private var pairs: [StepPair] {
        let left = Dictionary(uniqueKeysWithValues: primary.trajectory.steps.map { ($0.stepID, $0) })
        let right = Dictionary(uniqueKeysWithValues: comparison.trajectory.steps.map { ($0.stepID, $0) })
        let ids = Set(left.keys).union(right.keys).sorted()
        return ids.map { StepPair(stepID: $0, primary: left[$0], comparison: right[$0]) }
    }

    private var changedCount: Int {
        pairs.filter { pairStatus($0) != .same }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            comparisonHeader
            Divider()

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(pairs) { pair in
                        comparisonRow(pair)
                    }
                }
                .padding(22)
            }
            .background(AppTheme.canvas)
        }
    }

    private var comparisonHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step-by-step comparison")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("Steps align by step ID. Tool outputs stay collapsed until needed.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(pairs.count) aligned · \(changedCount) different")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 26) {
                ComparisonColumnLabel(label: "A", trajectory: primary, accent: AppTheme.primary)
                ComparisonColumnLabel(label: "B", trajectory: comparison, accent: AppTheme.comparison)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private func comparisonRow(_ pair: StepPair) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("STEP \(pair.stepID)")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(AppTheme.separator)
                    .frame(height: 1)
                ComparisonStatusBadge(status: pairStatus(pair))
            }

            HStack(alignment: .top, spacing: 26) {
                Group {
                    if let step = pair.primary {
                        StepCardView(
                            step: step,
                            trajectory: primary,
                            accent: AppTheme.primary,
                            compact: true
                        )
                    } else {
                        MissingStepView(label: "A", stepID: pair.stepID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                Group {
                    if let step = pair.comparison {
                        StepCardView(
                            step: step,
                            trajectory: comparison,
                            accent: AppTheme.comparison,
                            compact: true
                        )
                    } else {
                        MissingStepView(label: "B", stepID: pair.stepID)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func pairStatus(_ pair: StepPair) -> ComparisonStatus {
        switch (pair.primary, pair.comparison) {
        case (.none, .some): return .onlyB
        case (.some, .none): return .onlyA
        case (.none, .none): return .same
        case (.some(let left), .some(let right)):
            let sameModel = primary.trajectory.effectiveModel(for: left)
                == comparison.trajectory.effectiveModel(for: right)
            return left.comparisonFingerprint == right.comparisonFingerprint && sameModel ? .same : .changed
        }
    }
}

private struct StepPair: Identifiable {
    let stepID: Int
    let primary: TrajectoryStep?
    let comparison: TrajectoryStep?
    var id: Int { stepID }
}

private enum ComparisonStatus {
    case same
    case changed
    case onlyA
    case onlyB

    var text: String {
        switch self {
        case .same: return "Same"
        case .changed: return "Different"
        case .onlyA: return "Only in A"
        case .onlyB: return "Only in B"
        }
    }

    var icon: String {
        switch self {
        case .same: return "equal"
        case .changed: return "not.equal"
        case .onlyA, .onlyB: return "arrow.turn.down.right"
        }
    }

    var color: Color {
        switch self {
        case .same: return .secondary
        case .changed: return AppTheme.reasoning
        case .onlyA: return AppTheme.primary
        case .onlyB: return AppTheme.comparison
        }
    }
}

private struct ComparisonStatusBadge: View {
    let status: ComparisonStatus

    var body: some View {
        Label(status.text, systemImage: status.icon)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.09), in: Capsule())
    }
}

private struct ComparisonColumnLabel: View {
    let label: String
    let trajectory: LoadedTrajectory
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(accent, in: RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 2) {
                Text(trajectory.displayModel)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let summary = MetricFormat.usageSummary(trajectory.usage) {
                    Text(summary)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MissingStepView: View {
    let label: String
    let stepID: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "minus.circle")
                .font(.title3)
            Text("No step \(stepID) in trajectory \(label)")
                .font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(AppTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(AppTheme.separator)
        }
    }
}
