import Foundation
import SwiftUI
import LocalStore

/// A preview derived from explicit color syntax. Clipboard storage remains plain text.
struct ClipboardColor {
    let text: String
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var hex: String {
        let channels = [red, green, blue] + (alpha < 1 ? [alpha] : [])
        return "#" + channels.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    init?(item: ClipboardItem) {
        guard item.kind == .text, let original = item.text, original.utf8.count <= 2048 else { return nil }
        let token = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.utf8.count <= 128, let rgba = Self.parse(token), rgba.allSatisfy(\.isFinite) else { return nil }
        text = original
        red = Self.clamp(rgba[0]); green = Self.clamp(rgba[1]); blue = Self.clamp(rgba[2])
        alpha = Self.clamp(rgba[3])
    }

    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    private static func parse(_ token: String) -> [Double]? {
        if token.hasPrefix("#") {
            var digits = String(token.dropFirst())
            guard [3, 4, 6, 8].contains(digits.count), digits.utf8.allSatisfy({
                (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
            }) else { return nil }
            if digits.count < 5 { digits = digits.map { "\($0)\($0)" }.joined() }
            guard let bits = UInt32(digits, radix: 16) else { return nil }
            let rgb = digits.count == 8 ? bits >> 8 : bits
            return [Double((rgb >> 16) & 255) / 255, Double((rgb >> 8) & 255) / 255,
                    Double(rgb & 255) / 255, digits.count == 8 ? Double(bits & 255) / 255 : 1]
        }
        guard let open = token.firstIndex(of: "("), token.last == ")" else { return nil }
        let name = token[..<open].lowercased()
        guard ["rgb", "rgba", "hsl", "hsla", "oklch"].contains(name) else { return nil }
        let body = token[token.index(after: open)..<token.index(before: token.endIndex)]
        let channels: [String]
        if body.contains(",") {
            guard name != "oklch", !body.contains("/") else { return nil }
            channels = body.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard channels.count == 3 || channels.count == 4 else { return nil }
        } else {
            let groups = body.components(separatedBy: "/").map { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
            guard groups.count <= 2, groups[0].count == 3,
                  groups.count == 1 || groups[1].count == 1 else { return nil }
            channels = groups.flatMap { $0 }
        }
        guard let opacity = channels.count == 4 ? number(channels[3], scale: 1) : 1 else { return nil }
        switch name {
        case "rgb", "rgba":
            let rgb = channels.prefix(3).compactMap { number($0, scale: 255) }
            guard rgb.count == 3 else { return nil }
            return rgb + [opacity]
        case "hsl", "hsla":
            guard let hue = hue(channels[0]), channels[1].hasSuffix("%"), channels[2].hasSuffix("%"),
                  let saturation = number(channels[1], scale: 1), let lightness = number(channels[2], scale: 1) else { return nil }
            let l = clamp(lightness), s = clamp(saturation)
            let amplitude = s * min(l, 1 - l)
            let rgb = [0.0, 8.0, 4.0].map { offset in
                let k = (offset + hue / 30).truncatingRemainder(dividingBy: 12)
                return l - amplitude * max(-1, min(k - 3, 9 - k, 1))
            }
            return rgb + [opacity]
        case "oklch":
            guard let l = number(channels[0], scale: 1), let c = number(channels[1], scale: 0.4),
                  let h = hue(channels[2]) else { return nil }
            return oklch(lightness: clamp(l), chroma: max(0, c) * 0.4, hue: h) + [opacity]
        default: return nil
        }
    }

    /// CSS numeric token, including signed decimals and exponents, excluding NaN and infinity.
    private static func number(_ token: String, scale: Double) -> Double? {
        let percent = token.hasSuffix("%")
        let digits = percent ? String(token.dropLast()) : token
        guard digits.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#,
                           options: .regularExpression) != nil,
              let value = Double(digits), value.isFinite else { return nil }
        let result = value / (percent ? 100 : scale)
        return result.isFinite ? result : nil
    }

    private static func hue(_ token: String) -> Double? {
        let lower = token.lowercased()
        let units: [(String, Double)] = [("turn", 360), ("grad", 0.9), ("deg", 1), ("rad", 180 / .pi)]
        let unit = units.first { lower.hasSuffix($0.0) }
        let digits = unit.map { String(lower.dropLast($0.0.count)) } ?? lower
        guard !digits.hasSuffix("%"), let number = number(digits, scale: 1) else { return nil }
        let degrees = number * (unit?.1 ?? 1)
        guard degrees.isFinite else { return nil }
        return (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// OkLCh → Oklab → linear sRGB → encoded sRGB, clipped to the preview's sRGB gamut.
    private static func oklch(lightness: Double, chroma: Double, hue: Double) -> [Double] {
        let angle = hue * .pi / 180
        let a = chroma * cos(angle), b = chroma * sin(angle)
        let roots = [lightness + 0.3963377774 * a + 0.2158037573 * b,
                     lightness - 0.1055613458 * a - 0.0638541728 * b,
                     lightness - 0.0894841775 * a - 1.2914855480 * b]
        let l = pow(roots[0], 3), m = pow(roots[1], 3), s = pow(roots[2], 3)
        return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s].map {
            let x = clamp($0)
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
    }
}
