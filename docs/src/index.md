# Alpaca.jl

A Julia client for the [Alpaca Markets](https://alpaca.markets) REST API, focused on paper trading US equities, ETFs, and options, plus access to historical and latest market data.

## Features

- Credentials loaded from a local TOML file (no environment variables required)
- Reading: one model for each endpoint, `url` to build the request URL, and `api` to send the request and return a `DataFrame`
- Trading: `submit`, `cancel`, `close`, and `roll` for equities, option legs, vertical spreads, and covered calls
- Real-time streaming of trades, quotes, and bars through a WebSocket with automatic reconnection
- Automatic pagination for market data queries
- The exceptions `AlpacaError` for a non-2xx API response and `AlpacaSequenceError` for a two-order sequence that stops after the first order

## Quick example

```julia
using Alpaca
using Dates

client = load_client()                 # reads conf/apidata.toml

# read the daily bars of two stocks
model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = today() - Day(30))
bars = api(client, model)

# buy one share of SPY at market
order = submit(client, MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 1))
```

See [Getting Started](getting_started.md) for installation and credential setup. The API Reference pages in the sidebar document every exported function and type. The functions of versions before 0.4.0 are deprecated and listed on the [Legacy API](api/legacy.md) page, with the replacement for each function.

## Disclaimer

This package is independent and not affiliated with Alpaca Securities LLC. It is intended for paper trading, research, and algorithm development. Review any strategy carefully before running it against a live account.
