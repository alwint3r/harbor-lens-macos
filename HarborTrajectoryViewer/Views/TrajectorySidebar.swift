import SwiftUI

struct TrajectorySidebar: View {
    @EnvironmentObject private var model: AppModel
    let trajectory: LoadedTrajectory
    @Binding var selectedStepID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    runSummary
                    Divider()
                    stepIndex
                }
                .padding(16)
            }

            Divider()
            HStack {
                Button {
                    model.chooseFile(for: .primary)
                } label: {
                    Label("Replace", systemImage: "folder")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    model.reveal(trajectory)
                } label: {
                    Image(systemName: "arrow.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
                .accessibilityLabel("Show trajectory in Finder")
            }
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .background(AppTheme.sidebar)
        .frame(minWidth: 220, idealWidth: 248, maxWidth: 280)
    }

    private var runSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Run")

            VStack(alignment: .leading, spacing: 4) {
                Text(trajectory.trajectory.agent.name)
                    .font(.system(size: 16, weight: .semibold))
                    .textSelection(.enabled)
                Text(trajectory.displayModel)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: 0) {
                MetricValue(value: trajectory.trajectory.steps.count, label: "Steps")
                MetricValue(value: trajectory.trajectory.agentTurnCount, label: "Turns")
                MetricValue(value: trajectory.trajectory.toolCallCount, label: "Tools")
            }

            VStack(alignment: .leading, spacing: 6) {
                if let schema = trajectory.trajectory.schemaVersion {
                    MetadataLine(label: "Format", value: schema)
                }
                if let identifier = trajectory.shortIdentifier {
                    MetadataLine(label: "ID", value: identifier)
                }
                MetadataLine(
                    label: "Size",
                    value: ByteCountFormatter.string(fromByteCount: trajectory.byteCount, countStyle: .file)
                )
            }
        }
    }

    private var stepIndex: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: "Steps")

            ForEach(trajectory.trajectory.steps) { step in
                Button {
                    selectedStepID = step.stepID
                } label: {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: AppTheme.sourceIcon(step.source))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.sourceColor(step.source))
                            .frame(width: 16, height: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Step \(step.stepID)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Spacer()
                                if !step.toolCalls.isEmpty {
                                    Label("\(step.toolCalls.count)", systemImage: "wrench.fill")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(stepSummary(step))
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(
                        selectedStepID == step.stepID ? AppTheme.primary.opacity(0.1) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(step.stepID), \(step.source), \(stepSummary(step))")
            }
        }
    }

    private func stepSummary(_ step: TrajectoryStep) -> String {
        let message = step.message.plainText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !message.isEmpty { return message }
        if let reasoning = step.reasoningContent, !reasoning.isEmpty { return reasoning }
        if let tool = step.toolCalls.first { return tool.functionName }
        return step.source.capitalized
    }
}

private struct MetricValue: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
        .font(.system(size: 10.5, design: .monospaced))
    }
}
