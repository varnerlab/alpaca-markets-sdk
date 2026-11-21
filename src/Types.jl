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
    AbstractAlpacaCryptoDataEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the crypto market data API.
"""
abstract type AbstractAlpacaCryptoDataEndpointModel <: AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaGlobalStockDataEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the market data API of stocks on non-US exchanges.
"""
abstract type AbstractAlpacaGlobalStockDataEndpointModel <: AbstractAlpacaEndpointModel end

"""
    AbstractAlpacaMarketDataEndpointModel <: AbstractAlpacaEndpointModel

Supertype of the endpoint models that call the news, screener, logo, and fixed income market data APIs.
"""
abstract type AbstractAlpacaMarketDataEndpointModel <: AbstractAlpacaEndpointModel end

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
function AlpacaClient(trading_url::AbstractString, data_url::AbstractString,
                      key_id::AbstractString, secret_key::AbstractString)::AlpacaClient

    # derive the options data base URL from the stock data base URL -
    options_data_url = _derive_options_url(data_url);

    # build the client with the derived options data base URL -
    return AlpacaClient(trading_url, data_url, options_data_url, key_id, secret_key);
end

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

function Base.showerror(io::IO, e::AlpacaError)::Nothing

    # print the status, the code, and the message -
    print(io, "AlpacaError(status=$(e.status), code=$(e.code)): $(e.message)");
    return nothing;
end

"""
    Account

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

A trading order. Returned by [`submit`](@ref), `close`, and [`roll`](@ref),
and by the deprecated functions [`submit_order`](@ref), [`submit_multileg_order`](@ref),
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

!!! warning "Deprecated"
    `OrderLeg` is deprecated, use `MyOptionLegModel(...)` instead, together with `submit`, `close`, or `roll`, which supply the position intent.

Legacy type, passed to the deprecated `submit_multileg_order`. New code uses `MyOptionLegModel`.

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

    # the constructor warns that OrderLeg is deprecated, and converts the arguments to the field types -
    function OrderLeg(symbol::AbstractString, ratio_qty::Integer, side::AbstractString, position_intent::AbstractString)
        Base.depwarn("`OrderLeg` is deprecated, use `MyOptionLegModel(...)` instead", :OrderLeg);
        return new(String(symbol), Int(ratio_qty), String(side), String(position_intent));
    end
end

"""
    Position

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

The bar that the `on_bar` streaming callback receives. The deprecated read functions, such as [`get_bars`](@ref) and
[`get_latest_bar`](@ref), also return a `Bar`, and new read code uses the `DataFrame` that `api` returns.

Fields:

- `symbol` — ticker
- `t` — bar start time (`DateTime`, UTC)
- `o`, `h`, `l`, `c` — open / high / low / close
- `v` — volume
- `n` — trade count, or `nothing` when the feed does not send it
- `vw` — volume-weighted average price, or `nothing` when the feed does not send it
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

The quote that the `on_quote` streaming callback receives. The deprecated read functions, such as [`get_quotes`](@ref) and
[`get_latest_quote`](@ref), also return a `Quote`, and new read code uses the `DataFrame` that `api` returns.

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

The trade that the `on_trade` streaming callback receives. The deprecated read functions, such as [`get_trades`](@ref) and
[`get_latest_trade`](@ref), also return a `Trade`, and new read code uses the `DataFrame` that `api` returns.

