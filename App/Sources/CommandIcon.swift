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

    init(keyword: String) {
        if let brand = Brand(rawValue: keyword.lowercased()) {
            image = Image(brand.asset).renderingMode(brand == .github ? .template : .original)
            // Official ChatGPT and DeepSeek artwork includes its own inset.
            artworkSize = [.chatGPT, .deepSeek].contains(brand) ? Self.size : 20
        } else {
            image = Image(mingCute: "globe")
            artworkSize = 18
        }
    }

    init(terminalIcon: NSImage?) {
        image = terminalIcon.map(Image.init(nsImage:)) ?? Image(mingCute: "terminal")
        // macOS application artwork also includes an inset around the app tile.
        artworkSize = terminalIcon == nil ? 18 : Self.size
    }

    var body: some View {
        image.resizable().scaledToFit()
            .frame(width: artworkSize, height: artworkSize)
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .frame(width: Self.size, height: Self.size)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}
