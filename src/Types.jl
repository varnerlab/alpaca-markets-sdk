"""
    AbstractAlpacaEndpointModel

Supertype of every endpoint model. An endpoint model describes one Alpaca REST request.
"""
abstract type AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaTradingEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the trading API.
"""
abstract type AbstractAlpacaTradingEndpointModel <: AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaStockDataEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the stock market data API.
"""
abstract type AbstractAlpacaStockDataEndpointModel <: AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaOptionDataEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the options market data API.
"""
abstract type AbstractAlpacaOptionDataEndpointModel <: AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaOrderModel

Supertype of the order models that describe an order to submit.
"""
abstract type AbstractAlpacaOrderModel end

"""
    AlpacaClient(trading_url, data_url, [options_data_url,] key_id, secret_key)

Holds credentials and base URLs for the Alpaca REST APIs. Usually
constructed via [`load_client`](@ref) from a TOML config file.

Fields:

- `trading_url` — trading API base, e.g. `https://paper-api.alpaca.markets/v2`
- `data_url` — stock market data base, e.g. `https://data.alpaca.markets/v2`
- `options_data_url` — options market data base, e.g. `https://data.alpaca.markets/v1beta1`
- `key_id`, `secret_key` — Alpaca API credentials

The four-argument constructor `AlpacaClient(trading_url, data_url, key_id, secret_key)`
is preserved for convenience and derives `options_data_url` from `data_url`
automatically.
"""
struct AlpacaClient
    trading_url::String
    data_url::String
    options_data_url::String
    key_id::String
    secret_key::String
end

# Four-arg convenience constructor (backwards compatible).
AlpacaClient(trading_url::AbstractString, data_url::AbstractString,
             key_id::AbstractString, secret_key::AbstractString) =
    AlpacaClient(trading_url, data_url,
                 _derive_options_url(data_url),
                 key_id, secret_key)

"""
    AlpacaError(status, code, message, body)

Raised when the Alpaca REST API returns a non-2xx response. `status` is the
HTTP status code, `code` is Alpaca's internal numeric error code (when the
body parses as JSON with a `code` field, otherwise `nothing`), `message` is
the decoded error message, and `body` is the raw response body for debugging.
"""
struct AlpacaError <: Exception
    status::Int
    code::Union{Int,Nothing}
    message::String
    body::String
end

Base.showerror(io::IO, e::AlpacaError) =
    print(io, "AlpacaError(status=$(e.status), code=$(e.code)): $(e.message)")

"""
    Account

Summary of the authenticated trading account. Returned by [`get_account`](@ref).

Selected fields:

- `id`, `account_number`, `status`, `currency`
- `cash`, `buying_power`, `portfolio_value`, `equity`, `last_equity`
- `pattern_day_trader`, `trading_blocked`, `transfers_blocked`, `account_blocked`
- `raw` — the original `JSON3.Object` payload for fields not surfaced explicitly
"""
struct Account
    id::String
    account_number::String
    status::String
    currency::String
    cash::Float64
    buying_power::Float64
    portfolio_value::Float64
    equity::Float64
    last_equity::Float64
    pattern_day_trader::Bool
    trading_blocked::Bool
    transfers_blocked::Bool
    account_blocked::Bool
    raw::JSON3.Object
end

"""
    Asset

A tradable (or historically tradable) instrument on Alpaca. Returned by
[`list_assets`](@ref) and [`get_asset`](@ref).

Selected fields:

- `id`, `symbol`, `name`, `class`, `exchange`, `status`
- `tradable`, `marginable`, `shortable`, `easy_to_borrow`, `fractionable`
- `raw` — the original `JSON3.Object` payload
"""
struct Asset
    id::String
    class::String
    exchange::String
    symbol::String
    name::String
    status::String
    tradable::Bool
    marginable::Bool
    shortable::Bool
    easy_to_borrow::Bool
    fractionable::Bool
    raw::JSON3.Object
end

