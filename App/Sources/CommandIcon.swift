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

    private let image: Image
    private let artworkSize: CGFloat
    private let hasSquareTile: Bool

    init(keyword: String) {
        if let brand = Brand(rawValue: keyword.lowercased()) {
            image = Image(brand.asset).renderingMode(brand == .github ? .template : .original)
            artworkSize = brand == .chatGPT ? Self.size : 20
            hasSquareTile = ![.google, .chatGPT, .youtube, .github].contains(brand)
        } else {
            image = Image(mingCute: "globe")
            artworkSize = 18
            hasSquareTile = false
        }
    }

    init(terminalIcon: NSImage?) {
        image = terminalIcon.map(Image.init(nsImage:)) ?? Image(mingCute: "terminal")
        // macOS application artwork also includes an inset around the app tile.
        artworkSize = terminalIcon == nil ? 18 : Self.size
        hasSquareTile = false
    }

    var body: some View {
        artwork
            .fixedSize()
            .frame(width: Self.size, height: Self.size)
            .fixedSize()
    }

    @ViewBuilder private var artwork: some View {
        if hasSquareTile {
            originalArtwork
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
        } else {
            originalArtwork
        }
    }

    private var originalArtwork: some View {
        image.resizable().scaledToFit()
            .frame(width: artworkSize, height: artworkSize)
            .foregroundStyle(.primary)
    }
}
