# Models

An endpoint model holds the fields of one request. A read model describes a request that [`api`](@ref) sends, and an order model describes what [`submit`](@ref), `close`, and [`roll`](@ref) trade. Every model has a keyword constructor, and each keyword that has a default matches the query parameter that Alpaca uses.

The abstract type of a read model selects the base URL that [`url`](@ref) uses: trading, stock data, or options data.

## Abstract types

```@docs
AbstractAlpacaEndpointModel
AbstractAlpacaTradingEndpointModel
AbstractAlpacaStockDataEndpointModel
AbstractAlpacaOptionDataEndpointModel
AbstractAlpacaOrderModel
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
```

## Option data read models

```@docs
MyOptionBarsEndpointModel
MyOptionQuotesEndpointModel
MyOptionTradesEndpointModel
MyOptionLatestBarEndpointModel
MyOptionLatestQuoteEndpointModel
MyOptionLatestTradeEndpointModel
MyOptionSnapshotsEndpointModel
MyOptionChainEndpointModel
```

## Order models

```@docs
MyEquityOrderModel
MyOptionLegModel
MyMixedOrderModel
```