"""
    Order

A trading order. Returned by [`submit_order`](@ref), [`submit_multileg_order`](@ref),
[`get_order`](@ref), and [`list_orders`](@ref).

Selected fields:

- `id`, `client_order_id`
- `symbol` — `String` for single-leg orders; `nothing` for multi-leg parent orders
  (Alpaca returns no top-level symbol on an `mleg` parent — each leg has its own)
- `asset_class`
- `side` (`"buy"` or `"sell"`) — `nothing` for multi-leg parents (lives on each leg)
- `type`, `time_in_force`, `status`
- `order_class` — `""` for simple orders; `"mleg"`, `"bracket"`, `"oco"`, `"oto"` for compound orders
- `position_intent` — `"buy_to_open"` / `"sell_to_open"` / `"buy_to_close"` / `"sell_to_close"`
  on option legs; `nothing` otherwise
- `qty`, `filled_qty`, `limit_price`, `stop_price`, `filled_avg_price`
- `created_at`, `submitted_at`, `filled_at` (all `DateTime` in UTC, may be `nothing`)
- `legs` — `Vector{Order}` of child legs on a multi-leg parent; `nothing` otherwise
- `raw` — the original `JSON3.Object` payload
"""
struct Order
    id::String
    client_order_id::String
    symbol::Union{String,Nothing}
    asset_class::String
    side::Union{String,Nothing}
    type::String
    time_in_force::String
    order_class::String
    position_intent::Union{String,Nothing}
    qty::Union{Float64,Nothing}
    filled_qty::Float64
    limit_price::Union{Float64,Nothing}
    stop_price::Union{Float64,Nothing}
    filled_avg_price::Union{Float64,Nothing}
    status::String
    created_at::Union{DateTime,Nothing}
    submitted_at::Union{DateTime,Nothing}
    filled_at::Union{DateTime,Nothing}
    legs::Union{Vector{Order},Nothing}
    raw::JSON3.Object
end

"""
    OrderLeg(symbol, ratio_qty, side, position_intent)

Input descriptor for one leg of a multi-leg option order. Pass a
`Vector{OrderLeg}` to [`submit_multileg_order`](@ref).

Fields:

- `symbol` — OCC option symbol (e.g. `"SPY250620P00420000"`)
- `ratio_qty` — number of contracts per spread unit (typically `1`)
- `side` — `"buy"` or `"sell"`
- `position_intent` — `"buy_to_open"`, `"sell_to_open"`, `"buy_to_close"`,
  or `"sell_to_close"`
"""
struct OrderLeg
    symbol::String
    ratio_qty::Int
    side::String
    position_intent::String
end

"""
    Position

An open position in the account. Returned by [`list_positions`](@ref) and
[`get_position`](@ref).

Selected fields:

- `symbol`, `asset_id`, `exchange`, `asset_class`, `side` (`"long"` / `"short"`)
- `qty`, `avg_entry_price`, `current_price`, `lastday_price`
- `market_value`, `cost_basis`, `unrealized_pl`, `unrealized_plpc`, `change_today`
- `raw` — the original `JSON3.Object` payload
"""
struct Position
    asset_id::String
    symbol::String
    exchange::String
    asset_class::String
    qty::Float64
    side::String
    avg_entry_price::Float64
    market_value::Float64
    cost_basis::Float64
    unrealized_pl::Float64
    unrealized_plpc::Float64
    current_price::Float64
    lastday_price::Float64
    change_today::Float64
    raw::JSON3.Object
end

"""
    Bar

An OHLCV bar for a single symbol at a given timestamp. Returned by
[`get_bars`](@ref) and [`get_latest_bar`](@ref).

Fields:

- `symbol` — ticker
- `t` — bar start time (`DateTime`, UTC)
- `o`, `h`, `l`, `c` — open / high / low / close
- `v` — volume
- `n` — trade count (may be `nothing` depending on feed)
- `vw` — volume-weighted average price (may be `nothing` depending on feed)
"""
struct Bar
    symbol::String
    t::DateTime
    o::Float64
    h::Float64
    l::Float64
    c::Float64
    v::Float64
    n::Union{Int,Nothing}
    vw::Union{Float64,Nothing}
end

"""
    Quote

A level-1 NBBO quote. Returned by [`get_quotes`](@ref) and
[`get_latest_quote`](@ref).

Fields: `symbol`, `t`, `bid_price`, `bid_size`, `ask_price`, `ask_size`,
`bid_exchange`, `ask_exchange`.
"""
struct Quote
    symbol::String
    t::DateTime
    bid_price::Float64
    bid_size::Float64
    ask_price::Float64
    ask_size::Float64
    bid_exchange::String
    ask_exchange::String
