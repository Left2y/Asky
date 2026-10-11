import SwiftUI
import Theme

/// Compact feedback with its own surface, separated from the clipboard cards below it.
struct ClipboardStatusToast: View {
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
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ThemeColor.kBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
