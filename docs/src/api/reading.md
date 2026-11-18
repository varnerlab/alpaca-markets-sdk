# Reading data

Reading has two steps. [`url`](@ref) builds the request URL from a read model, and [`api`](@ref) sends the request, follows `next_page_token` until the last page, and returns the result of the handler.

```julia
using Alpaca
using Dates

client = load_client()

model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = Date(2025, 1, 1), finish = Date(2025, 6, 30))
url(client, model)           # the URL of the first page
bars = api(client, model)    # a DataFrame with every page
```

## The default result

The default handler of every read model returns a `DataFrame`. An endpoint that returns one record, such as the account, the clock, one asset, one order, one position, or one contract, returns a `DataFrame` with one row.

A missing value is `missing` in a column. Timestamps are `DateTime` in UTC, and prices and sizes are `Float64`. The columns of a bars table are `timestamp`, `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`. A snapshots table has one row for each contract, and the nested objects (the latest quote, the latest trade, and the greeks) are columns with a prefix.

`MyAssetsEndpointModel` has no `tradable_only` field, because `tradable_only` is not an Alpaca query parameter. To keep only the tradable assets, filter the `tradable` column of the `DataFrame`.

## Custom handlers

The `handler` keyword of `api` replaces the default handler. A handler is a function of the model type and the response body as a `String`: `handler(Type, body)`. A handler sees only the response, so any step that needs a value from the request happens after `api` returns.

## Functions

```@docs
url
api
```
