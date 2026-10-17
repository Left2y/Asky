import AppKit
import SwiftUI

/// Shared artwork and geometry for command settings, scope icons and results.
struct CommandIcon: View {
    enum Brand: String, CaseIterable {
        case google = "go", chatGPT = "chat", deepSeek = "ds", youtube = "yt", douyin = "dy"
        case taobao = "tb", jd = "jd", bilibili = "bl", github = "gh"

        case baidu = "bd", huaban = "hb", zhihu = "zh", xiaohongshu = "xhs", weibo = "wb"

        var asset: String {
            switch self {
            case .google: "CommandGoogle"
            case .chatGPT: "CommandChatGPT"
            case .deepSeek: "CommandDeepSeek"
            case .youtube: "CommandYouTube"
            case .douyin: "CommandDouyin"
            case .taobao: "CommandTaobao"
            case .jd: "CommandJD"
            case .bilibili: "CommandBilibili"
            case .github: "CommandGitHub"
            case .baidu: "CommandBaidu"
            case .huaban: "CommandHuaban"
            case .zhihu: "CommandZhihu"
            case .xiaohongshu: "CommandXiaohongshu"
            case .weibo: "CommandWeibo"
            }
        }
    }

    static let size: CGFloat = 24
    static let cornerRadius: CGFloat = 6

    private let image: Image
    private let artworkSize: CGFloat
    private let artworkScale: CGFloat

    init(keyword: String) {
        if let brand = Brand(rawValue: keyword.lowercased()) {
            image = Image(brand.asset).renderingMode(brand == .github ? .template : .original)
            // Keep the visible longest edge at 20 pt inside the shared 24 pt slot.
            // ChatGPT's solid tile is 824 px in a 1024 px canvas; the faint outer
            // shadow reaches 882 px but must not count toward its visible size.
            // DeepSeek's white tile fills its canvas and needs no compensation.
            artworkSize = brand == .chatGPT ? 20 * 1024 / 824 : 20
            // Douyin's note occupies only 392 / 512 px of its dark canvas.
            // Enlarge the artwork within the tile without enlarging the tile itself.
            artworkScale = brand == .douyin ? 1.12 : 1
        } else {
            image = Image(mingCute: "globe")
            artworkSize = 18
            artworkScale = 1
        }
    }

    init(terminalIcon: NSImage?) {
        image = terminalIcon.map(Image.init(nsImage:)) ?? Image(mingCute: "terminal")
        // macOS application artwork also includes an inset around the app tile.
        artworkSize = terminalIcon == nil ? 18 : Self.size
        artworkScale = 1
    }

    var body: some View {
        image.resizable().scaledToFit()
            .frame(width: artworkSize, height: artworkSize)
            .scaleEffect(artworkScale)
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .frame(width: Self.size, height: Self.size)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}
