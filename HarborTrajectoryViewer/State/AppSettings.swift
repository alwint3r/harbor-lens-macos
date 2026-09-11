import Foundation

/// UserDefaults-backed preferences shared by the toolbar, menu commands, and views.
enum AppSettings {
    /// When true, bash tool output is rendered with the Markdown renderer
    /// instead of the monospaced code block.
    static let renderBashOutputAsMarkdown = "renderBashOutputAsMarkdown"
}