Fields: `symbol`, `t`, `price`, `size`, `exchange`, `id` (the trade id of the exchange, or `nothing` when the message
has none).
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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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

Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.

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
- `start::Union{Nothing,Date,String}`: the first day of the request, a `Date` or an ISO `"YYYY-MM-DD"` `String`.
- `finish::Union{Nothing,Date,String}`: the last day of the request, or `nothing` to leave it open. The URL sends this field as `end`.

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
- `status::String`: the status filter, e.g., `"active"`.
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
- `MyOrdersEndpointModel(; status::String = "open", limit::Int = 50, after::Union{Nothing,String,DateTime} = nothing, until::Union{Nothing,String,DateTime} = nothing, direction::String = "desc", symbols::Union{Nothing,AbstractString,AbstractVector} = nothing)`: returns a new `MyOrdersEndpointModel` instance.
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
        status::String = "open", limit::Int = 50, after::Union{Nothing,String,DateTime} = nothing, until::Union{Nothing,String,DateTime} = nothing, direction::String = "desc", symbols::Union{Nothing,AbstractString,AbstractVector} = nothing) = new(status, limit, after, until, direction, _to_symbol_vector(symbols));
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
- `MyOptionContractsEndpointModel(; underlying_symbols::Union{AbstractString,AbstractVector}, status::String = "active", expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, type::Union{Nothing,String} = nothing, style::Union{Nothing,String} = nothing, limit::Int = 1000)`: returns a new `MyOptionContractsEndpointModel` instance.
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
        underlying_symbols::Union{AbstractString,AbstractVector}, status::String = "active", expiration_date::Union{Nothing,Date,String} = nothing, expiration_date_gte::Union{Nothing,Date,String} = nothing, expiration_date_lte::Union{Nothing,Date,String} = nothing, strike_price_gte::Union{Nothing,Real} = nothing, strike_price_lte::Union{Nothing,Real} = nothing, type::Union{Nothing,String} = nothing, style::Union{Nothing,String} = nothing, limit::Int = 1000) = new(_to_symbol_vector(underlying_symbols), status, expiration_date, expiration_date_gte, expiration_date_lte, strike_price_gte, strike_price_lte, type, style, limit);
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
- `MyStockBarsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, adjustment::String = "raw", feed::String = "iex")`: returns a new `MyStockBarsEndpointModel` instance.
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
        symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, adjustment::String = "raw", feed::String = "iex") = new(_to_symbol_vector(symbols), timeframe, start, finish, limit, adjustment, feed);
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
- `MyStockQuotesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex")`: returns a new `MyStockQuotesEndpointModel` instance.
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
        symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex") = new(_to_symbol_vector(symbols), start, finish, limit, feed);
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
- `MyStockTradesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex")`: returns a new `MyStockTradesEndpointModel` instance.
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
        symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "iex") = new(_to_symbol_vector(symbols), start, finish, limit, feed);
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
- `MyStockSnapshotsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, feed::String = "iex")`: returns a new `MyStockSnapshotsEndpointModel` instance.
"""
mutable struct MyStockSnapshotsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    feed::String

    # methods -
    MyStockSnapshotsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, feed::String = "iex") = new(_to_symbol_vector(symbols), feed);
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
- `MyOptionBarsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000)`: returns a new `MyOptionBarsEndpointModel` instance.
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
        symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000) = new(_to_symbol_vector(symbols), timeframe, start, finish, limit);
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
- `MyOptionTradesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000)`: returns a new `MyOptionTradesEndpointModel` instance.
"""
mutable struct MyOptionTradesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int

    # methods -
    MyOptionTradesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000) = new(_to_symbol_vector(symbols), start, finish, limit);
end

"""
    mutable struct MyOptionLatestQuoteEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/quotes/latest` endpoint.
This endpoint returns the latest option quote of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionLatestQuoteEndpointModel(; symbols::Union{AbstractString,AbstractVector})`: returns a new `MyOptionLatestQuoteEndpointModel` instance.
"""
mutable struct MyOptionLatestQuoteEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionLatestQuoteEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionLatestTradeEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/trades/latest` endpoint.
This endpoint returns the latest option trade of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionLatestTradeEndpointModel(; symbols::Union{AbstractString,AbstractVector})`: returns a new `MyOptionLatestTradeEndpointModel` instance.
"""
mutable struct MyOptionLatestTradeEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionLatestTradeEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}) = new(_to_symbol_vector(symbols));
end

"""
    mutable struct MyOptionSnapshotsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/snapshots` endpoint.
This endpoint returns the snapshots of several option contracts.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyOptionSnapshotsEndpointModel(; symbols::Union{AbstractString,AbstractVector})`: returns a new `MyOptionSnapshotsEndpointModel` instance.
"""
mutable struct MyOptionSnapshotsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    symbols::Vector{String}

    # methods -
    MyOptionSnapshotsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}) = new(_to_symbol_vector(symbols));
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

"""
    mutable struct MyAccountConfigurationsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/account/configurations` endpoint.
This endpoint returns the settings of the account, e.g., the day-trade buying power check and fractional trading.

### Fields
- None: the endpoint takes no parameters.

### Constructors
- `MyAccountConfigurationsEndpointModel()`: returns a new `MyAccountConfigurationsEndpointModel` instance.
"""
mutable struct MyAccountConfigurationsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyAccountConfigurationsEndpointModel() = new();
end

"""
    mutable struct MyAccountActivitiesEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/account/activities` and `/account/activities/{activity_type}` endpoints.