end

"""
    Trade

A last-sale print. Returned by [`get_trades`](@ref) and [`get_latest_trade`](@ref).

Fields: `symbol`, `t`, `price`, `size`, `exchange`, `id` (exchange trade id,
may be `nothing`).
"""
struct Trade
    symbol::String
    t::DateTime
    price::Float64
    size::Float64
    exchange::String
    id::Union{Int,Nothing}
end

"""
    MarketClock

Server-side market clock snapshot returned by [`get_clock`](@ref).

Fields: `timestamp`, `is_open`, `next_open`, `next_close` (all `DateTime` UTC
except `is_open::Bool`).
"""
struct MarketClock
    timestamp::DateTime
    is_open::Bool
    next_open::DateTime
    next_close::DateTime
end

"""
    CalendarDay

A single trading session in the market calendar. Returned by
[`get_calendar`](@ref).

Fields: `date`, `open`, `close`, `session_open`, `session_close`.
The `session_*` fields include extended-hours sessions when Alpaca provides them.
"""
struct CalendarDay
    date::Date
    open::Time
    close::Time
    session_open::Union{Time,Nothing}
    session_close::Union{Time,Nothing}
end

"""
    OptionContract

Metadata for a single listed options contract. Returned by
[`list_option_contracts`](@ref) and [`get_option_contract`](@ref).

Selected fields:

- `symbol` — OCC-encoded option symbol (e.g. `"AAPL260117C00150000"`), which
  is the value you pass to `submit_order` for single-leg options trades
- `underlying_symbol`, `root_symbol`, `underlying_asset_id`
- `type` — `"call"` or `"put"`
- `style` — `"american"` or `"european"`
- `strike_price`, `expiration_date`, `multiplier`, `size`
- `tradable`, `status`
- `open_interest`, `open_interest_date`, `close_price`, `close_price_date`
- `raw` — original `JSON3.Object` payload
"""
struct OptionContract
    id::String
    symbol::String
    name::String
    status::String
    tradable::Bool
    expiration_date::Date
    root_symbol::String
    underlying_symbol::String
    underlying_asset_id::String
    type::String            # "call" or "put"
    style::String           # "american" / "european"
    strike_price::Float64
    multiplier::Float64
    size::Float64
    open_interest::Union{Float64,Nothing}
    open_interest_date::Union{Date,Nothing}
    close_price::Union{Float64,Nothing}
    close_price_date::Union{Date,Nothing}
    raw::JSON3.Object
end

"""
    OptionGreeks

The standard option greeks returned alongside a snapshot. Any field may be
`nothing` when Alpaca is unable to compute it (e.g. deep ITM / OTM with no
quote activity).

Fields: `delta`, `gamma`, `theta`, `vega`, `rho`.
"""
struct OptionGreeks
    delta::Union{Float64,Nothing}
    gamma::Union{Float64,Nothing}
    theta::Union{Float64,Nothing}
    vega::Union{Float64,Nothing}
    rho::Union{Float64,Nothing}
end

"""
    OptionSnapshot

Snapshot of a single option contract: latest trade/quote, minute bar,
implied volatility, and greeks. Returned by [`get_option_snapshots`](@ref)
and [`get_option_chain_snapshot`](@ref).

Fields:

- `symbol` — OCC-encoded option symbol
- `latest_quote`, `latest_trade` — reuse the shared [`Quote`](@ref) / [`Trade`](@ref) types
- `minute_bar`, `daily_bar`, `prev_daily_bar` — [`Bar`](@ref) values
- `implied_volatility` — as a decimal (e.g. `0.23` = 23%)
- `greeks` — an [`OptionGreeks`](@ref) value, or `nothing`
- `raw` — original `JSON3.Object` payload
"""
struct OptionSnapshot
    symbol::String
    latest_quote::Union{Quote,Nothing}
    latest_trade::Union{Trade,Nothing}
    minute_bar::Union{Bar,Nothing}
    daily_bar::Union{Bar,Nothing}
    prev_daily_bar::Union{Bar,Nothing}
    implied_volatility::Union{Float64,Nothing}
    greeks::Union{OptionGreeks,Nothing}
    raw::JSON3.Object
