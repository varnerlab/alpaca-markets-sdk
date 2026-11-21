# Alpaca.jl

[![Stable Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://varnerlab.github.io/alpaca-markets-sdk/stable/)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://varnerlab.github.io/alpaca-markets-sdk/dev/)
[![CI](https://github.com/varnerlab/alpaca-markets-sdk/actions/workflows/CI.yml/badge.svg)](https://github.com/varnerlab/alpaca-markets-sdk/actions/workflows/CI.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A Julia SDK for the [Alpaca Markets](https://alpaca.markets/) trading API, targeting **paper trading** workflows such as historical data acquisition, order management, and portfolio analysis.

## Installation

The package is not yet registered in the Julia General registry. Install directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/varnerlab/alpaca-markets-sdk.git")
```

## Quick start

### 1. Configure credentials

Create a TOML configuration file (default path: `conf/apidata.toml`):

```toml
[Credentials]
# Paper: https://paper-api.alpaca.markets/v2
# Live:  https://api.alpaca.markets/v2
endpoint = "https://paper-api.alpaca.markets/v2"
key      = "YOUR_ALPACA_KEY_ID"
secret   = "YOUR_ALPACA_SECRET_KEY"
```

A starter template lives at `conf/apidata.example.toml`. Multiple credentials
can live in one file under different section names — pass `section=` to pick
one (e.g. `load_client("creds.toml"; section = "paper_research")`).

### 2. Read data

Each read endpoint has a model. `url` builds the request URL from the model, and `api` sends the request and returns a `DataFrame` that holds every page of the response.

```julia
using Alpaca
using Dates

client = load_client("conf/apidata.toml")
# Or with no argument: load_client() reads conf/apidata.toml by default.

# The daily bars of two stocks
model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = Date(2025, 1, 1), finish = Date(2025, 6, 30))
url(client, model)           # the URL of the first page, for inspection
bars = api(client, model)    # a DataFrame with one row for each bar
```

### 3. Trade a vertical spread

An order model says what to trade. The verb says what to do with the order: `submit` opens each leg, `close` reverses each leg, and `roll` closes the old legs and opens the new legs in one order.

```julia
# A bull put spread: short the 540 put, long the 530 put
short_put = MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell")
long_put  = MyOptionLegModel(symbol = "SPY261218P00530000", side = "buy")
spread    = [short_put, long_put]

# Open two units of the spread for a net credit of 1.25 per unit
order = submit(client, spread; qty = 2, limit_price = -1.25)

# Close the spread for a net debit of 0.80 per unit
closing_order = close(client, spread; qty = 2, limit_price = 0.80)

# Or roll the spread to a later expiration for a net credit of 0.40 per unit
later_spread = [MyOptionLegModel(symbol = "SPY270115P00540000", side = "sell"),
                MyOptionLegModel(symbol = "SPY270115P00530000", side = "buy")]
rolling_order = roll(client, spread, later_spread; qty = 2, limit_price = -0.40)
```

### 4. Trade a covered call

Alpaca cannot fill shares and options in one order, so `MyMixedOrderModel` sends two orders in sequence. `submit` buys the shares, waits until the equity order fills, and then sells the call. `close` buys back the call, waits until the option order fills, and then sells the shares.

```julia
covered_call = MyMixedOrderModel(
    equity  = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
    options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])

orders = submit(client, covered_call; limit_price = 0.35)   # the equity order, then the option order
orders = close(client, covered_call; limit_price = 0.10)    # the option order, then the equity order
```

The deprecated functions of earlier versions, such as `get_account` and `submit_order`, still work, and the Legacy API page of the documentation lists the replacement for each function.

## Features

| Area | Functions and models |
|------|----------------------|
| **Client** | `AlpacaClient`, `load_client` |
| **Reading** | `url`, `api` |
| **Trading** | `submit`, `cancel`, `close`, `roll` |
| **Order models** | `MyEquityOrderModel`, `MyCryptoOrderModel`, `MyOptionLegModel`, `MyMixedOrderModel` |
| **Trading read models** | `MyAccountEndpointModel`, `MyClockEndpointModel`, `MyCalendarEndpointModel`, `MyAssetsEndpointModel`, `MyAssetEndpointModel`, `MyPositionsEndpointModel`, `MyPositionEndpointModel`, `MyOrdersEndpointModel`, `MyOrderEndpointModel` |
| **Stock data read models** | `MyStockBarsEndpointModel`, `MyStockQuotesEndpointModel`, `MyStockTradesEndpointModel`, `MyStockLatestBarEndpointModel`, `MyStockLatestQuoteEndpointModel`, `MyStockLatestTradeEndpointModel`, `MyStockSnapshotsEndpointModel` |
| **Option read models** | `MyOptionContractsEndpointModel`, `MyOptionContractEndpointModel`, `MyOptionBarsEndpointModel`, `MyOptionTradesEndpointModel`, `MyOptionLatestQuoteEndpointModel`, `MyOptionLatestTradeEndpointModel`, `MyOptionSnapshotsEndpointModel`, `MyOptionChainEndpointModel` |
| **Streaming** | `connect_market_stream`, `subscribe!`, `unsubscribe!`, `on_trade`, `on_quote`, `on_bar`, `start!`, `stop!`, `isrunning` |
| **Errors** | `AlpacaError`, `AlpacaSequenceError` |

## What the SDK covers

- Account and settings: the account, its configuration, activities, and portfolio history.
- Orders, including bracket, OCO, and OTO orders, crypto orders, and replacing an order.
- Positions, closing positions, and exercising options.
- Watchlists: create, read, update, and delete.
- The market calendar and the market clocks.
- US stock data: bars, quotes, trades, auctions, snapshots, conditions, and exchanges.
- Non-US stock data: bars, quotes, trades, and snapshots.
- Option data: bars, trades, quotes, snapshots, chains, conditions, and exchanges.
- Crypto data: bars, quotes, trades, snapshots, and order books.
- News.
- The screener: most active stocks and market movers.
- Corporate actions.
- Logos and fixed income prices and quotes, which need a paid market-data subscription.

## Requirements

- Julia **1.10+**
- An [Alpaca](https://alpaca.markets/) paper-trading account (API key and secret)

## License

[MIT](LICENSE) -- Copyright (c) 2026 Jeffrey D Varner
