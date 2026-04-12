module Alpaca

using HTTP
using JSON3
using TOML
using URIs
using Dates

include("types.jl")
include("client.jl")
include("account.jl")
include("clock.jl")
include("assets.jl")
include("orders.jl")
include("positions.jl")
include("marketdata.jl")
include("historical.jl")
include("options.jl")
include("streaming.jl")

# Client
export AlpacaClient, load_client

# Account / clock
export get_account, get_clock, get_calendar

# Assets
export list_assets, get_asset

# Orders
export submit_order, list_orders, get_order, cancel_order, cancel_all_orders

# Positions
export list_positions, get_position, close_position, close_all_positions

# Market data
export get_bars, get_quotes, get_trades, get_snapshot, get_latest_bar,
       get_latest_quote, get_latest_trade

# Historical download helpers
export download_bars, write_bars_csv, read_bars_csv

# Options
export list_option_contracts, get_option_contract,
       get_option_bars, get_option_trades, get_option_quotes,
       get_latest_option_bar, get_latest_option_quote, get_latest_option_trade,
       get_option_snapshots, get_option_chain_snapshot

# Streaming
export AlpacaStream, connect_market_stream,
       subscribe!, unsubscribe!,
       on_trade, on_quote, on_bar,
       start!, stop!, isrunning

# Types
export Account, Order, Position, Asset, Bar, Quote, Trade, MarketClock,
       CalendarDay, AlpacaError,
       OptionContract, OptionGreeks, OptionSnapshot

end # module