end

# --- Read endpoint models ----------------------------------------------------------------------------------- #

"""
    mutable struct MyAccountEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/account` endpoint.
This endpoint returns the account of the client: cash, buying power, and status.

### Fields
This model has no fields.

### Constructors
- `MyAccountEndpointModel()`: returns a new `MyAccountEndpointModel` instance.
"""
mutable struct MyAccountEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyAccountEndpointModel() = new();
end

"""
    mutable struct MyClockEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/clock` endpoint.
This endpoint returns the market clock: whether the market is open and when it next opens or closes.

### Fields
This model has no fields.

### Constructors
- `MyClockEndpointModel()`: returns a new `MyClockEndpointModel` instance.
"""
mutable struct MyClockEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyClockEndpointModel() = new();
end

"""
    mutable struct MyPositionsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/positions` endpoint.
This endpoint returns every open position of the account.

### Fields
This model has no fields.

### Constructors
- `MyPositionsEndpointModel()`: returns a new `MyPositionsEndpointModel` instance.
"""
mutable struct MyPositionsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyPositionsEndpointModel() = new();
end

"""
    mutable struct MyCalendarEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/calendar` endpoint.
This endpoint returns the market calendar: the trading days and their open and close times.

### Fields
- `start::Union{Nothing,Date,String}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,Date,String}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.

### Constructors
- `MyCalendarEndpointModel(; start::Union{Nothing,Date,String} = nothing, finish::Union{Nothing,Date,String} = nothing)`: returns a new `MyCalendarEndpointModel` instance.
"""
mutable struct MyCalendarEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    start::Union{Nothing,Date,String}
    finish::Union{Nothing,Date,String}

    # methods -
    MyCalendarEndpointModel(;
        start::Union{Nothing,Date,String} = nothing, finish::Union{Nothing,Date,String} = nothing) = new(start, finish);
end

"""
    mutable struct MyAssetsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/assets` endpoint.
This endpoint returns the assets that match a status and an asset class.

### Fields
- `status::String`: the status filter, e.g., `"open"`.
- `asset_class::String`: the asset class filter, e.g., `"us_equity"`.

### Constructors
- `MyAssetsEndpointModel(; status::String = "active", asset_class::String = "us_equity")`: returns a new `MyAssetsEndpointModel` instance.
"""
mutable struct MyAssetsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    status::String
    asset_class::String

    # methods -
    MyAssetsEndpointModel(;
        status::String = "active", asset_class::String = "us_equity") = new(status, asset_class);
end

"""
    mutable struct MyAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/assets/{symbol}` endpoint.
This endpoint returns one asset, by symbol or asset identifier.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.

### Constructors
- `MyAssetEndpointModel(; symbol::String)`: returns a new `MyAssetEndpointModel` instance.
"""
mutable struct MyAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    symbol::String

    # methods -
    MyAssetEndpointModel(;
        symbol::String) = new(symbol);
end

"""
    mutable struct MyPositionEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/positions/{symbol}` endpoint.
This endpoint returns the open position of one symbol.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.

### Constructors
- `MyPositionEndpointModel(; symbol::String)`: returns a new `MyPositionEndpointModel` instance.
"""
mutable struct MyPositionEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    symbol::String

    # methods -
    MyPositionEndpointModel(;
        symbol::String) = new(symbol);
end

"""
    mutable struct MyOrdersEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/orders` endpoint.
This endpoint returns the orders of the account that match a status.

### Fields
- `status::String`: the status filter, e.g., `"open"`.
- `limit::Int`: the largest number of rows to return per page.
- `after::Union{Nothing,String,DateTime}`: return only orders submitted after this time, or `nothing`.
- `until::Union{Nothing,String,DateTime}`: return only orders submitted until this time, or `nothing`.
- `direction::String`: the sort direction of the orders, `"asc"` or `"desc"`.
- `symbols::Union{Nothing,Vector{String}}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOrdersEndpointModel(; status::String = "open", limit::Int = 50, after::Union{Nothing,String,DateTime} = nothing, until::Union{Nothing,String,DateTime} = nothing, direction::String = "desc", symbols::Union{Nothing,String,AbstractVector{<:AbstractString}} = nothing)`: returns a new `MyOrdersEndpointModel` instance.
"""
mutable struct MyOrdersEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    status::String
    limit::Int
    after::Union{Nothing,String,DateTime}
    until::Union{Nothing,String,DateTime}
    direction::String
    symbols::Union{Nothing,Vector{String}}

    # methods -
    MyOrdersEndpointModel(;
        status::String = "open", limit::Int = 50, after::Union{Nothing,String,DateTime} = nothing, until::Union{Nothing,String,DateTime} = nothing, direction::String = "desc", symbols::Union{Nothing,String,AbstractVector{<:AbstractString}} = nothing) = new(status, limit, after, until, direction, _to_symbol_vector(symbols));
