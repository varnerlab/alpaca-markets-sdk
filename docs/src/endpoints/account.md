# Account

These models read the paper account, change its settings, and read its history. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyAccountEndpointModel`](@ref) | The cash, buying power, and equity of the account |
| [`MyAccountConfigurationsEndpointModel`](@ref) | The settings of the account |
| [`MyUpdateAccountConfigurationsEndpointModel`](@ref) | Changes one or more settings |
| [`MyAccountActivitiesEndpointModel`](@ref) | The fills, dividends, and other activities of the account |
| [`MyPortfolioHistoryEndpointModel`](@ref) | The equity and the profit or loss of the account over time |

```@docs
MyAccountEndpointModel
MyAccountConfigurationsEndpointModel
MyUpdateAccountConfigurationsEndpointModel
MyAccountActivitiesEndpointModel
MyPortfolioHistoryEndpointModel
```
