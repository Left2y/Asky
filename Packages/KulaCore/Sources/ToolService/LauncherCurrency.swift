import DirectActions

extension ToolService {
    /// All launcher exchange-rate network/cache reads pass through ToolService.
    public static func launcherCurrencyResults(_ query: CurrencyQuery, service: ExchangeRateService) async -> [CurrencyResult] {
        await service.conversions(query)
    }
}
