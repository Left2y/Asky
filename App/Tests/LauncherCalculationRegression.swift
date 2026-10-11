import AppKit
import DirectActions
import LocalStore

/// Exercises the actual launcher in both appearances using a deterministic dated rate cache.
@main
@MainActor
enum LauncherCalculationRegression {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        Task { @MainActor in
            do {
                for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                    application.appearance = NSAppearance(named: appearance)
                    try await check(appearance.rawValue)
                }
                print("Launcher calculation/currency native regression passed")
                exit(0)
            } catch {
                print("FAILED: \(error)")
                exit(1)
            }
        }
        application.run()
    }

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "CalculatorRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func check(_ appearance: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Asky-calculation-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try AppModel(root: root)
        let snapshot = ExchangeRates(date: "2026-10-08", perEUR: ["USD": 1.1, "CNY": 7.7, "JPY": 165,
            "GBP": 0.85, "HKD": 8.6, "KRW": 1500, "SGD": 1.5, "AUD": 1.65, "CAD": 1.5], fetchedAt: Date())
        try JSONEncoder().encode(snapshot).write(to: root.appendingPathComponent("ecb-rates.json"))
        let model = LauncherModel(app: app, searchProviders: [])
        let controller = LauncherController(model: model)
        controller.show()
        guard let panel = NSApp.windows.first(where: { $0 is LauncherPanel && $0.isVisible }) as? LauncherPanel else {
            throw NSError(domain: "CalculatorRegression", code: 2)
        }
        panel.onBlur = {}
        defer { controller.hide() }
        try await Task.sleep(for: .milliseconds(100))
        guard let field = findField(panel.contentView!), field.currentEditor() is NSTextView else {
            throw NSError(domain: "CalculatorRegression", code: 3)
        }
        func setQuery(_ value: String) {
            // Keep the active field editor in sync so a later edit callback cannot
            // replace the model query with text left over from the previous case.
            field.stringValue = value
            if let editor = field.currentEditor() as? NSTextView { editor.string = value }
            model.query = value
        }
        let currencyOnly = CommandLine.arguments.contains("--currency-only")
        if currencyOnly {
            panel.makeFirstResponder(nil)
            panel.resignKey()
        } else {
        setQuery("1+1")
        try await Task.sleep(for: .milliseconds(250))
        try require(model.calculationCompletion == "= 2", "calculator completion")
        try require(model.results.first?.primaryAction == .copy("2"), "Return copies the computed value")
        field.updateCompletion()
        try require(field.stringValue == "1+1", "ghost must not enter query")
        try require(field.subviews.contains { ($0 as? NSTextField)?.stringValue == "= 2" && !$0.isHidden }, "ghost must be visible")
        try capture(panel, "calculator-\(appearance)")
        if let editor = field.currentEditor() as? NSTextView {
            editor.setSelectedRange(NSRange(location: 1, length: 0))
            field.updateCompletion()
            try require(!field.subviews.contains { ($0 as? NSTextField)?.stringValue == "= 2" && !$0.isHidden }, "mid-text caret hides suffix")
            editor.setSelectedRange(NSRange(location: 3, length: 0))
        }
        let longExpression = Array(repeating: "123456789", count: 24).joined(separator: "+")
        setQuery(longExpression)
        try await Task.sleep(for: .milliseconds(250))
        try require(model.calculation?.expression == longExpression, "long expression remains complete")
        try require(model.calculation?.result == "2962962936", "long expression result")
        try capture(panel, "calculator-long-\(appearance)")
        setQuery("123456789012345 * 123456789012345")
        try await Task.sleep(for: .milliseconds(250))
        try capture(panel, "calculator-large-\(appearance)")
        setQuery("1+")
        try require(model.calculationCompletion == nil, "incomplete expression clears ghost")
        try require(model.calculation == nil, "incomplete expression clears card")
        }
        setQuery("1美元")
        for _ in 0..<50 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(!model.isSearching, "currency loading must finish")
        let rows = model.results.filter { $0.source == .currency }
        try require(rows.count == snapshot.perEUR.count - 1, "all other currencies remain below the card")
        try require(rows.first?.target.identifier == "CNY", "CNY first")
        try require(rows.allSatisfy { $0.primaryAction == nil }, "currencies have no copy action")
        guard case .converted(let converted, _, _, _, let pair) = model.currencyConversion else {
            throw NSError(domain: "CalculatorRegression", code: 4)
        }
        try require(pair.from == "USD" && pair.to == "CNY" && pair.amount == 1 && converted == 7,
                    "card shows the input amount and yuan conversion")
        try require(rows.allSatisfy { $0.subtitle.isEmpty && CurrencyPresentation.flag(for: $0.target.identifier) != nil }, "value-only rows and flags")
        try await Task.sleep(for: .milliseconds(200))
        try capture(panel, "currency-\(appearance)")
        model.move(1)
        try require(model.selection == 0, "currency has no keyboard selection")
        try await Task.sleep(for: .milliseconds(100))
        try capture(panel, "currency-selected-\(appearance)")
        setQuery("1美元")
        setQuery("Safari")
        try await Task.sleep(for: .milliseconds(400))
        try require(!model.results.contains { $0.source == .currency }, "cancelled FX cannot overwrite new query")
        setQuery("100人民币")
        for _ in 0..<50 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(model.results.first?.target.identifier == "USD", "CNY converts outward")
        setQuery("100 USD CNY")
        for _ in 0..<50 {
            if !model.isSearching { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        try require(model.results.filter { $0.source == .currency }.count == 1, "explicit pairs show only requested currency")
        print("\(appearance): ghost, flags, CNY, reverse conversion, cancellation and explicit pair passed")
    }

    static func findField(_ view: NSView) -> CompletionTextField? {
        if let field = view as? CompletionTextField { return field }
        return view.subviews.lazy.compactMap(findField).first
    }

    static func capture(_ panel: NSPanel, _ name: String) throws {
        guard let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try data.write(to: URL(filePath: "build/\(name).png"))
        }
    }
}
