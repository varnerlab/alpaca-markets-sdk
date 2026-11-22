# Stock data

These models read the prices of US stocks and of stocks on non-US exchanges. A bar summarizes the trades of one time interval, a quote is the best bid price and ask price at one time, and a trade is one fill. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyStockBarsEndpointModel`](@ref) | Price bars over a range of times |
| [`MyStockQuotesEndpointModel`](@ref) | Quotes over a range of times |
| [`MyStockTradesEndpointModel`](@ref) | Trades over a range of times |
| [`MyStockLatestBarEndpointModel`](@ref) | The latest bar of one stock |
| [`MyStockLatestQuoteEndpointModel`](@ref) | The latest quote of one stock |
| [`MyStockLatestTradeEndpointModel`](@ref) | The latest trade of one stock |
| [`MyStockLatestBarsEndpointModel`](@ref) | The latest bar of each of several stocks |
| [`MyStockLatestQuotesEndpointModel`](@ref) | The latest quote of each of several stocks |
| [`MyStockLatestTradesEndpointModel`](@ref) | The latest trade of each of several stocks |
| [`MyStockSnapshotsEndpointModel`](@ref) | The latest trade, quote, and bars of each of several stocks |
| [`MyStockAuctionsEndpointModel`](@ref) | The opening and closing auctions over a range of dates |
| [`MyStockConditionsEndpointModel`](@ref) | The meaning of each trade or quote condition code |
| [`MyStockExchangesEndpointModel`](@ref) | The name of each exchange code |
| [`MyGlobalStockBarsEndpointModel`](@ref) | Price bars over a range of times |
| [`MyGlobalStockQuotesEndpointModel`](@ref) | Quotes over a range of times |
| [`MyGlobalStockTradesEndpointModel`](@ref) | Trades over a range of times |
| [`MyGlobalStockLatestBarsEndpointModel`](@ref) | The latest bar of each stock |
| [`MyGlobalStockLatestQuotesEndpointModel`](@ref) | The latest quote of each stock |
| [`MyGlobalStockLatestTradesEndpointModel`](@ref) | The latest trade of each stock |
| [`MyGlobalStockSnapshotsEndpointModel`](@ref) | The latest trade, quote, and bars of each stock |

## US stocks

```@docs
MyStockBarsEndpointModel
MyStockQuotesEndpointModel
MyStockTradesEndpointModel
MyStockLatestBarEndpointModel
MyStockLatestQuoteEndpointModel
MyStockLatestTradeEndpointModel
MyStockLatestBarsEndpointModel
MyStockLatestQuotesEndpointModel
MyStockLatestTradesEndpointModel
MyStockSnapshotsEndpointModel
MyStockAuctionsEndpointModel
MyStockConditionsEndpointModel
MyStockExchangesEndpointModel
```

## Non-US stocks

```@docs
MyGlobalStockBarsEndpointModel
MyGlobalStockQuotesEndpointModel
MyGlobalStockTradesEndpointModel
MyGlobalStockLatestBarsEndpointModel
MyGlobalStockLatestQuotesEndpointModel
MyGlobalStockLatestTradesEndpointModel
MyGlobalStockSnapshotsEndpointModel
```
