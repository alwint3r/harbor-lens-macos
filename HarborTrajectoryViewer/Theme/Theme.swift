import AppKit
import SwiftUI

enum AppTheme {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(nsColor: .underPageBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let recessed = Color(nsColor: .textBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)

    static let primary = Color(red: 0.08, green: 0.52, blue: 0.49)
    static let comparison = Color(red: 0.91, green: 0.39, blue: 0.23)
    static let reasoning = Color(red: 0.82, green: 0.57, blue: 0.12)

    static func sourceColor(_ source: String) -> Color {
        switch source.lowercased() {
        case "agent": return primary
        case "user": return .blue
        case "system": return .secondary
        default: return .purple
        }
    }

    static func sourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case "agent": return "sparkles"
        case "user": return "person.fill"
        case "system": return "gearshape.fill"
        default: return "circle.fill"
        }
    }

    static func toolIcon(_ functionName: String) -> String {
        let name = functionName.lowercased()
        if name.contains("bash") || name.contains("shell") || name.contains("exec") || name.contains("terminal") {
            return "terminal.fill"
        }
        if name.contains("read") || name.contains("open") || name.contains("file") {
            return "doc.text.fill"
        }
        if name.contains("write") || name.contains("edit") || name.contains("patch") {
            return "pencil.line"
        }
        if name.contains("search") || name.contains("grep") || name.contains("find") {
            return "magnifyingglass"
        }
        if name.contains("browser") || name.contains("web") || name.contains("url") {
            return "globe"
        }
        return "wrench.and.screwdriver.fill"
    }
}

struct EyebrowLabel: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(color)
    }
}

struct RoundedPanelModifier: ViewModifier {
    var borderColor: Color = AppTheme.separator.opacity(0.7)

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }
}

extension View {
    func roundedPanel(borderColor: Color = AppTheme.separator.opacity(0.7)) -> some View {
        modifier(RoundedPanelModifier(borderColor: borderColor))
    }
}
