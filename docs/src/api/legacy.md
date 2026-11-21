# Legacy API

These functions and types come from versions before 0.4.0. Every legacy function sends the same request and returns the same value as before, and each call prints a deprecation warning when Julia runs with `--depwarn=yes`. Under `--depwarn=error`, every legacy call becomes an error, which finds the legacy calls that remain in your code.

| Legacy call | Replacement |
|---|---|
| `get_account(client)` | `api(client, MyAccountEndpointModel())` |
| `get_clock(client)` | `api(client, MyClockEndpointModel())` |
| `get_calendar(client; start, finish)` | `api(client, MyCalendarEndpointModel(start = ..., finish = ...))` |
| `list_assets(client; ...)` | `api(client, MyAssetsEndpointModel(...))` |
| `get_asset(client, symbol)` | `api(client, MyAssetEndpointModel(symbol = ...))` |
| `list_positions(client)` | `api(client, MyPositionsEndpointModel())` |
| `get_position(client, symbol)` | `api(client, MyPositionEndpointModel(symbol = ...))` |
| `close_position(client, symbol; qty, percentage)` | `close(client, symbol; qty, percentage)` |
| `close_all_positions(client; cancel_orders)` | `close(client; all = true, cancel_orders)` |
| `list_orders(client; ...)` | `api(client, MyOrdersEndpointModel(...))` |
| `get_order(client, id; by_client_order_id)` | `api(client, MyOrderEndpointModel(...))` |
| `submit_order(client, symbol, qty, side; ...)` | `submit(client, MyEquityOrderModel(...); ...)`, or `submit(client, MyOptionLegModel(...); ...)` for an option symbol |
| `submit_multileg_order(client, legs; ...)` | `submit`, `close`, or `roll` with `MyOptionLegModel` legs |
| `cancel_order(client, id)` | `cancel(client, id)` |
| `cancel_all_orders(client)` | `cancel(client; all = true)` |
| `get_bars`, `get_quotes`, `get_trades` | `api` with `MyStockBarsEndpointModel`, `MyStockQuotesEndpointModel`, `MyStockTradesEndpointModel` |
| `get_latest_bar`, `get_latest_quote`, `get_latest_trade` | `api` with the `MyStockLatest*EndpointModel` types |
| `get_snapshot` | `api(client, MyStockSnapshotsEndpointModel(...))` |
| `download_bars` | `api(client, MyStockBarsEndpointModel(...))`, which follows every page |
| `write_bars_csv`, `read_bars_csv` | No replacement. Write the bars `DataFrame` with a CSV package |
| `list_option_contracts`, `get_option_contract` | `api` with `MyOptionContractsEndpointModel`, `MyOptionContractEndpointModel` |
| `get_option_bars`, `get_option_trades` | `api` with `MyOptionBarsEndpointModel`, `MyOptionTradesEndpointModel` |
| `get_latest_option_quote`, `get_latest_option_trade` | `api` with the `MyOptionLatestQuoteEndpointModel` and `MyOptionLatestTradeEndpointModel` types |
| `get_option_snapshots` | `api(client, MyOptionSnapshotsEndpointModel(...))` |
| `get_option_chain_snapshot` | `api(client, MyOptionChainEndpointModel(...))` |
| `OrderLeg(...)` | `MyOptionLegModel(...)` |

## Account and clock

```@docs
get_account
get_clock
get_calendar
```

## Assets

```@docs
list_assets
get_asset
```

## Positions

```@docs
list_positions
get_position
close_position
close_all_positions
```

## Orders

```@docs
submit_order
submit_multileg_order
list_orders
get_order
cancel_order
cancel_all_orders
```

## Market data

```@docs
get_bars
get_quotes
get_trades
get_snapshot
get_latest_bar
get_latest_quote
get_latest_trade
```

## Historical downloads

```@docs
download_bars
write_bars_csv
read_bars_csv
```

## Options

```@docs
list_option_contracts
get_option_contract
get_option_bars
get_option_trades
get_latest_option_quote
get_latest_option_trade
get_option_snapshots
get_option_chain_snapshot
```

## Legacy types

The deprecated market data functions also return [`Bar`](@ref), [`Quote`](@ref), and [`Trade`](@ref), which the Streaming page documents.

```@docs
Account
Asset
Position
MarketClock
CalendarDay
OptionContract
OptionGreeks
OptionSnapshot
OrderLeg
```