These endpoints return the account activities, e.g., fills and dividends, that match the filters.
Alpaca pages the activities by `page_token`, and `api` does not follow the pages. A caller reads the last activity identifier and passes it as the next `page_token`.

### Fields
- `activity_type::Union{Nothing,String}`: one activity type, e.g., `"FILL"`, sent in the path, or `nothing`.
- `activity_types::Union{Nothing,Vector{String}}`: the activity types to list, sent as a comma list, or `nothing`. The keyword accepts a `String` or a vector of strings.
- `category::Union{Nothing,String}`: `"trade_activity"` or `"non_trade_activity"`, or `nothing`. The URL carries `category` only when `activity_type` is `nothing`.
- `date::Union{Nothing,Date,String}`: the one day to list, or `nothing`.
- `after::Union{Nothing,Date,DateTime,String}`: return only activities after this time, or `nothing`.
- `until::Union{Nothing,Date,DateTime,String}`: return only activities until this time, or `nothing`.
- `direction::String`: the sort direction of the activities, `"asc"` or `"desc"`.
- `page_size::Int`: the largest number of activities to return, at most `100`.
- `page_token::Union{Nothing,String}`: the identifier of the last activity of the previous page, or `nothing`.
- `order_id::Union{Nothing,String}`: return only the activities of this order, or `nothing`.

### Constructors
- `MyAccountActivitiesEndpointModel(; activity_type = nothing, activity_types = nothing, category = nothing, date = nothing, after = nothing, until = nothing, direction = "desc", page_size = 100, page_token = nothing, order_id = nothing)`: returns a new `MyAccountActivitiesEndpointModel` instance.
  Setting both `activity_type` and `activity_types` throws an `ArgumentError`.
"""
mutable struct MyAccountActivitiesEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    activity_type::Union{Nothing,String}
    activity_types::Union{Nothing,Vector{String}}
    category::Union{Nothing,String}
    date::Union{Nothing,Date,String}
    after::Union{Nothing,Date,DateTime,String}
    until::Union{Nothing,Date,DateTime,String}
    direction::String
    page_size::Int
    page_token::Union{Nothing,String}
    order_id::Union{Nothing,String}

    # methods -
    function MyAccountActivitiesEndpointModel(; activity_type::Union{Nothing,String} = nothing, activity_types::Union{Nothing,AbstractString,AbstractVector} = nothing,
        category::Union{Nothing,String} = nothing, date::Union{Nothing,Date,String} = nothing, after::Union{Nothing,Date,DateTime,String} = nothing,
        until::Union{Nothing,Date,DateTime,String} = nothing, direction::String = "desc", page_size::Int = 100,
        page_token::Union{Nothing,String} = nothing, order_id::Union{Nothing,String} = nothing)

        # at most one of the two type keywords can be set -
        if (activity_type !== nothing && activity_types !== nothing)
            throw(ArgumentError("set at most one of `activity_type` and `activity_types`"));
        end
        return new(activity_type, _to_symbol_vector(activity_types), category, date, after, until, direction, page_size, page_token, order_id);
    end
end

"""
    mutable struct MyPortfolioHistoryEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/account/portfolio/history` endpoint.
This endpoint returns the equity and the profit and loss of the account over a period.

### Fields
- `period::Union{Nothing,String}`: the length of the history, e.g., `"1M"`, or `nothing`.
- `timeframe::Union{Nothing,String}`: the time between rows, e.g., `"1D"`, or `nothing`.
- `intraday_reporting::Union{Nothing,String}`: `"market_hours"`, `"extended_hours"` or `"continuous"`, or `nothing`.
- `start::Union{Nothing,Date,DateTime,String}`: the start of the history, or `nothing`.
- `finish::Union{Nothing,Date,DateTime,String}`: the end of the history, sent as `end`, or `nothing`.
- `pnl_reset::Union{Nothing,String}`: `"no_reset"` or `"per_day"`, or `nothing`.
- `extended_hours::Union{Nothing,Bool}`: whether to include extended hours, or `nothing`.
- `cashflow_types::Union{Nothing,Vector{String}}`: the cash flow types to include, sent as a comma list, or `nothing`. The keyword accepts a `String` or a vector of strings.

### Constructors
- `MyPortfolioHistoryEndpointModel(; period = nothing, timeframe = nothing, intraday_reporting = nothing, start = nothing, finish = nothing, pnl_reset = nothing, extended_hours = nothing, cashflow_types = nothing)`: returns a new `MyPortfolioHistoryEndpointModel` instance.
"""
mutable struct MyPortfolioHistoryEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    period::Union{Nothing,String}
    timeframe::Union{Nothing,String}
    intraday_reporting::Union{Nothing,String}
    start::Union{Nothing,Date,DateTime,String}
    finish::Union{Nothing,Date,DateTime,String}
    pnl_reset::Union{Nothing,String}
    extended_hours::Union{Nothing,Bool}
    cashflow_types::Union{Nothing,Vector{String}}

    # methods -
    MyPortfolioHistoryEndpointModel(;
        period::Union{Nothing,String} = nothing, timeframe::Union{Nothing,String} = nothing, intraday_reporting::Union{Nothing,String} = nothing,
        start::Union{Nothing,Date,DateTime,String} = nothing, finish::Union{Nothing,Date,DateTime,String} = nothing,
        pnl_reset::Union{Nothing,String} = nothing, extended_hours::Union{Nothing,Bool} = nothing,
        cashflow_types::Union{Nothing,AbstractString,AbstractVector} = nothing) = new(period, timeframe, intraday_reporting, start, finish, pnl_reset, extended_hours, _to_symbol_vector(cashflow_types));
end

"""
    mutable struct MyMarketCalendarEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/v3/calendar/{market}` endpoint.
