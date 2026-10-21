import AppKit
import SwiftUI
@preconcurrency import SwiftMath
import Theme

/// Presentation-only conversion: history and message copying retain the original LaTeX.
enum ChatMath {
    struct Formula {
        let source: String
        let display: Bool
    }

    static func formula(_ url: URL?) -> Formula? {
        guard let url, url.scheme == "asky-math",
              let data = Data(base64Encoded: String(url.path.dropFirst())),
              let source = String(data: data, encoding: .utf8) else { return nil }
        return Formula(source: source, display: url.host == "display")
    }

    /// Protect code, escaped delimiters, and Markdown link/image destinations before math parsing.
    static func markdown(_ source: String) -> String {
        let chars = Array(source)
        var result = ""
        var i = 0
        var fence: (Character, Int)?
        func matches(_ value: String, at index: Int) -> Bool {
            let token = Array(value)
            return index + token.count <= chars.count && Array(chars[index..<(index + token.count)]) == token
        }
        while i < chars.count {
            if i == 0 || chars[i - 1] == "\n" {
                if fence == nil && (matches("    ", at: i) || chars[i] == "\t") {
                    var end = i
                    while end < chars.count && chars[end] != "\n" { end += 1 }
                    result += String(chars[i..<end]); i = end; continue
                }
                var start = i
                while start < chars.count && start - i < 3 && chars[start] == " " { start += 1 }
                if start < chars.count && (chars[start] == "`" || chars[start] == "~") {
                    var end = start
                    while end < chars.count && chars[end] == chars[start] { end += 1 }
                    if end - start >= 3 {
                        if let active = fence {
                            if active.0 == chars[start] && end - start >= active.1 { fence = nil }
                        } else { fence = (chars[start], end - start) }
                        while end < chars.count && chars[end] != "\n" { end += 1 }
                        result += String(chars[i..<end]); i = end; continue
                    }
                }
            }
            if fence != nil { result.append(chars[i]); i += 1; continue }
            if chars[i] == "`" {
                var end = i
                while end < chars.count && chars[end] == "`" { end += 1 }
                let token = String(chars[i..<end])
                var close = end
                while close < chars.count {
                    if matches(token, at: close),
                       close + token.count == chars.count || chars[close + token.count] != "`" { break }
                    close += 1
                }
                if close < chars.count { end = close + token.count }
                result += String(chars[i..<end]); i = end; continue
            }
            if matches("](", at: i) {
                var end = i + 2
                var depth = 1
                while end < chars.count && depth > 0 {
                    if chars[end] == "\\" { end = min(chars.count, end + 2); continue }
                    if chars[end] == "(" { depth += 1 }
                    if chars[end] == ")" { depth -= 1 }
                    end += 1
                }
                result += String(chars[i..<end]); i = end; continue
            }
            let opener: String?
            let closer: String
            if matches("$$", at: i) { opener = "$$"; closer = "$$" }
            else if matches("\\[", at: i) { opener = "\\["; closer = "\\]" }
            else if matches("\\(", at: i) { opener = "\\("; closer = "\\)" }
            else if chars[i] == "$" { opener = "$"; closer = "$" }
            else { opener = nil; closer = "" }
            if let opener {
                let start = i + opener.count
                let display = opener == "$$" || opener == "\\["
                var end = start
                while end < chars.count {
                    if matches(closer, at: end) { break }
                    if display && matches("\n\n", at: end) { break }
                    if !display && chars[end] == "\n" { break }
                    if chars[end] == "\\" { end += 1 }
                    end += 1
                }
                let latex = String(chars[start..<min(end, chars.count)])
                let validEdges = display || (latex.first?.isWhitespace == false && latex.last?.isWhitespace == false)
                // Dollar amounts such as $20 and $30 are ordinary prose.
                let currency = opener == "$" && latex.first?.isNumber == true
                    && end + 1 < chars.count && chars[end + 1].isNumber
                if end < chars.count && matches(closer, at: end) && !latex.isEmpty && validEdges && !currency {
                    let encoded = Data(latex.utf8).base64EncodedString()
                    let image = "![formula](asky-math://\(display ? "display" : "inline")/\(encoded))"
                    result += display ? "\n\n\(image)\n\n" : image
                    i = end + closer.count; continue
                }
            }
            if chars[i] == "\\", i + 1 < chars.count {
                result += String(chars[i...i + 1]); i += 2
            } else { result.append(chars[i]); i += 1 }
        }
        return result
    }
}

@MainActor
enum ChatMathRenderer {
    final class Rendered {
        let image: NSImage
        let descent: CGFloat
        init(image: NSImage, descent: CGFloat) { self.image = image; self.descent = descent }
    }
    private static let cache: NSCache<NSString, Rendered> = {
        let cache = NSCache<NSString, Rendered>()
        cache.countLimit = 256
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func sourceImage(_ source: String, color: NSColor) -> NSImage {
        let text = NSAttributedString(string: source, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular), .foregroundColor: color])
        let image = NSImage(size: NSSize(width: max(1, text.size().width), height: max(1, text.size().height)))
        image.lockFocus()
        text.draw(at: .zero)
        image.unlockFocus()
        return image
    }

    static func render(_ formula: ChatMath.Formula, color: NSColor) -> Rendered? {
        let key = "\(formula.display)|\(color.description)|\(formula.source)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        // Bound layout work for malformed or unexpectedly large streamed output.
        guard formula.source.count < 8192 else { return nil }
        let label = MTMathUILabel()
        label.fontSize = formula.display ? 18 : 14
        label.labelMode = formula.display ? .display : .text
        label.textColor = color
        label.latex = formula.source
        guard label.error == nil else { return nil }
        label.frame = NSRect(origin: .zero, size: label.fittingSize)
        label.layout()
        guard let display = label.displayList else { return nil }
        let size = NSSize(width: ceil(display.width) + 4, height: ceil(display.ascent + display.descent) + 4)
        guard size.width > 4, size.width < 16000, size.height < 4000 else { return nil }
        // Draw immediately on the main actor; the resulting image contains no deferred math work.
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2),
            pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }
        context.cgContext.scaleBy(x: 2, y: 2)
        context.cgContext.translateBy(x: 2, y: 2)
        display.draw(context.cgContext)
        bitmap.size = size
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        let rendered = Rendered(image: image, descent: display.descent + 2)
        cache.setObject(rendered, forKey: key, cost: bitmap.bytesPerRow * bitmap.pixelsHigh)
        return rendered
    }
}

struct ChatMathBlock: View {
    let formula: ChatMath.Formula
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ScrollView(.horizontal) {
            if let rendered = ChatMathRenderer.render(formula, color: NSColor(ThemeColor("text").color(for: colorScheme))) {
                Image(nsImage: rendered.image).accessibilityLabel(formula.source)
            } else {
                Text(formula.source).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
            }
        }
    }
}
