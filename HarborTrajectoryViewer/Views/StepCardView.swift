import SwiftUI

struct StepCardView: View {
    let step: TrajectoryStep
    let trajectory: LoadedTrajectory
    var accent: Color = AppTheme.primary
    var compact = false

    private var effectiveModel: String? {
        trajectory.trajectory.effectiveModel(for: step)
    }

    private var messageTitle: String {
        switch step.source.lowercased() {
        case "user": return "Prompt"
        case "system": return "System prompt"
        default: return "Response"
        }
    }

    private var contentBaseURL: URL {
        trajectory.url.deletingLastPathComponent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            header

            if let reasoning = step.reasoningContent,
               !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                reasoningBlock(reasoning)
            }

            if !step.message.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowLabel(text: messageTitle)
                    RichContentView(content: step.message, baseURL: contentBaseURL)
                }
            }

            if !step.toolCalls.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        EyebrowLabel(text: "Tool calls")
                        Text("\(step.toolCalls.count)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent.opacity(0.1), in: Capsule())
                    }

                    ForEach(step.toolCalls) { toolCall in
                        ToolCallView(
                            toolCall: toolCall,
                            results: step.results(for: toolCall),
                            baseURL: contentBaseURL,
                            accent: accent,
                            compact: compact
                        )
                    }
                }
            }

            if !step.unlinkedResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: step.toolCalls.isEmpty ? "Observations" : "Other observations")
                    ForEach(Array(step.unlinkedResults.enumerated()), id: \.offset) { _, result in
                        UnlinkedObservationView(
                            result: result,
                            baseURL: contentBaseURL,
                            compact: compact,
                            accent: accent
                        )
                    }
                }
            }
        }
        .padding(compact ? 16 : 22)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accent)
            .frame(width: 3)
            .padding(.vertical, 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AppTheme.sourceIcon(step.source))
                    .font(.system(size: 10, weight: .semibold))
                Text(step.source.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(AppTheme.sourceColor(step.source))

            Text("STEP \(step.stepID)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            if step.isCopiedContext == true {
                Label("Copied context", systemImage: "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if let effectiveModel {
                    Text(effectiveModel)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .help(effectiveModel)
                }
                if let timestamp = step.timestamp {
                    Text(shortTimestamp(timestamp))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .help(timestamp)
                }
            }
        }
    }

    private func reasoningBlock(_ reasoning: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11, weight: .semibold))
                EyebrowLabel(text: "Reasoning", color: AppTheme.reasoning)
                if let effort = step.reasoningEffort {
                    Text("Effort \(inlineValue(effort))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            MarkdownText(markdown: reasoning, baseURL: contentBaseURL)
        }
        .padding(compact ? 11 : 13)
        .background(AppTheme.reasoning.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.reasoning.opacity(0.22), lineWidth: 1)
        }
    }

    private func inlineValue(_ value: JSONValue) -> String {
        switch value {
        case .string(let string): return string
        default: return value.prettyPrinted.replacingOccurrences(of: "\n", with: " ")
        }
    }

    private func shortTimestamp(_ timestamp: String) -> String {
        timestamp
            .replacingOccurrences(of: "T", with: " ")
            .replacingOccurrences(of: "Z", with: " UTC")
    }
}