This endpoint returns the calendar of one market, e.g., the NYSE: the trading days and the times of the sessions.
The model calls the `v3` base URL of the trading API.

### Fields
- `market::String`: the market acronym, e.g., `"NYSE"`.
- `start::Union{Nothing,Date,DateTime,String}`: the first day of the calendar, or `nothing`.
- `finish::Union{Nothing,Date,DateTime,String}`: the last day of the calendar, sent as `end`, or `nothing`.
- `timezone::Union{Nothing,String}`: the time zone of the session times, `"UTC"`, or `nothing`.

### Constructors
- `MyMarketCalendarEndpointModel(; market = "NYSE", start = nothing, finish = nothing, timezone = nothing)`: returns a new `MyMarketCalendarEndpointModel` instance.
"""
mutable struct MyMarketCalendarEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    market::String
    start::Union{Nothing,Date,DateTime,String}
    finish::Union{Nothing,Date,DateTime,String}
    timezone::Union{Nothing,String}

    # methods -
    MyMarketCalendarEndpointModel(;
        market::String = "NYSE", start::Union{Nothing,Date,DateTime,String} = nothing, finish::Union{Nothing,Date,DateTime,String} = nothing,
        timezone::Union{Nothing,String} = nothing) = new(market, start, finish, timezone);
end

"""
    mutable struct MyMarketClocksEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/v3/clock` endpoint.
This endpoint returns the clocks of several markets: whether each market is in a trading phase now, and when the market opens and closes next.
The model calls the `v3` base URL of the trading API.

### Fields
- `markets::Union{Nothing,Vector{String}}`: the market acronyms, e.g., `"NYSE"`, sent as a comma list, or `nothing`. The keyword accepts a `String` or a vector of strings.
- `time::Union{Nothing,Date,DateTime,String}`: the time to read the clocks at, or `nothing`.

### Constructors
- `MyMarketClocksEndpointModel(; markets = nothing, time = nothing)`: returns a new `MyMarketClocksEndpointModel` instance.
"""
mutable struct MyMarketClocksEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    markets::Union{Nothing,Vector{String}}
    time::Union{Nothing,Date,DateTime,String}

    # methods -
    MyMarketClocksEndpointModel(;
        markets::Union{Nothing,AbstractString,AbstractVector} = nothing,
        time::Union{Nothing,Date,DateTime,String} = nothing) = new(_to_symbol_vector(markets), time);
end

"""
    mutable struct MyEquityOrderModel <: AbstractAlpacaOrderModel

Order model for one equity or ETF order. The model says what to trade. The `submit` method supplies the order keywords.

### Fields
- `symbol::String`: the ticker symbol of the equity.
- `side::String`: `"buy"` or `"sell"`.
- `qty::Union{Nothing,Real}`: the number of shares (can be fractional), or `nothing` when `notional` is set.
- `notional::Union{Nothing,Real}`: the dollar amount to trade, or `nothing` when `qty` is set.

### Constructors
- `MyEquityOrderModel(; symbol::String, side::String, qty::Union{Nothing,Real} = nothing, notional::Union{Nothing,Real} = nothing)`: returns a new `MyEquityOrderModel` instance.
  The constructor throws an `ArgumentError` unless `side` is `"buy"` or `"sell"` and exactly one of `qty` and `notional` is set.
"""
mutable struct MyEquityOrderModel <: AbstractAlpacaOrderModel

    # data -
    symbol::String
    side::String
    qty::Union{Nothing,Real}
    notional::Union{Nothing,Real}

    # methods -
    function MyEquityOrderModel(; symbol::String, side::String, qty::Union{Nothing,Real} = nothing, notional::Union{Nothing,Real} = nothing)

        # the side must be buy or sell -
        if ((side == "buy" || side == "sell") == false)
            throw(ArgumentError("side must be \"buy\" or \"sell\", got \"$(side)\""));
        end

        # exactly one of qty and notional must be set -
        if ((qty === nothing && notional === nothing) || (qty !== nothing && notional !== nothing))
            throw(ArgumentError("set exactly one of `qty` and `notional`"));
        end
        return new(symbol, side, qty, notional);
    end
end

"""
    mutable struct MyOptionLegModel <: AbstractAlpacaOrderModel

Order model for one option leg. A leg has no position intent. The verb (`submit`, and later `close` and `roll`) supplies the intent.

### Fields
- `symbol::String`: the OCC symbol of the option contract.
- `side::String`: `"buy"` (long the contract) or `"sell"` (short the contract).
- `ratio::Int`: the number of contracts of this leg in one unit of the structure.

### Constructors
- `MyOptionLegModel(; symbol::String, side::String, ratio::Int = 1)`: returns a new `MyOptionLegModel` instance.
  The constructor throws an `ArgumentError` unless `side` is `"buy"` or `"sell"` and `ratio >= 1`.
"""
mutable struct MyOptionLegModel <: AbstractAlpacaOrderModel

    # data -
    symbol::String
    side::String
    ratio::Int

    # methods -
    function MyOptionLegModel(; symbol::String, side::String, ratio::Int = 1)

        # the side must be buy or sell -
        if ((side == "buy" || side == "sell") == false)
            throw(ArgumentError("side must be \"buy\" or \"sell\", got \"$(side)\""));
        end

        # the ratio must be at least 1 -
        if (ratio < 1)
            throw(ArgumentError("ratio must be at least 1, got $(ratio)"));
        end
        return new(symbol, side, ratio);
    end
end

"""
    mutable struct MyMixedOrderModel <: AbstractAlpacaOrderModel

Order model for shares and options together, e.g., a covered call. Alpaca cannot fill shares and options in one order,
so `submit` and `close` send two orders in a fixed sequence.

### Fields
- `equity::MyEquityOrderModel`: the equity part of the structure.
- `options::Vector{MyOptionLegModel}`: the option legs of the structure.

### Constructors
- `MyMixedOrderModel(; equity::MyEquityOrderModel, options::Vector{MyOptionLegModel})`: returns a new `MyMixedOrderModel` instance.
  The constructor throws an `ArgumentError` when `options` has no legs.
"""
mutable struct MyMixedOrderModel <: AbstractAlpacaOrderModel

    # data -
    equity::MyEquityOrderModel
    options::Vector{MyOptionLegModel}

    # methods -
    function MyMixedOrderModel(; equity::MyEquityOrderModel, options::Vector{MyOptionLegModel})

        # the structure needs at least one option leg -
        if (isempty(options))
            throw(ArgumentError("options must hold at least one leg"));
        end
        return new(equity, options);
    end
end

"""
    struct AlpacaSequenceError <: Exception

Raised when the two-order sequence of a `MyMixedOrderModel` stops after the first order. The error holds the orders sent so far,
so the caller knows which part of the structure filled.

### Fields
- `message::String`: what went wrong.
- `orders::Vector{Order}`: the orders sent so far, in sequence order.
- `cause::Union{Nothing,Exception}`: the error that stopped the sequence: the `AlpacaError` of the second request, or the error raised while polling the first order. It is `nothing` when the first order did not fill in time.

### Constructors
- `AlpacaSequenceError(message::String, orders::Vector{Order}, cause::Union{Nothing,Exception})`: returns a new `AlpacaSequenceError` instance.
"""
struct AlpacaSequenceError <: Exception
    message::String
    orders::Vector{Order}
    cause::Union{Nothing,Exception}
end

"""
    Base.showerror(io::IO, e::AlpacaSequenceError)

Print the message of an `AlpacaSequenceError`, the id and the status of each order sent so far, and the cause when there is one.
"""
function Base.showerror(io::IO, e::AlpacaSequenceError)::Nothing

    # print the message -
    print(io, "AlpacaSequenceError: ", e.message);

    # print the id and the status of each order sent so far -
    for order in e.orders
        print(io, "\n  order ", order.id, ": ", order.status);
    end

    # print the cause, when there is one -
    if (e.cause !== nothing)
        print(io, "\n  cause: ");
        showerror(io, e.cause);
    end
    return nothing;
end

# _check_id_or_name: throws an ArgumentError unless exactly one of the identifier and the name of a watchlist is set -
function _check_id_or_name(id::Union{Nothing,String}, name::Union{Nothing,String})::Nothing
    if ((id === nothing && name === nothing) || (id !== nothing && name !== nothing))
        throw(ArgumentError("set exactly one of `id` and `name`"));
    end
    return nothing;
end

"""
    mutable struct MyWatchlistsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/watchlists` endpoint.
