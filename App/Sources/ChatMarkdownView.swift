import SwiftUI
import MarkdownUI
import Theme

/// Shared by live replies and reopened history; the stored content remains Markdown source.
struct ChatMarkdownView: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Markdown(text)
            .markdownTheme(.basic)
            .markdownTextStyle {
                FontSize(16)
                ForegroundColor(ThemeColor("text").color(for: colorScheme))
            }
            .markdownTextStyle(\.link) {
                ForegroundColor(.accentColor)
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
            // Model output must not initiate image downloads or local file reads.
            .markdownImageProvider(ChatImagePlaceholder())
            .markdownInlineImageProvider(ChatInlineImagePlaceholder())
            .textSelection(.enabled)
    }
}

private struct ChatImagePlaceholder: ImageProvider {
    func makeImage(url: URL?) -> some View {
        Label("图片", systemImage: "photo")
            .foregroundStyle(ThemeColor.kTextSubtle)
    }
}

private struct ChatInlineImagePlaceholder: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        Image(systemName: "photo")
    }
}

#Preview("Markdown 回复") {
    ChatMarkdownView(text: """
    你好！我是 **KulaHere**，你的 macOS 个人助理。

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
