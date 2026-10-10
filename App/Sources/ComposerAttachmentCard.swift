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
                .frame(width: 88, height: 88).clipped()
            } else {
                HStack(spacing: 10) {
                    Image(systemName: attachment.kind == .text ? "doc.text" : "doc")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(ThemeColor.kIconSubtle.color(for: colorScheme))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name).textStyle(.input).lineLimit(1).truncationMode(.middle)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.byteSize), countStyle: .file))
                            .textStyle(.secondary).foregroundStyle(ThemeColor.kTextSubtlest.color(for: colorScheme))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).frame(width: 220, height: 88)
            }
        }
        .background(ThemeColor.kBackgroundNeutral.color(for: colorScheme))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ThemeColor.kBorder.color(for: colorScheme), lineWidth: 1))
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
