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
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
                        .frame(width: 44, height: 44)
                        .background(ThemeColor.kBackground, in: .rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).textStyle(TextStyle(size: 14, weight: 500, mode: .default)).lineLimit(1).truncationMode(.middle).frame(maxWidth: 128)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file))
                            .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest.color(for: colorScheme))
                    }
                }
                .padding(.leading, 4).padding(.trailing, 20).padding(.vertical, 4).frame(height: 52)
            }
        }
        .background(ThemeColor.kBackgroundNeutral.color(for: colorScheme))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ThemeColor.kBorder.color(for: colorScheme), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 20, height: 20)
                    .background(.black.opacity(0.8), in: .circle)
            }
            .buttonStyle(.plain).focused($deleteFocused)
            .accessibilityLabel("删除附件：\(name)")
            .opacity(hovering || deleteFocused ? 1 : 0)
            .padding(4)
        }
        .onHover { hovering = $0 }
        .help(name)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }
}
