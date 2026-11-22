# Alpaca.jl

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://varnerlab.github.io/alpaca-markets-sdk/dev/)
[![CI](https://github.com/varnerlab/alpaca-markets-sdk/actions/workflows/CI.yml/badge.svg)](https://github.com/varnerlab/alpaca-markets-sdk/actions/workflows/CI.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Alpaca.jl is a Julia package for the trading and market data APIs of [Alpaca](https://alpaca.markets). With an Alpaca paper account, it reads market data and places orders with simulated money at real market prices.

Every Alpaca endpoint has a model type in this package. A model holds the settings of one request, and the call `api(client, model)` sends the request and returns the result as a `DataFrame`. The trading verbs `submit`, `cancel`, and `close` place and manage orders.

## Install

The package needs Julia 1.10 or later.

```julia
using Pkg
Pkg.add(url = "https://github.com/varnerlab/alpaca-markets-sdk.git")
```

## Quick start

Generate a pair of paper keys in the API Keys panel of the [Alpaca dashboard](https://app.alpaca.markets), and save them in `conf/apidata.toml` in your project folder. Add that file to your `.gitignore` file, so that git never commits your keys.

```toml
[Credentials]
endpoint = "https://paper-api.alpaca.markets/v2"
key      = "YOUR_PAPER_KEY_ID"
secret   = "YOUR_PAPER_SECRET_KEY"
```

Read the account and the daily bars of two stocks, then place a buy limit order far below the price of SPY and cancel it:

```julia
using Alpaca
using Dates

client = load_client();     # reads conf/apidata.toml
account = api(client, MyAccountEndpointModel());

model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
    start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
bars = api(client, model);

order = submit(client, MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 1);
    type = "limit", limit_price = 500.0);
cancel(client, order);
```

## Documentation

The [documentation](https://varnerlab.github.io/alpaca-markets-sdk/dev/) has a Getting Started page and one page for each group of endpoints, with the fields, the result columns, and an example for every model:

- [Account](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/account/): the account, its settings, its activities, and its portfolio history.
- [Clock and calendars](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/calendar/): market hours and trading days.
- [Assets and option contracts](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/assets/): what the account can trade.
- [Orders and positions](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/orders/): stock, crypto, and option orders, including spreads and covered calls.
- [Watchlists](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/watchlists/).
- [Stock data](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/stocks/), [option data](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/options/), and [crypto data](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/crypto/): bars, quotes, trades, and snapshots.
- [News and other market data](https://varnerlab.github.io/alpaca-markets-sdk/dev/endpoints/news/): news, the screener, corporate actions, logos, and fixed income.

The functions of versions before 0.4.0, such as `get_account`, still work, and the [Legacy API](https://varnerlab.github.io/alpaca-markets-sdk/dev/api/legacy/) page lists the replacement for each one.

## License

[MIT](LICENSE). Copyright (c) 2026 Jeffrey D Varner. This package is not affiliated with Alpaca Securities LLC.
