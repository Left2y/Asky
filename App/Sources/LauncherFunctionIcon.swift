import SwiftUI

/// The only background colors allowed for built-in tool tiles.
enum ToolIconPalette {
    static let red = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
    static let orange = Color(.sRGB, red: 1, green: 154 / 255, blue: 2 / 255, opacity: 1)
    static let cyan = Color(.sRGB, red: 0, green: 145 / 255, blue: 1, opacity: 1)
    static let blue = Color(.sRGB, red: 45 / 255, green: 104 / 255, blue: 1, opacity: 1)
    static let green = Color(.sRGB, red: 40 / 255, green: 167 / 255, blue: 69 / 255, opacity: 1)
    static let teal = Color(.sRGB, red: 0, green: 158 / 255, blue: 154 / 255, opacity: 1)
    static let pink = Color(.sRGB, red: 227 / 255, green: 79 / 255, blue: 140 / 255, opacity: 1)
    static let indigo = Color(.sRGB, red: 88 / 255, green: 86 / 255, blue: 214 / 255, opacity: 1)
    static let purple = Color(.sRGB, red: 125 / 255, green: 64 / 255, blue: 1, opacity: 1)
}

/// Built-in tools share a white MingCute glyph and a solid, circular-cornered tile.
struct LauncherFunctionIcon: View {
    enum Kind {
        case colorPicker, clipboardImage, clipboardVideo, clipboardText, bookmark, link, quickLinks, quit, conversion, tabs, windows, ai, calculator, files, applications, shortcuts

        static func searchCommand(_ id: String) -> Self {
            switch id {
            case "colorPicker": .colorPicker
            case "calculatorHistory": .calculator
            case "windows": .windows
            case "tabs": .tabs
            case "bookmark": .bookmark
            case "link": .link
            case "quickLinks": .quickLinks
            case "files": .files
            case "applications": .applications
            case "shortcuts": .shortcuts
            default: .ai
            }
        }

        var symbol: String? {
            switch self {
            case .colorPicker: "eyedropper"
            case .clipboardImage: "photo"
            case .clipboardVideo: "video"
            case .clipboardText: "text.document"
            case .bookmark: "bookmark"
            case .link: "link"
            case .quit: "power"
            case .conversion: "arrow.left.arrow.right"
            case .tabs, .windows: "layout_4_line"
            case .ai: nil
            case .calculator: "equal.square"
            case .files: "folder"
            case .applications: "app.badge"
            case .quickLinks: "cursor_3"
            case .shortcuts: "command"
            }
        }

        var background: Color {
            switch self {
            case .colorPicker: ToolIconPalette.pink
            case .clipboardImage: ToolIconPalette.blue
            case .clipboardVideo: ToolIconPalette.purple
            case .clipboardText: ToolIconPalette.cyan
            case .bookmark: ToolIconPalette.orange
            case .quit: ToolIconPalette.red
            case .conversion, .calculator: ToolIconPalette.cyan
            case .link: ToolIconPalette.teal
            case .quickLinks: ToolIconPalette.green
            case .applications: ToolIconPalette.blue
            case .tabs: ToolIconPalette.purple
            case .windows: ToolIconPalette.indigo
            case .shortcuts: ToolIconPalette.pink
            case .files: ToolIconPalette.orange
            case .ai: .clear
            }
        }
    }

    let kind: Kind

    var body: some View {
        Group {
            if let symbol = kind.symbol {
                ZStack {
                    LauncherIconClip(radius: LauncherIconTile.toolCornerRadius)
                        .fill(kind.background)
                    Image(mingCute: symbol, size: 16)
                        .resizable().scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.white)
                }
                .frame(width: LauncherIconTile.size, height: LauncherIconTile.size)
                .fixedSize()
            } else {
                // AI keeps its original brand artwork; the tool palette does not apply.
                Image("Agent").renderingMode(.original).resizable().scaledToFit()
                    .launcherIconTile()
            }
        }
        .frame(width: LauncherLayout.rowIconSize, height: LauncherLayout.rowIconSize)
    }
}
