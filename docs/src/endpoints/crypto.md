# Crypto data

These models read the prices of crypto pairs, such as `"BTC/USD"`. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyCryptoBarsEndpointModel`](@ref) | Price bars over a range of times |
| [`MyCryptoQuotesEndpointModel`](@ref) | Quotes over a range of times |
| [`MyCryptoTradesEndpointModel`](@ref) | Trades over a range of times |
| [`MyCryptoLatestBarsEndpointModel`](@ref) | The latest bar of each pair |
| [`MyCryptoLatestQuotesEndpointModel`](@ref) | The latest quote of each pair |
| [`MyCryptoLatestTradesEndpointModel`](@ref) | The latest trade of each pair |
| [`MyCryptoLatestOrderbooksEndpointModel`](@ref) | The bids and asks of each pair's order book |
| [`MyCryptoSnapshotsEndpointModel`](@ref) | The latest trade, quote, and bars of each pair |

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