end

"""
    mutable struct MyOrderEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/orders/{id}` or `/orders:by_client_order_id` endpoint.
This endpoint returns one order, by order identifier or by client order identifier.

### Fields
- `id::Union{Nothing,String}`: the order identifier assigned by Alpaca, or `nothing`.
- `client_order_id::Union{Nothing,String}`: the order identifier assigned by the client, or `nothing`.

### Constructors
- `MyOrderEndpointModel(; id::Union{Nothing,String} = nothing, client_order_id::Union{Nothing,String} = nothing)`: returns a new `MyOrderEndpointModel` instance.
  Exactly one of `id` and `client_order_id` must be set, otherwise the constructor throws an `ArgumentError`.
"""
mutable struct MyOrderEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::Union{Nothing,String}
    client_order_id::Union{Nothing,String}

    # methods -
    function MyOrderEndpointModel(; id::Union{Nothing,String} = nothing, client_order_id::Union{Nothing,String} = nothing)

        # exactly one identifier must be set -
        if ((id === nothing && client_order_id === nothing) || (id !== nothing && client_order_id !== nothing))
            throw(ArgumentError("set exactly one of `id` and `client_order_id`"));
        end
        return new(id, client_order_id);
    end
end

"""
    mutable struct MyOptionContractsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/options/contracts` endpoint.
This endpoint returns the option contracts that match the filters.

### Fields
- `underlying_symbols::Vector{String}`: the underlying symbols of the contracts to list. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `status::String`: the status filter, e.g., `"open"`.
- `expiration_date::Union{Nothing,Date,String}`: the exact expiration date to match, or `nothing`.
- `expiration_date_gte::Union{Nothing,Date,String}`: the earliest expiration date to match, or `nothing`.
- `expiration_date_lte::Union{Nothing,Date,String}`: the latest expiration date to match, or `nothing`.
- `strike_price_gte::Union{Nothing,Real}`: the lowest strike price to match, or `nothing`.
- `strike_price_lte::Union{Nothing,Real}`: the highest strike price to match, or `nothing`.
- `type::Union{Nothing,String}`: the contract type to match, `"call"` or `"put"`, or `nothing`.
- `style::Union{Nothing,String}`: the exercise style to match, e.g., `"american"`, or `nothing`.
- `limit::Int`: the largest number of rows to return per page.

### Constructors
- `MyOptionContractsEndpointModel(; underlying_symbols::Union{String,AbstractVector{<:AbstractString}}, status::String = "active", expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, type::Union{Nothing,String} = nothing, style::Union{Nothing,String} = nothing, limit::Int = 1000)`: returns a new `MyOptionContractsEndpointModel` instance.
"""
mutable struct MyOptionContractsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    underlying_symbols::Vector{String}
    status::String
    expiration_date::Union{Nothing,Date,String}
    expiration_date_gte::Union{Nothing,Date,String}
    expiration_date_lte::Union{Nothing,Date,String}
    strike_price_gte::Union{Nothing,Real}
    strike_price_lte::Union{Nothing,Real}
    type::Union{Nothing,String}
    style::Union{Nothing,String}
    limit::Int

    # methods -
    MyOptionContractsEndpointModel(;
        underlying_symbols::Union{String,AbstractVector{<:AbstractString}}, status::String = "active", expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, type::Union{Nothing,String} = nothing, style::Union{Nothing,String} = nothing, limit::Int = 1000) = new(_to_symbol_vector(underlying_symbols), status, expiration_date, expiration_date_gte, expiration_date_lte, strike_price_gte, strike_price_lte, type, style, limit);
