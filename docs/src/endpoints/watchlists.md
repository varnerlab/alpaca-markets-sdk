# Watchlists

A watchlist is a named list of symbols that the account keeps. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyWatchlistsEndpointModel`](@ref) | Every watchlist of the account |
| [`MyWatchlistEndpointModel`](@ref) | One watchlist and its assets, by id or name |
| [`MyCreateWatchlistEndpointModel`](@ref) | Creates a watchlist |
| [`MyUpdateWatchlistEndpointModel`](@ref) | Renames a watchlist or replaces its symbols |
| [`MyAddWatchlistAssetEndpointModel`](@ref) | Adds one symbol to a watchlist |
| [`MyRemoveWatchlistAssetEndpointModel`](@ref) | Removes one symbol from a watchlist |
| [`MyDeleteWatchlistEndpointModel`](@ref) | Deletes a watchlist |

```@docs
MyWatchlistsEndpointModel
MyWatchlistEndpointModel
MyCreateWatchlistEndpointModel
MyUpdateWatchlistEndpointModel
MyAddWatchlistAssetEndpointModel
MyRemoveWatchlistAssetEndpointModel
MyDeleteWatchlistEndpointModel
```
