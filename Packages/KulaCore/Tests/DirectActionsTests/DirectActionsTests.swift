import Testing
import Foundation
@testable import DirectActions

@Suite struct CalculatorTests {
    @Test(arguments: [("2+3*4", 14.0), ("(2+3)*4", 20), ("2^10", 1024), ("10/4", 2.5), ("1,000*2", 2000),
                      ("3×4", 12), ("-2+5", 3), ("2^3^2", 512), ("10 % 3", 1),
                      ("(12-1)*3", 33), ("(12–1)*3", 33), ("(12−1)×3", 33),
                      ("(12—1)*3", 33), ("（１２－１）＊３", 33),
                      ("((12−1)×3+7)÷2", 20), ("（12－1）×（2＋3）", 55)])
    func evaluates(_ input: String, _ expected: Double) {
        #expect(Calculator.evaluate(input) == expected)
    }

    @Test(arguments: ["hello", "1/0", "-5", "42", "2+", "system(\"ls\")", "1+2;rm",
                      "（12－1", "（12－1）÷0", "１２", "−５", "（12－1）×", "１＋２；rm"])
    func rejects(_ input: String) {
        #expect(Calculator.evaluate(input) == nil)
    }

    @Test func formatting() {
        #expect(Calculator.format(3) == "3")
        #expect(Calculator.format(2.5) == "2.5")
    }
}

@Suite struct ConversionTests {
    @Test func temperature() throws {
        let c = try #require(UnitConverter.convert("100 f to c"))
        #expect(abs(c.value - 37.7778) < 0.001)
    }

    @Test func chineseUnits() throws {
        let c = try #require(UnitConverter.convert("2 公斤 斤"))
        #expect(abs(c.value - 4) < 1e-9)
    }

    @Test func incompatibleDimensions() {
        #expect(UnitConverter.convert("10 kg km") == nil)
        #expect(UnitConverter.convert("km to mi") == nil)
    }
}

