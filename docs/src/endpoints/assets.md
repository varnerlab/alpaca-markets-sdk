# Assets and option contracts

These models read what the account can trade: stocks, ETFs, and crypto pairs, and the option contracts on a stock. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyAssetsEndpointModel`](@ref) | Every asset of one class, such as every US stock |
| [`MyAssetEndpointModel`](@ref) | One asset, by symbol |
| [`MyOptionContractsEndpointModel`](@ref) | The option contracts on one or more underlying symbols |
| [`MyOptionContractEndpointModel`](@ref) | One option contract, by symbol |

```@docs
MyAssetsEndpointModel
MyAssetEndpointModel
MyOptionContractsEndpointModel
MyOptionContractEndpointModel
```
