import SwiftUI

/// Shared visible tile geometry for supplied artwork and built-in tool icons.
enum LauncherIconTile {
    static let size: CGFloat = 20
    static let cornerRadius: CGFloat = 5
    static let toolCornerRadius = cornerRadius
}

/// Use an explicit circular path so parent layout cannot adapt the tile corners.
struct LauncherIconClip: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    }
}

extension View {
    func launcherIconTile(cornerRadius: CGFloat = LauncherIconTile.cornerRadius) -> some View {
        frame(width: LauncherIconTile.size, height: LauncherIconTile.size)
            .clipShape(LauncherIconClip(radius: cornerRadius))
    }
}
