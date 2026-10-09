import Testing
import Foundation
@testable import DirectActions

@Suite struct CalculatorTests {
    @Test(arguments: [("2+3*4", 14.0), ("(2+3)*4", 20), ("2^10", 1024), ("10/4", 2.5), ("1,000*2", 2000),
                      ("3×4", 12), ("-2+5", 3), ("2^3^2", 512), ("10 % 3", 1)])
    func evaluates(_ input: String, _ expected: Double) {
        #expect(Calculator.evaluate(input) == expected)
    }

    @Test(arguments: ["hello", "1/0", "-5", "42", "2+", "system(\"ls\")", "1+2;rm"])
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
        try reg.upsert(KeywordCommand(keyword: "gh", name: "GitHub", urlTemplate: "https://github.com/search?q={query}"))
        #expect(reg.match("gh kula")?.1 == "kula")
        #expect(throws: KeywordRegistry.RegistryError.duplicate) {
            try reg.upsert(KeywordCommand(keyword: "go", name: "x", urlTemplate: "https://x.com/{query}"))
        }
        #expect(throws: KeywordRegistry.RegistryError.invalidTemplate) {
            try reg.upsert(KeywordCommand(keyword: "js", name: "x", urlTemplate: "javascript:alert({query})"))
        }
        #expect(throws: KeywordRegistry.RegistryError.invalidKeyword) {
            try reg.upsert(KeywordCommand(keyword: ">", name: "x", urlTemplate: "https://x.com/{query}"))
        }
        reg.remove("gh")
        #expect(reg.match("gh kula") == nil)
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
