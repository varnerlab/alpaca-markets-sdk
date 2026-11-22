# Reading data

Every Alpaca endpoint has a model type, and a model holds the settings of one request. The call [`api`](@ref) sends the request and returns the result. The call [`url`](@ref) returns the URL of the request without sending it, so you can check a request before you send it.

```julia
using Alpaca
using Dates

client = load_client()

model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
    start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
url(client, model)           # the URL of the first page
bars = api(client, model);   # a DataFrame with every page
```

## Model fields

Each keyword that sets a query parameter has the name of that Alpaca query parameter. The one exception is `finish`, which sets `end`, because `end` is a reserved word in Julia.

## The result

The call `api` returns a `DataFrame`. An endpoint that returns one record, such as the account or one order, gives a `DataFrame` with one row. The docstring of each model lists the columns of its result.

A value that Alpaca does not send is `missing`. Timestamps are `DateTime` values in UTC, and prices and sizes are `Float64`. The tables of account activities, account settings, corporate actions, and fixed income keep the values as Alpaca sends them, so some prices and sizes in those tables are text.

## Pages

Alpaca splits a long result into pages. For the historical bars, quotes, trades, and auctions, the option contracts and chains, and the corporate actions, the call `api` reads every page and returns one `DataFrame`. Pass `max_pages` to stop after that many pages. A `DataFrame` that `max_pages` cut short carries the token of the next page in its metadata, under `"next_page_token"`:

```julia
using DataFrames

model = MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Min",
    start = Date(2026, 11, 20), limit = 100);
bars = api(client, model; max_pages = 1);    # the first 100 bars
metadata(bars, "next_page_token", nothing)   # the token of the next page, or nothing
```

## Writes

The write models, such as `MyCreateWatchlistEndpointModel` and `MyReplaceOrderEndpointModel`, also go through `api`. The call sends each write once and never reads more pages. A write that Alpaca answers with no body, such as `MyDeleteWatchlistEndpointModel`, returns an empty `DataFrame`.

## Custom handlers

The `handler` keyword of `api` replaces the default handler. A handler is a function of the model type and the response body as a `String`, `handler(Type, body)`, and `api` returns what the handler returns.

## Functions

```@docs
url
api
```
