import DirectActions

extension ToolService {
    public static func prefetchLauncherCurrency(service: ExchangeRateService) async {
        await service.prefetch()
    }

    /// All launcher exchange-rate network/cache reads pass through ToolService.
    public static func launcherCurrencyResults(_ query: CurrencyQuery, service: ExchangeRateService) async -> [CurrencyResult] {
        await service.conversions(query)
    }
}
