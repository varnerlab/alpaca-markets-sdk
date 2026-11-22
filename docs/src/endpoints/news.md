# News and other market data

These models read news articles, the screener, corporate actions, company logos, and fixed income prices. A paper account without a market data subscription cannot read logos or fixed income prices. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyNewsEndpointModel`](@ref) | News articles, newest first |
| [`MyMostActivesEndpointModel`](@ref) | The most active stocks, by volume or by number of trades |
| [`MyMoversEndpointModel`](@ref) | The stocks or crypto pairs with the largest gains and losses |
| [`MyCorporateActionsEndpointModel`](@ref) | Dividends, splits, mergers, and other corporate actions |
| [`MyLogoEndpointModel`](@ref) | The logo of a company, as a PNG image |
| [`MyFixedIncomeLatestPricesEndpointModel`](@ref) | The latest prices of bonds, by ISIN |
| [`MyFixedIncomeLatestQuotesEndpointModel`](@ref) | The latest quotes of bonds, by ISIN |

```@docs
MyNewsEndpointModel
MyMostActivesEndpointModel
MyMoversEndpointModel
MyCorporateActionsEndpointModel
MyLogoEndpointModel
MyFixedIncomeLatestPricesEndpointModel
MyFixedIncomeLatestQuotesEndpointModel
```
