import AppKit
import SwiftUI
import Contracts
import Theme

struct ComposerAttachmentCard: View {
    let attachment: AttachmentRef
    let thumbnail: Data?
    var remove: () -> Void
    @State private var hovering = false
    @FocusState private var deleteFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var name: String { URL(filePath: attachment.path).lastPathComponent }
    private var active: Bool { hovering || deleteFocused }
    var body: some View {
        Group {
            if attachment.kind == .image {
                ZStack {
                    if let thumbnail, let image = NSImage(data: thumbnail) {
                        Image(nsImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").font(.system(size: 28))
                    }
                }
                .frame(width: 52, height: 52).clipped()
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "text.document")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .background(ThemeColor.kBackground, in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ThemeColor.kBorder.color(for: colorScheme), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).textStyle(.button)
                            .foregroundStyle(ThemeColor.kText.color(for: colorScheme))
                            .lineLimit(1).truncationMode(.tail)
                            .frame(height: 22, alignment: .leading)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file))
                            .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest.color(for: colorScheme))
                            .lineLimit(1).frame(height: 20, alignment: .leading)
                    }
                    .frame(maxWidth: 128, alignment: .leading)
                }
                .padding(.leading, 4).padding(.trailing, 20).padding(.vertical, 4).frame(height: 52)
            }
        }
        .background(ThemeColor(active ? "backgroundNeutralHover" : "backgroundNeutral").color(for: colorScheme))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            Button(action: remove) {
                Image(systemName: "xmark").font(TextStyle(size: 12, weight: 500, mode: .default).font)
                    .foregroundStyle(ThemeColor("iconInverted").color(for: colorScheme))
                    .frame(width: 20, height: 20)
                    .background(ThemeColor.kBackgroundPrimary, in: .circle)
            }
            .buttonStyle(.plain).focused($deleteFocused)
            .accessibilityLabel("删除附件：\(name)")
            .opacity(active ? 1 : 0)
            .offset(x: attachment.kind == .image ? 6 : 8, y: -6)
        }
        // Reserve the overhanging control inside the scroll content's bounds.
        .padding(.top, 6)
        .padding(.trailing, attachment.kind == .image ? 6 : 8)
        .contentShape(.rect)
        .onHover { hovering = $0 }
        .help(name)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }
}
