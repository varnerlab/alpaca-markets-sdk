# Models

An endpoint model holds the fields of one request. A read model describes a request that [`api`](@ref) sends, and an order model describes what [`submit`](@ref), `close`, and [`roll`](@ref) trade. Every model has a keyword constructor. Each keyword that sets a query parameter has the name of that Alpaca query parameter, except `finish`, which sets `end` because `end` is a reserved word in Julia.

The abstract type of a read model selects the base URL that [`url`](@ref) uses: trading, US stock data, non-US stock data, option data, crypto data, or the market-data extras (news, screener, logos, and fixed income).

## Abstract types

```@docs
AbstractAlpacaEndpointModel
AbstractAlpacaTradingEndpointModel
AbstractAlpacaStockDataEndpointModel
AbstractAlpacaOptionDataEndpointModel
AbstractAlpacaOrderModel
AbstractAlpacaCryptoDataEndpointModel
AbstractAlpacaGlobalStockDataEndpointModel
AbstractAlpacaMarketDataEndpointModel
```

## Trading read models

```@docs
MyAccountEndpointModel
MyClockEndpointModel
MyCalendarEndpointModel
MyAssetsEndpointModel
MyAssetEndpointModel
MyPositionsEndpointModel
MyPositionEndpointModel
MyOrdersEndpointModel
MyOrderEndpointModel
MyOptionContractsEndpointModel
MyOptionContractEndpointModel
MyAccountConfigurationsEndpointModel
MyAccountActivitiesEndpointModel
MyPortfolioHistoryEndpointModel
MyMarketCalendarEndpointModel
MyMarketClocksEndpointModel
```

## Watchlist models

```@docs
MyWatchlistsEndpointModel
MyWatchlistEndpointModel
MyCreateWatchlistEndpointModel
MyUpdateWatchlistEndpointModel
MyAddWatchlistAssetEndpointModel
MyRemoveWatchlistAssetEndpointModel
MyDeleteWatchlistEndpointModel
```

## Trading write models

```@docs
MyUpdateAccountConfigurationsEndpointModel
MyReplaceOrderEndpointModel
MyExerciseOptionEndpointModel
MyDoNotExerciseOptionEndpointModel
```

## Stock data read models

```@docs
MyStockBarsEndpointModel
MyStockQuotesEndpointModel
MyStockTradesEndpointModel
MyStockLatestBarEndpointModel
MyStockLatestQuoteEndpointModel
MyStockLatestTradeEndpointModel
MyStockSnapshotsEndpointModel
MyStockLatestBarsEndpointModel
MyStockLatestQuotesEndpointModel
MyStockLatestTradesEndpointModel
MyStockAuctionsEndpointModel
MyStockConditionsEndpointModel
MyStockExchangesEndpointModel
```

## Non-US stock data read models

```@docs
MyGlobalStockBarsEndpointModel
MyGlobalStockQuotesEndpointModel
MyGlobalStockTradesEndpointModel
MyGlobalStockLatestBarsEndpointModel
MyGlobalStockLatestQuotesEndpointModel
MyGlobalStockLatestTradesEndpointModel
MyGlobalStockSnapshotsEndpointModel
```

## Option data read models

```@docs
MyOptionBarsEndpointModel
MyOptionTradesEndpointModel
MyOptionLatestQuoteEndpointModel
MyOptionLatestTradeEndpointModel
MyOptionSnapshotsEndpointModel
MyOptionChainEndpointModel
MyOptionExchangesEndpointModel
MyOptionConditionsEndpointModel
```

## Crypto data read models

```@docs
MyCryptoBarsEndpointModel
MyCryptoQuotesEndpointModel
MyCryptoTradesEndpointModel
MyCryptoLatestBarsEndpointModel
MyCryptoLatestQuotesEndpointModel
MyCryptoLatestTradesEndpointModel
MyCryptoLatestOrderbooksEndpointModel
MyCryptoSnapshotsEndpointModel
```

## News, screener, corporate actions, logos, and fixed income read models

```@docs
MyNewsEndpointModel
MyMostActivesEndpointModel
MyMoversEndpointModel
MyCorporateActionsEndpointModel
MyLogoEndpointModel
MyFixedIncomeLatestPricesEndpointModel
MyFixedIncomeLatestQuotesEndpointModel
```

## Order models

```@docs
MyEquityOrderModel
MyCryptoOrderModel
MyOptionLegModel
MyMixedOrderModel
```
