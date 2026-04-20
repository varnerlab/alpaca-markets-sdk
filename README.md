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

A starter template lives at `conf/apiidata.example.toml`. Multiple credentials
can live in one file under different section names — pass `section=` to pick
one (e.g. `load_client("creds.toml"; section = "paper_research")`).

### 2. Connect and query

```julia
using Alpaca

client = load_client("conf/apidata.toml")
# Or with no argument: load_client() reads conf/apidata.toml by default.

# Account info
acct = get_account(client)

# Market clock
clk = get_clock(client)

# Historical bars (timeframe is positional)
bars = get_bars(client, "AAPL", "1Day"; start = "2025-01-01", limit = 100)

# Submit a paper order (symbol, qty, side are positional)
order = submit_order(client, "AAPL", 1, "buy";
                     type = "market", time_in_force = "day")
```

## Features

| Area | Functions |
|------|-----------|
| **Account** | `get_account`, `get_clock`, `get_calendar` |
| **Assets** | `list_assets`, `get_asset` |
| **Orders** | `submit_order`, `list_orders`, `get_order`, `cancel_order`, `cancel_all_orders` |
| **Positions** | `list_positions`, `get_position`, `close_position`, `close_all_positions` |
| **Market data** | `get_bars`, `get_quotes`, `get_trades`, `get_snapshot`, `get_latest_bar`, `get_latest_quote`, `get_latest_trade` |
| **Historical helpers** | `download_bars`, `write_bars_csv`, `read_bars_csv` |
| **Options** | `list_option_contracts`, `get_option_contract`, `get_option_bars`, `get_option_trades`, `get_option_quotes`, `get_latest_option_bar`, `get_latest_option_quote`, `get_latest_option_trade`, `get_option_snapshots`, `get_option_chain_snapshot` |

## Requirements

- Julia **1.10+**
- An [Alpaca](https://alpaca.markets/) paper-trading account (API key and secret)

## License

[MIT](LICENSE) -- Copyright (c) 2026 Jeffrey D Varner
