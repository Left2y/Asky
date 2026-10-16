import SwiftUI
import Theme

/// Compact feedback in its own opaque window above the launcher or clipboard;
/// the window server draws its shadow.
struct ClipboardStatusToast: View {
    static let cornerRadius: CGFloat = 12
    let message: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            if message == NSLocalizedString("已复制", comment: "") {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(message)
                .textStyle(.resultPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(ThemeColor.kText)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(ThemeColor.kBackground.color(for: scheme, opaque: true),
                    in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(ThemeColor.kBorder, lineWidth: 1)
        }
    }
}
