import Foundation

/// All rectangles use Accessibility coordinates: origin at the primary display's top-left, y down.
enum LauncherWindowDisplayLayout {
    static func target(for window: CGRect, displays: [CGRect], direction: Int) -> Int? {
        guard displays.count > 1, direction == -1 || direction == 1 else { return nil }
        let xs = displays.map(\.midX), ys = displays.map(\.midY)
        let horizontal = xs.max()! - xs.min()! >= ys.max()! - ys.min()!
        let order = displays.indices.sorted { a, b in
            let first = horizontal ? displays[a].midX : displays[a].midY
            let second = horizontal ? displays[b].midX : displays[b].midY
            if first != second { return first < second }
            let secondaryA = horizontal ? displays[a].midY : displays[a].midX
            let secondaryB = horizontal ? displays[b].midY : displays[b].midX
            return secondaryA == secondaryB ? a < b : secondaryA < secondaryB
        }
        guard let current = source(for: window, displays: displays),
              let index = order.firstIndex(of: current) else { return nil }
        return order[(index + direction + order.count) % order.count]
    }

    static func frame(for window: CGRect, source: CGRect, destination: CGRect) -> CGRect {
        let size = CGSize(width: min(window.width, destination.width), height: min(window.height, destination.height))
        let x = (window.minX - source.minX) / max(1, source.width - window.width)
        let y = (window.minY - source.minY) / max(1, source.height - window.height)
        return CGRect(x: destination.minX + min(1, max(0, x)) * (destination.width - size.width),
                      y: destination.minY + min(1, max(0, y)) * (destination.height - size.height),
                      width: size.width, height: size.height)
    }

    static func source(for window: CGRect, displays: [CGRect]) -> Int? {
        displays.indices.max { a, b in
            let areaA = area(window.intersection(displays[a]))
            let areaB = area(window.intersection(displays[b]))
            if areaA != areaB { return areaA < areaB }
            return distance(window, displays[a]) > distance(window, displays[b])
        }
    }

    private static func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        pow(a.midX - b.midX, 2) + pow(a.midY - b.midY, 2)
    }
}