@Suite struct CurrencyTests {
    static let ecb = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
    <Cube><Cube time="2026-10-08"><Cube currency="USD" rate="1.1000"/><Cube currency="CNY" rate="7.7000"/></Cube></Cube>
    </gesmes:Envelope>
    """

    @Test func parsesECBAndCrossConverts() throws {
        let r = try #require(ExchangeRates.parseECB(Data(Self.ecb.utf8)))
        #expect(r.date == "2026-10-08")
        let (v, rate) = try #require(r.convert(10, from: "USD", to: "CNY"))
        #expect(abs(rate - 7) < 1e-9)
        #expect(abs(v - 70) < 1e-9)
        #expect(r.convert(1, from: "EUR", to: "USD")?.rate == 1.1) // EUR is the implicit base
        #expect(r.convert(1, from: "USD", to: "XYZ") == nil)
    }

    @Test func queryAliases() {
        #expect(CurrencyQuery.parse("100美元 人民币") == CurrencyQuery(amount: 100, from: "USD", to: "CNY"))
        #expect(CurrencyQuery.parse("100 usd usd") == nil)
        #expect(CurrencyQuery.parse("100 abc cny") == nil)
    }

    @Test func noCacheNoNetworkIsUnavailable() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let svc = ExchangeRateService(cacheURL: dir.appendingPathComponent("rates.json"))
        let r = await svc.convert(CurrencyQuery(amount: 1, from: "USD", to: "CNY"), allowNetwork: false)
        guard case .unavailable = r else { Issue.record("must not fabricate a rate"); return }
    }
}

@Suite struct KeywordTests {
    @Test func crudAndValidation() throws {
        var reg = KeywordRegistry()
        try reg.upsert(KeywordCommand(keyword: "git", name: "GitHub", urlTemplate: "https://github.com/search?q={query}"))
        #expect(reg.match("git kula")?.1 == "kula")
        #expect(throws: KeywordRegistry.RegistryError.duplicate) {
            try reg.upsert(KeywordCommand(keyword: "go", name: "x", urlTemplate: "https://x.com/{query}"))
        }
        #expect(throws: KeywordRegistry.RegistryError.invalidTemplate) {
            try reg.upsert(KeywordCommand(keyword: "js", name: "x", urlTemplate: "javascript:alert({query})"))
        }
        #expect(throws: KeywordRegistry.RegistryError.invalidKeyword) {
            try reg.upsert(KeywordCommand(keyword: ">", name: "x", urlTemplate: "https://x.com/{query}"))
        }
        reg.remove("git")
        #expect(reg.match("git kula") == nil)
    }

    @Test func plainWebsiteAddressesAndPersistence() throws {
        var registry = KeywordRegistry(commands: [])
        try registry.upsert(KeywordCommand(keyword: " chat ", name: "ChatGPT", urlTemplate: " chatgpt.com "))
        try registry.upsert(KeywordCommand(keyword: "gem", name: "Gemini", urlTemplate: "https://gemini.google.com/app"))
        #expect(registry.commands.last?.url(for: "")?.absoluteString == "https://gemini.google.com/app")
        let restored = try JSONDecoder().decode(KeywordRegistry.self, from: JSONEncoder().encode(registry))
        let command = try #require(restored.commands.first { $0.keyword == "chat" })
        #expect(command.url(for: "")?.absoluteString == "https://chatgpt.com")
        #expect(command.url(for: "hello")?.query == "q=hello")
        #expect(restored.matchInput("chat ")?.0 == command)
    }

    @Test func websitePresetsUpgradePreservesCustomEntries() throws {
        let custom = KeywordCommand(keyword: "CHAT", name: "Custom", urlTemplate: "https://example.com")
        var registry = KeywordRegistry(commands: [KeywordCommand.builtIn[0], custom])
        registry.addMissingWebsitePresets(excluding: ["GEMINI"])
        #expect(registry.commands.filter { $0.keyword.lowercased() == "chat" } == [custom])
        #expect(!registry.commands.contains { $0.keyword == "gemini" })
        #expect(!registry.commands.contains { $0.keyword == "doubao" })
        let upgraded = registry
        registry.addMissingWebsitePresets(excluding: ["gemini"])
        #expect(registry == upgraded)
        #expect(KeywordRegistry().commands.count == 8)
    }

    @Test func chatGPTCarriesQueryWithoutUserTemplate() throws {
        let command = KeywordCommand.websitePresets[0]
        #expect(command.supportsQuery)
        let url = try #require(command.url(for: "中文 & + # / ?"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first { $0.name == "q" }?.value == "中文 & + # / ?")
        #expect(url.absoluteString.contains("%2B"))
        #expect(command.url(for: "")?.query == nil)
        #expect(KeywordCommand.websitePresets.allSatisfy { $0.supportsQuery })
    }

    @Test func migratesRetiredDefaultsAndShortKeyword() {
        let old = KeywordCommand(keyword: "chatgpt", name: "ChatGPT", urlTemplate: "https://chatgpt.com")
        let retired = KeywordCommand(keyword: "gemini", name: "Gemini", urlTemplate: "https://gemini.google.com")
        let custom = KeywordCommand(keyword: "doubao", name: "Custom", urlTemplate: "https://example.com/search?q={query}")
        var registry = KeywordRegistry(commands: [old, retired, custom])
        registry.migrateQueryPresets()
        #expect(registry.commands == [custom, KeywordCommand.websitePresets[0]])
        registry.migrateQueryPresets()
        #expect(registry.commands == [custom, KeywordCommand.websitePresets[0]])
        var conflict = KeywordRegistry(commands: [old])
        conflict.migrateQueryPresets(excluding: ["CHAT"])
        #expect(conflict.commands == [old])
    }

    @Test func rejectsInvalidWebsiteAddresses() {
        for address in ["", "https://", "file:///tmp/a", "javascript:alert(1)", "not a website", "https://user:pass@example.com"] {
            var registry = KeywordRegistry()
            #expect(throws: KeywordRegistry.RegistryError.invalidTemplate) {
                try registry.upsert(KeywordCommand(keyword: "site", name: "Site", urlTemplate: address))
            }
        }
    }

    @Test func encodesQuerySafely() throws {
        let url = try #require(KeywordCommand.builtIn[0].url(for: "a&b=c #d"))
        #expect(url.query?.contains("a%26b%3Dc%20%23d") == true)
    }
}

@Suite struct TerminalTests {
    @Test func interactiveDetection() {
        #expect(TerminalRunner.isInteractive("vim file"))
        #expect(TerminalRunner.isInteractive("python3"))
        #expect(!TerminalRunner.isInteractive("python3 script.py"))
        #expect(!TerminalRunner.isInteractive("ls -la"))
    }

    @Test func runsAndReportsExitCode() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let runner = TerminalRunner(spillDirectory: dir)
        var output = ""
        var exit: Int32?
        for await e in runner.run("echo hello; echo err >&2; exit 3", workingDirectory: FileManager.default.temporaryDirectory) {
            switch e {
            case .stdout(let s), .stderr(let s): output += s
            case .exited(let c, _): exit = c
            default: break
            }
        }
        #expect(output.contains("hello"))
        #expect(output.contains("err"))
        #expect(exit == 3)
    }
}
