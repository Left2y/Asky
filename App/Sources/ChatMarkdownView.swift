import SwiftUI
import MarkdownUI
import Theme
import ToolService

/// Shared by live replies and reopened history; the stored content remains Markdown source.
struct ChatMarkdownView: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    private static let bodyStyle = TextStyle(size: 14, weight: 400, mode: .paragraph)
    private static let headingStyle = TextStyle(size: 16, weight: 500, mode: .paragraph)

    var body: some View {
        Markdown(text)
            // The default theme is basic; setting it here would override the block styles below.
            .markdownTextStyle {
                FontSize(Self.bodyStyle.size)
                FontWeight(.regular)
                ForegroundColor(ThemeColor("text").color(for: colorScheme))
            }
            .markdownBlockStyle(\.heading1, body: Self.heading)
            .markdownBlockStyle(\.heading2, body: Self.heading)
            .markdownBlockStyle(\.heading3, body: Self.heading)
            .markdownBlockStyle(\.heading4, body: Self.heading)
            .markdownBlockStyle(\.heading5, body: Self.heading)
            .markdownBlockStyle(\.heading6, body: Self.heading)
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(Self.bodyStyle.lineHeight - Self.bodyStyle.size * 1.2)
                    .markdownMargin(top: 0, bottom: 14)
            }
            .markdownTextStyle(\.link) {
                ForegroundColor(ThemeColor("textPrimary").color(for: colorScheme))
                UnderlineStyle(.single)
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: true, vertical: false)
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(14)
                        }
                        .padding(12)
                }
                .background(ThemeColor.kBackgroundNeutral, in: .rect(cornerRadius: 8))
                .markdownMargin(top: 0, bottom: 16)
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                BackgroundColor(ThemeColor("backgroundNeutral").color(for: colorScheme))
            }
            .markdownBlockStyle(\.blockquote) { configuration in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ThemeColor.kBorderIntense).frame(width: 3)
                    configuration.label
                        .markdownTextStyle {
                            ForegroundColor(ThemeColor("textSubtle").color(for: colorScheme))
                        }
                }
                .fixedSize(horizontal: false, vertical: true)
                .markdownMargin(top: 0, bottom: 16)
            }
            .markdownBlockStyle(\.table) { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .markdownTableBorderStyle(.init(color: ThemeColor("border").color(for: colorScheme)))
                        .markdownTableBackgroundStyle(.alternatingRows(
                            Color.clear, ThemeColor("backgroundNeutral").color(for: colorScheme)))
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThemeColor.kBorder, lineWidth: 1))
                }
                .markdownMargin(top: 0, bottom: 16)
            }
            .markdownBlockStyle(\.tableCell) { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 { FontWeight(.medium) }
                        BackgroundColor(nil)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .markdownBlockStyle(\.thematicBreak) {
                Rectangle().fill(ThemeColor.kBorder).frame(height: 1)
                    .markdownMargin(top: 16, bottom: 16)
            }
            .markdownImageProvider(ChatImageProvider())
            .markdownInlineImageProvider(ChatInlineImageProvider())
            .textSelection(.enabled)
    }

    // Every heading uses the same visual style, including older conversations.
    private static func heading(_ configuration: BlockConfiguration) -> some View {
        configuration.label
            .markdownTextStyle {
                FontSize(headingStyle.size)
                FontWeight(.medium)
            }
            .lineSpacing(headingStyle.lineHeight - headingStyle.size * 1.2)
            .markdownMargin(top: 16, bottom: 16)
    }

}

private struct ChatImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View { ChatRemoteImage(url: url) }
}

private struct ChatRemoteImage: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var failed = false

    nonisolated init(url: URL?) { self.url = url }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 420, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    if failed { Image(systemName: "photo") } else { ProgressView().controlSize(.small) }
                    Text(failed ? LocalizedStringKey("图片加载失败") : LocalizedStringKey("正在加载图片…")).font(.system(size: 14))
                    if failed {
                        Button("重试") { failed = false }
                            .buttonStyle(.plain).underline()
                    }
                }
                .foregroundStyle(ThemeColor.kTextSubtle)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ThemeColor.kBackgroundNeutral)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ThemeColor.kBorder, lineWidth: 1))
        .task(id: "\(url?.absoluteString ?? "")-\(failed)") {
            guard !failed else { return }
            image = nil
            do {
                guard let url else { throw URLError(.badURL) }
                let data = try await ChatImageService.shared.imageData(from: url)
                try Task.checkCancellation()
                guard let decoded = NSImage(data: data) else { throw URLError(.cannotDecodeContentData) }
                image = decoded
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}

private struct ChatInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        do {
            let data = try await ChatImageService.shared.imageData(from: url)
            guard let image = NSImage(data: data) else { throw URLError(.cannotDecodeContentData) }
            // Inline images stay within the text line; standalone images use the full block.
            image.size = NSSize(width: 20 * image.size.width / max(1, image.size.height), height: 20)
            return Image(nsImage: image)
        } catch {
            if Task.isCancelled { throw error }
            return Image(systemName: "photo")
        }
    }
}

#Preview(NSLocalizedString("Markdown 回复", comment: "")) {
    ChatMarkdownView(text: """
    你好！我是 **Asky**，你的 macOS 个人助理。

    比如：
    - 查看或新建日程、提醒事项
    - 查找联系人、准备短信草稿
    - 搜索或新建备忘录
    - 运行快捷指令

    ## 更多格式
    1. **粗体**、*斜体*、`行内代码`
    2. [链接](https://example.com)
       - 嵌套列表

    > 引用内容

    ```swift
    let greeting = "你好"
    ```

    | 功能 | 状态 |
    | --- | --- |
    | Markdown | 支持 |
    """)
    .padding(24)
    .frame(width: 640)
}
