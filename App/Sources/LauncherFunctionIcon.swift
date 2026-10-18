import SwiftUI

/// The only background colors allowed for built-in tool tiles.
enum ToolIconPalette {
    static let red = Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)
    static let orange = Color(.sRGB, red: 1, green: 154 / 255, blue: 2 / 255, opacity: 1)
    static let cyan = Color(.sRGB, red: 0, green: 145 / 255, blue: 1, opacity: 1)
    static let blue = Color(.sRGB, red: 45 / 255, green: 104 / 255, blue: 1, opacity: 1)
    static let purple = Color(.sRGB, red: 125 / 255, green: 64 / 255, blue: 1, opacity: 1)
}

/// Built-in tools share a white MingCute glyph and a solid, circular-cornered tile.
struct LauncherFunctionIcon: View {
    enum Kind {
        case bookmark, link, quit, conversion, tabs, ai, calculator

        var symbol: String? {
            switch self {
            case .bookmark: "bookmark"
            case .link: "link"
            case .quit: "power"
            case .conversion: "arrow.left.arrow.right"
            case .tabs: "web"
            case .ai: nil
            case .calculator: "equal.square"
            }
        }

        var background: Color {
            switch self {
            case .bookmark: ToolIconPalette.orange
            case .quit: ToolIconPalette.red
            case .conversion, .calculator: ToolIconPalette.cyan
            case .link: ToolIconPalette.blue
            case .tabs: ToolIconPalette.purple
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
