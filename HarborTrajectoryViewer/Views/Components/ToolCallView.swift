import SwiftUI

struct ToolCallView: View {
    let toolCall: ToolCall
    let results: [ObservationResult]
    let baseURL: URL
    var accent: Color = AppTheme.primary
    var compact = false

    @AppStorage(AppSettings.renderBashOutputAsMarkdown) private var renderBashOutputAsMarkdown = false

    /// Bash output is Markdown often enough (e.g. `cat README.md`) that the
    /// user can opt into rendering it that way.
    private var rendersMarkdownResults: Bool {
        renderBashOutputAsMarkdown && toolCall.isBashCommand
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: AppTheme.toolIcon(toolCall.functionName))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 26, height: 26)
                    .background(accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(toolCall.functionName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Text(toolCall.toolCallID)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(results.isEmpty ? "NO RESULT" : "\(results.count) RESULT\(results.count == 1 ? "" : "S")")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(results.isEmpty ? .secondary : accent)
            }
            .padding(compact ? 11 : 13)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                EyebrowLabel(text: "Arguments")
                CodeBlock(content: toolCall.arguments.prettyPrinted, maxHeight: compact ? 150 : 220)
            }
            .padding(compact ? 11 : 13)

            if !results.isEmpty {
                Divider()
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                        ToolResultDisclosure(
                            result: result,
                            ordinal: results.count > 1 ? index + 1 : nil,
                            baseURL: baseURL,
                            compact: compact,
                            accent: accent,
                            rendersMarkdown: rendersMarkdownResults
                        )
                        if index < results.count - 1 { Divider() }
                    }
                }
            }
        }
        .roundedPanel(borderColor: accent.opacity(0.22))
    }
}

struct UnlinkedObservationView: View {
    let result: ObservationResult
    let baseURL: URL
    var compact = false
    var accent: Color = AppTheme.primary

    var body: some View {
        ToolResultDisclosure(
            result: result,
            ordinal: nil,
            baseURL: baseURL,
            compact: compact,
            accent: accent,
            title: "Observation"
        )
        .roundedPanel(borderColor: AppTheme.separator.opacity(0.8))
    }
}

private struct ToolResultDisclosure: View {
    let result: ObservationResult
    let ordinal: Int?
    let baseURL: URL
    let compact: Bool
    let accent: Color
    var rendersMarkdown = false
    var title = "Result"

    @State private var isExpanded = false

    private var outputText: String {
        if let content = result.content {
            return content.plainText
        }
        if let extra = result.extra {
            return extra.prettyPrinted
        }
        return "No output"
    }

    private var summary: String {
        let bytes = outputText.utf8.count
        let lines = max(1, outputText.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
        return "\(lines) line\(lines == 1 ? "" : "s") · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Image(systemName: "return")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(ordinal.map { "\(title) \($0)" } ?? title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(summary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(isExpanded ? "Hide" : "Show")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(compact ? 11 : 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ordinal.map { "\(title) \($0)" } ?? title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses the output" : "Shows the output")

            if isExpanded {
                resultContent
                    .padding(.horizontal, compact ? 11 : 13)
                    .padding(.bottom, compact ? 11 : 13)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let content = result.content {
            switch content {
            case .text(let text):
                if rendersMarkdown, !text.isEmpty {
                    MarkdownOutputBlock(
                        markdown: text,
                        baseURL: baseURL,
                        maxHeight: compact ? 230 : 340
                    )
                } else {
                    CodeBlock(content: text.isEmpty ? "Empty output" : text, maxHeight: compact ? 230 : 340)
                }
            case .parts:
                RichContentView(content: content, baseURL: baseURL)
            }
        } else if let extra = result.extra {
            CodeBlock(content: extra.prettyPrinted, maxHeight: compact ? 230 : 340)
        } else {
            Text("No output was recorded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
