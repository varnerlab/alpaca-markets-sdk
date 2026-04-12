# Alpaca.jl

A thin Julia client for the [Alpaca Markets](https://alpaca.markets) REST API,
focused on paper-trading US equities and ETFs, plus access to historical and
latest market data.

## Features

- Credentials loaded from a local TOML file (no env vars required)
- Trading: account, clock/calendar, assets, orders, positions
- Market data: bars, quotes, trades, snapshots, and latest-* endpoints
- Real-time streaming: trades, quotes, and bars via WebSocket with auto-reconnect
- Automatic pagination for historical market data queries
- Typed return values (`Account`, `Order`, `Position`, `Bar`, `Quote`, ...) plus
  access to the raw `JSON3` payload when you need fields that aren't surfaced
- Single exception type `AlpacaError` for non-2xx API responses

## Quick example

```julia
using Alpaca
using Dates

client = load_client()                 # reads conf/apidata.toml

acct = get_account(client)
@show acct.cash acct.buying_power

order = submit_order(client, "SPY", 10, "buy";
                     type = "market", time_in_force = "day")

bars = get_bars(client, ["AAPL", "MSFT"], "1Day";
                start = today() - Day(30))
```

See [Getting Started](getting_started.md) for installation and credential setup,
and the API Reference pages in the sidebar for every exported function and
type.

## Disclaimer

This package is independent and not affiliated with Alpaca Securities LLC.
It is intended for paper-trading, research, and algorithm development. Review
any strategy carefully before running it against a live account.