end

"""
    mutable struct MyOptionContractEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/options/contracts/{symbol}` endpoint.
This endpoint returns one option contract, by symbol or contract identifier.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.

### Constructors
- `MyOptionContractEndpointModel(; symbol::String)`: returns a new `MyOptionContractEndpointModel` instance.
"""
mutable struct MyOptionContractEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    symbol::String

    # methods -
    MyOptionContractEndpointModel(;
        symbol::String) = new(symbol);
end

"""
    mutable struct MyStockBarsEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/bars` endpoint.
This endpoint returns historical stock bars.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `timeframe::String`: the width of each bar, e.g., `"1Day"`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `adjustment::String`: the corporate action adjustment of the prices, e.g., `"raw"`.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockBarsEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, adjustment::String = "raw", feed::String = "iex")`: returns a new `MyStockBarsEndpointModel` instance.
"""
mutable struct MyStockBarsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    timeframe::String
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    adjustment::String
    feed::String

    # methods -
    MyStockBarsEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, adjustment::String = "raw", feed::String = "iex") = new(_to_symbol_vector(symbols), timeframe, start, finish, limit, adjustment, feed);
end

"""
    mutable struct MyStockQuotesEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/quotes` endpoint.
This endpoint returns historical stock quotes.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockQuotesEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex")`: returns a new `MyStockQuotesEndpointModel` instance.
"""
mutable struct MyStockQuotesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    feed::String

    # methods -
    MyStockQuotesEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex") = new(_to_symbol_vector(symbols), start, finish, limit, feed);
end

"""
    mutable struct MyStockTradesEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/trades` endpoint.
This endpoint returns historical stock trades.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockTradesEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex")`: returns a new `MyStockTradesEndpointModel` instance.
"""
mutable struct MyStockTradesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    feed::String

    # methods -
    MyStockTradesEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex") = new(_to_symbol_vector(symbols), start, finish, limit, feed);
end

"""
    mutable struct MyStockLatestBarEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{symbol}/bars/latest` endpoint.
This endpoint returns the latest stock bar of one symbol.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockLatestBarEndpointModel(; symbol::String, feed::String = "iex")`: returns a new `MyStockLatestBarEndpointModel` instance.
"""
mutable struct MyStockLatestBarEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbol::String
    feed::String

    # methods -
    MyStockLatestBarEndpointModel(;
        symbol::String, feed::String = "iex") = new(symbol, feed);
end

"""
    mutable struct MyStockLatestQuoteEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{symbol}/quotes/latest` endpoint.
This endpoint returns the latest stock quote of one symbol.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockLatestQuoteEndpointModel(; symbol::String, feed::String = "iex")`: returns a new `MyStockLatestQuoteEndpointModel` instance.
"""
mutable struct MyStockLatestQuoteEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbol::String
    feed::String

    # methods -
    MyStockLatestQuoteEndpointModel(;
        symbol::String, feed::String = "iex") = new(symbol, feed);
end

"""
    mutable struct MyStockLatestTradeEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{symbol}/trades/latest` endpoint.
This endpoint returns the latest stock trade of one symbol.

### Fields
- `symbol::String`: the symbol or identifier that the endpoint path names.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockLatestTradeEndpointModel(; symbol::String, feed::String = "iex")`: returns a new `MyStockLatestTradeEndpointModel` instance.
"""
mutable struct MyStockLatestTradeEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbol::String
    feed::String

    # methods -
    MyStockLatestTradeEndpointModel(;
        symbol::String, feed::String = "iex") = new(symbol, feed);
end

"""
    mutable struct MyStockSnapshotsEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/snapshots` endpoint.
This endpoint returns the snapshots of several stocks.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `feed::String`: the market data feed, e.g., `"iex"`.

### Constructors
- `MyStockSnapshotsEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, feed::String = "iex")`: returns a new `MyStockSnapshotsEndpointModel` instance.
"""
mutable struct MyStockSnapshotsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    feed::String

    # methods -
    MyStockSnapshotsEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, feed::String = "iex") = new(_to_symbol_vector(symbols), feed);
end

