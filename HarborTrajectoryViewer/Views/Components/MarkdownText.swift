import AppKit
import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var baseURL: URL?

    private var rendered: AttributedString {
        // Inline-only parsing keeps every newline in the source. Full markdown
        // parsing turns soft line breaks into spaces (and drops paragraph breaks),
        // which collapses multi-line prompts into one run-on paragraph.
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: markdown, options: options, baseURL: baseURL))
            ?? AttributedString(markdown)
    }

    var body: some View {
        Text(rendered)
            .font(.system(size: 13.5))
            .lineSpacing(3)
            .foregroundStyle(.primary)
            .tint(AppTheme.primary)
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RichContentView: View {
    let content: RichContent
    let baseURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch content {
            case .text(let text):
                MarkdownText(markdown: text, baseURL: baseURL)
            case .parts(let parts):
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    if part.type == "text", let text = part.text {
                        MarkdownText(markdown: text, baseURL: baseURL)
                    } else if part.type == "image", let source = part.source {
                        TrajectoryImageView(source: source, baseURL: baseURL)
                    }
                }
            }
        }
    }
}

private struct TrajectoryImageView: View {
    let source: ImageSource
    let baseURL: URL

    private var resolvedURL: URL? {
        if let remoteURL = URL(string: source.path),
           let scheme = remoteURL.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return remoteURL
        }
        if source.path.hasPrefix("/") {
            return URL(fileURLWithPath: source.path)
        }
        return baseURL.appendingPathComponent(source.path)
    }

    var body: some View {
        Group {
            if let url = resolvedURL, url.isFileURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let url = resolvedURL, !url.isFileURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        unavailableImage
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                    @unknown default:
                        unavailableImage
                    }
                }
            } else {
                unavailableImage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.separator, lineWidth: 1)
        }
        .accessibilityLabel("Trajectory image: \(source.path)")
    }

    private var unavailableImage: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.title2)
            Text("Image unavailable")
                .font(.caption)
            Text(source.path)
                .font(.caption2.monospaced())
                .lineLimit(2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(AppTheme.recessed)
    }
}

struct CodeBlock: View {
    let content: String
    var maxHeight: CGFloat = 240

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    Text(content)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.88))
                        .textSelection(.enabled)
                        .padding(12)
                        .padding(.trailing, 26)
                        // Keeping the content at least as wide as the viewport stops
                        // the clip view from centering short content horizontally.
                        .frame(minWidth: proxy.size.width, alignment: .leading)
                }
            }
            .frame(height: textBlockHeight(for: content, maxHeight: maxHeight))
            .background(AppTheme.recessed)

            CopyButton(content: content)
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.65), lineWidth: 1)
        }
    }
}

/// Scrollable panel that renders Markdown with the same chrome as `CodeBlock`.
struct MarkdownOutputBlock: View {
    let markdown: String
    var baseURL: URL?
    var maxHeight: CGFloat = 340

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical) {
                MarkdownText(markdown: markdown, baseURL: baseURL)
                    .padding(12)
                    .padding(.trailing, 26)
            }
            .frame(height: textBlockHeight(for: markdown, maxHeight: maxHeight))
            .background(AppTheme.recessed)

            CopyButton(content: markdown, name: "Markdown output")
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.65), lineWidth: 1)
        }
    }
}

private struct CopyButton: View {
    let content: String
    var name = "code"

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .padding(7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(6)
        .help("Copy")
        .accessibilityLabel("Copy \(name)")
    }
}

/// Approximates a sensible panel height for a block of text, capped at `maxHeight`.
private func textBlockHeight(for content: String, maxHeight: CGFloat) -> CGFloat {
    let lines = max(1, content.reduce(1) { count, character in
        character == "\n" ? count + 1 : count
    })
    return min(maxHeight, max(44, CGFloat(lines * 17 + 24)))
}