This endpoint lists the watchlists of the account, without their assets.

### Fields
- None: the endpoint takes no parameters.

### Constructors
- `MyWatchlistsEndpointModel()`: returns a new `MyWatchlistsEndpointModel` instance.
"""
mutable struct MyWatchlistsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyWatchlistsEndpointModel() = new();
end

"""
    mutable struct MyWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for the Alpaca `/watchlists/{watchlist_id}` or `/watchlists:by_name` endpoint.
This endpoint returns one watchlist with its assets, by watchlist identifier or by name.

### Fields
- `id::Union{Nothing,String}`: the watchlist identifier assigned by Alpaca, or `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, or `nothing`.

### Constructors
- `MyWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing)`: returns a new `MyWatchlistEndpointModel` instance.
  Exactly one of `id` and `name` must be set, otherwise the constructor throws an `ArgumentError`.
"""
mutable struct MyWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::Union{Nothing,String}
    name::Union{Nothing,String}

    # methods -
    function MyWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing)

        # exactly one of the identifier and the name must be set -
        _check_id_or_name(id, name);
        return new(id, name);
    end
end

"""
    mutable struct MyCreateWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for creating a watchlist with an HTTP POST to the Alpaca `/watchlists` endpoint.
The endpoint answers with the new watchlist and its assets.

### Fields
- `name::String`: the name of the new watchlist.
- `symbols::Vector{String}`: the symbols of the assets that the new watchlist starts with. The keyword accepts a `String` or a vector of strings.

### Constructors
- `MyCreateWatchlistEndpointModel(; name::String, symbols::Union{AbstractString,AbstractVector} = String[])`: returns a new `MyCreateWatchlistEndpointModel` instance.
"""
mutable struct MyCreateWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    name::String
    symbols::Vector{String}

    # methods -
    MyCreateWatchlistEndpointModel(; name::String, symbols::Union{AbstractString,AbstractVector} = String[]) = new(name, _to_symbol_vector(symbols));
end

"""
    mutable struct MyUpdateWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for changing a watchlist with an HTTP PUT to the Alpaca `/watchlists/{watchlist_id}` or `/watchlists:by_name` endpoint.
The endpoint answers with the changed watchlist and its assets.

### Fields
- `id::Union{Nothing,String}`: the watchlist identifier assigned by Alpaca, or `nothing`.
- `name::Union{Nothing,String}`: the current name of the watchlist, or `nothing`.
- `new_name::Union{Nothing,String}`: the new name of the watchlist, or `nothing` to keep the name.
- `symbols::Union{Nothing,Vector{String}}`: the symbols that replace the assets of the watchlist, or `nothing` to keep the assets. The keyword accepts a `String` or a vector of strings.

### Constructors
- `MyUpdateWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing, new_name::Union{Nothing,String} = nothing, symbols::Union{Nothing,AbstractString,AbstractVector} = nothing)`: returns a new `MyUpdateWatchlistEndpointModel` instance.
  Exactly one of `id` and `name` must be set, and at least one of `new_name` and `symbols` must be set, otherwise the constructor throws an `ArgumentError`.
"""
mutable struct MyUpdateWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::Union{Nothing,String}
    name::Union{Nothing,String}
    new_name::Union{Nothing,String}
    symbols::Union{Nothing,Vector{String}}

    # methods -
    function MyUpdateWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing,
        new_name::Union{Nothing,String} = nothing, symbols::Union{Nothing,AbstractString,AbstractVector} = nothing)

        # exactly one of the identifier and the name must be set -
        _check_id_or_name(id, name);

        # something must change -
        if (new_name === nothing && symbols === nothing)
            throw(ArgumentError("set at least one of `new_name` and `symbols`"));
        end
        return new(id, name, new_name, _to_symbol_vector(symbols));
    end
end

"""
    mutable struct MyAddWatchlistAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for adding one asset to a watchlist with an HTTP POST to the Alpaca `/watchlists/{watchlist_id}` or `/watchlists:by_name` endpoint.
The endpoint answers with the changed watchlist and its assets.

### Fields
- `id::Union{Nothing,String}`: the watchlist identifier assigned by Alpaca, or `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, or `nothing`.
- `symbol::String`: the symbol of the asset to add.