"""
    mutable struct MyOptionBarsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/bars` endpoint.
This endpoint returns historical option bars.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `timeframe::String`: the width of each bar, e.g., `"1Day"`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.

### Constructors
- `MyOptionBarsEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000)`: returns a new `MyOptionBarsEndpointModel` instance.
"""
mutable struct MyOptionBarsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}
    timeframe::String
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int

    # methods -
    MyOptionBarsEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000) = new(_to_symbol_vector(symbols), timeframe, start, finish, limit);
end

"""
    mutable struct MyOptionQuotesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/quotes` endpoint.
This endpoint returns historical option quotes.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.

### Constructors
- `MyOptionQuotesEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000)`: returns a new `MyOptionQuotesEndpointModel` instance.
"""
mutable struct MyOptionQuotesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int

    # methods -
    MyOptionQuotesEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000) = new(_to_symbol_vector(symbols), start, finish, limit);
end

"""
    mutable struct MyOptionTradesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/trades` endpoint.
This endpoint returns historical option trades.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.

### Constructors
- `MyOptionTradesEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000)`: returns a new `MyOptionTradesEndpointModel` instance.
"""
mutable struct MyOptionTradesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int

    # methods -
    MyOptionTradesEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000) = new(_to_symbol_vector(symbols), start, finish, limit);
end

"""
    mutable struct MyOptionLatestBarEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/bars/latest` endpoint.
This endpoint returns the latest option bar of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionLatestBarEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}})`: returns a new `MyOptionLatestBarEndpointModel` instance.
"""
mutable struct MyOptionLatestBarEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionLatestBarEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionLatestQuoteEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/quotes/latest` endpoint.
This endpoint returns the latest option quote of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionLatestQuoteEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}})`: returns a new `MyOptionLatestQuoteEndpointModel` instance.
"""
mutable struct MyOptionLatestQuoteEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionLatestQuoteEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionLatestTradeEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/trades/latest` endpoint.
This endpoint returns the latest option trade of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionLatestTradeEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}})`: returns a new `MyOptionLatestTradeEndpointModel` instance.
"""
mutable struct MyOptionLatestTradeEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionLatestTradeEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionSnapshotsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/snapshots` endpoint.
This endpoint returns the snapshots of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionSnapshotsEndpointModel(; symbols::Union{String,AbstractVector{<:AbstractString}})`: returns a new `MyOptionSnapshotsEndpointModel` instance.
"""
mutable struct MyOptionSnapshotsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionSnapshotsEndpointModel(;
        symbols::Union{String,AbstractVector{<:AbstractString}}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionChainEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/snapshots/{underlying}` endpoint.
This endpoint returns the option chain snapshots of one underlying stock.

### Fields
- `underlying::String`: the symbol of the underlying stock, e.g., `"SPY"`.
- `type::Union{Nothing,String}`: the contract type to match, `"call"` or `"put"`, or `nothing`.
- `strike_price_gte::Union{Nothing,Real}`: the lowest strike price to match, or `nothing`.
- `strike_price_lte::Union{Nothing,Real}`: the highest strike price to match, or `nothing`.
- `expiration_date::Union{Nothing,Date,String}`: the exact expiration date to match, or `nothing`.
- `expiration_date_gte::Union{Nothing,Date,String}`: the earliest expiration date to match, or `nothing`.
- `expiration_date_lte::Union{Nothing,Date,String}`: the latest expiration date to match, or `nothing`.
- `limit::Int`: the largest number of rows to return per page.

### Constructors
- `MyOptionChainEndpointModel(; underlying::String, type::Union{Nothing,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, limit::Int = 1000)`: returns a new `MyOptionChainEndpointModel` instance.
"""
mutable struct MyOptionChainEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    underlying::String
    type::Union{Nothing,String}
    strike_price_gte::Union{Nothing,Real}
    strike_price_lte::Union{Nothing,Real}
    expiration_date::Union{Nothing,Date,String}
    expiration_date_gte::Union{Nothing,Date,String}
    expiration_date_lte::Union{Nothing,Date,String}
    limit::Int

    # methods -
    MyOptionChainEndpointModel(;
        underlying::String, type::Union{Nothing,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, limit::Int = 1000) = new(underlying, type, strike_price_gte, strike_price_lte, expiration_date, expiration_date_gte, expiration_date_lte, limit);
end
