module Alpaca

using HTTP
using JSON3
using TOML
using URIs
using Dates
import DataFrames: DataFrame, Not, select!, rename!, insertcols!

include("Types.jl")
include("Utility.jl")
include("Network.jl")
include("Factory.jl")
include("Handler.jl")
include("Trading.jl")
include("streaming.jl")
include("Legacy.jl")

# Client
export AlpacaClient, load_client

# Verbs (`close` is a method of `Base.close`, so it is not exported)
export url, api, submit, cancel, roll

# Abstract types
export AbstractAlpacaEndpointModel, AbstractAlpacaTradingEndpointModel,
       AbstractAlpacaStockDataEndpointModel, AbstractAlpacaOptionDataEndpointModel,
       AbstractAlpacaOrderModel, AbstractAlpacaCryptoDataEndpointModel,
       AbstractAlpacaGlobalStockDataEndpointModel, AbstractAlpacaMarketDataEndpointModel

# Read models
export MyAccountEndpointModel, MyClockEndpointModel,
       MyPositionsEndpointModel, MyCalendarEndpointModel,
       MyAssetsEndpointModel, MyAssetEndpointModel,
       MyPositionEndpointModel, MyOrdersEndpointModel,
       MyOrderEndpointModel, MyOptionContractsEndpointModel,
       MyOptionContractEndpointModel, MyStockBarsEndpointModel,
       MyStockQuotesEndpointModel, MyStockTradesEndpointModel,
       MyStockLatestBarEndpointModel, MyStockLatestQuoteEndpointModel,
       MyStockLatestTradeEndpointModel, MyStockSnapshotsEndpointModel,
       MyOptionBarsEndpointModel,
       MyOptionTradesEndpointModel,
       MyOptionLatestQuoteEndpointModel, MyOptionLatestTradeEndpointModel,
       MyOptionSnapshotsEndpointModel, MyOptionChainEndpointModel,
       MyAccountConfigurationsEndpointModel, MyAccountActivitiesEndpointModel,
       MyPortfolioHistoryEndpointModel, MyMarketCalendarEndpointModel,
       MyMarketClocksEndpointModel

# Order models
export MyEquityOrderModel, MyOptionLegModel, MyMixedOrderModel

# Errors and the order returned by the trading verbs
export AlpacaError, AlpacaSequenceError, Order

# Streaming
export AlpacaStream, connect_market_stream,
       subscribe!, unsubscribe!,
       on_trade, on_quote, on_bar,
       start!, stop!, isrunning

# Legacy functions (deprecated, see the Legacy API page)
export get_account, get_clock, get_calendar,
       list_assets, get_asset,
       submit_order, submit_multileg_order,
       list_orders, get_order, cancel_order, cancel_all_orders,
       list_positions, get_position, close_position, close_all_positions,
       get_bars, get_quotes, get_trades, get_snapshot, get_latest_bar,
       get_latest_quote, get_latest_trade,
       download_bars, write_bars_csv, read_bars_csv,
       list_option_contracts, get_option_contract,
       get_option_bars, get_option_trades,
       get_latest_option_quote, get_latest_option_trade,
       get_option_snapshots, get_option_chain_snapshot

# Legacy types
export Account, OrderLeg, Position, Asset, Bar, Quote, Trade, MarketClock,
       CalendarDay, OptionContract, OptionGreeks, OptionSnapshot

end # module