### Constructors
- `MyAddWatchlistAssetEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing, symbol::String)`: returns a new `MyAddWatchlistAssetEndpointModel` instance.
  Exactly one of `id` and `name` must be set, otherwise the constructor throws an `ArgumentError`.
"""
mutable struct MyAddWatchlistAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::Union{Nothing,String}
    name::Union{Nothing,String}
    symbol::String

    # methods -
    function MyAddWatchlistAssetEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing, symbol::String)

        # exactly one of the identifier and the name must be set -
        _check_id_or_name(id, name);
        return new(id, name, symbol);
    end
end

"""
    mutable struct MyRemoveWatchlistAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for removing one asset from a watchlist with an HTTP DELETE to the Alpaca `/watchlists/{watchlist_id}/{symbol}` endpoint.
Alpaca has no by-name form of this endpoint. The endpoint answers with the changed watchlist and its assets.

### Fields
- `id::String`: the watchlist identifier assigned by Alpaca.
- `symbol::String`: the symbol of the asset to remove.

### Constructors
- `MyRemoveWatchlistAssetEndpointModel(; id::String, symbol::String)`: returns a new `MyRemoveWatchlistAssetEndpointModel` instance.
"""
mutable struct MyRemoveWatchlistAssetEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::String
    symbol::String

    # methods -
    MyRemoveWatchlistAssetEndpointModel(; id::String, symbol::String) = new(id, symbol);
end

"""
    mutable struct MyDeleteWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for deleting a watchlist with an HTTP DELETE to the Alpaca `/watchlists/{watchlist_id}` or `/watchlists:by_name` endpoint.
The endpoint answers with no body, so the default handler returns an empty table.

### Fields
- `id::Union{Nothing,String}`: the watchlist identifier assigned by Alpaca, or `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, or `nothing`.

### Constructors
- `MyDeleteWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing)`: returns a new `MyDeleteWatchlistEndpointModel` instance.
  Exactly one of `id` and `name` must be set, otherwise the constructor throws an `ArgumentError`.
"""
mutable struct MyDeleteWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::Union{Nothing,String}
    name::Union{Nothing,String}

    # methods -
    function MyDeleteWatchlistEndpointModel(; id::Union{Nothing,String} = nothing, name::Union{Nothing,String} = nothing)

        # exactly one of the identifier and the name must be set -
        _check_id_or_name(id, name);
        return new(id, name);
    end
end
