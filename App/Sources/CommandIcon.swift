import AppKit
import SwiftUI

/// Shared artwork and geometry for command settings, scope icons and results.
struct CommandIcon: View {
    enum Brand: String, CaseIterable {
        case google = "go", chatGPT = "chat", youtube = "yt", douyin = "dy"
        case taobao = "tb", jd = "jd", bilibili = "bl", github = "gh"

        var asset: String {
            switch self {
            case .google: "CommandGoogle"
            case .chatGPT: "CommandChatGPT"
            case .youtube: "CommandYouTube"
            case .douyin: "CommandDouyin"
            case .taobao: "CommandTaobao"
            case .jd: "CommandJD"
            case .bilibili: "CommandBilibili"
            case .github: "CommandGitHub"
            }
        }
    }

    static let size: CGFloat = 24
    static let cornerRadius: CGFloat = 6

    private let image: Image
    private let artworkSize: CGFloat

    init(keyword: String) {
        if let brand = Brand(rawValue: keyword.lowercased()) {
            image = Image(brand.asset)
            // The official ChatGPT app artwork includes its own transparent inset.
            artworkSize = brand == .chatGPT ? Self.size : 18
        } else {
            image = Image(systemName: "globe")
            artworkSize = 18
        }
    }

    init(terminalIcon: NSImage?) {
        image = terminalIcon.map(Image.init(nsImage:)) ?? Image(systemName: "terminal")
        // macOS application artwork also includes an inset around the app tile.
        artworkSize = terminalIcon == nil ? 18 : Self.size
    }

    var body: some View {
        image.resizable().scaledToFit()
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            .frame(width: Self.size, height: Self.size)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
            }
    }
}
