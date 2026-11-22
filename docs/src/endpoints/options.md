# Option data

These models read the prices of option contracts. To find the contracts on a stock, use the models on the [Assets and option contracts](assets.md) page. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyOptionBarsEndpointModel`](@ref) | Price bars over a range of times |
| [`MyOptionTradesEndpointModel`](@ref) | Trades over a range of times |
| [`MyOptionLatestQuoteEndpointModel`](@ref) | The latest quote of each contract |
| [`MyOptionLatestTradeEndpointModel`](@ref) | The latest trade of each contract |
| [`MyOptionSnapshotsEndpointModel`](@ref) | The latest trade, quote, bars, implied volatility, and greeks of each contract |
| [`MyOptionChainEndpointModel`](@ref) | The snapshots of every contract on one underlying symbol |
| [`MyOptionExchangesEndpointModel`](@ref) | The name of each option exchange code |
| [`MyOptionConditionsEndpointModel`](@ref) | The meaning of each trade or quote condition code |

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
