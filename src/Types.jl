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
    mutable struct MyStockLatestBarsEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/bars/latest` endpoint.
This endpoint returns the latest stock bar of each of several symbols.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `feed::String`: the market data feed, e.g., `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, or `nothing` to leave it to Alpaca.

### Constructors
- `MyStockLatestBarsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing)`: returns a new `MyStockLatestBarsEndpointModel` instance.
"""
mutable struct MyStockLatestBarsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    feed::String
    currency::Union{Nothing,String}

    # methods -
    MyStockLatestBarsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), feed, currency);
end

"""
    mutable struct MyStockLatestQuotesEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/quotes/latest` endpoint.
This endpoint returns the latest stock quote of each of several symbols.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `feed::String`: the market data feed, e.g., `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, or `nothing` to leave it to Alpaca.

### Constructors
- `MyStockLatestQuotesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing)`: returns a new `MyStockLatestQuotesEndpointModel` instance.
"""
mutable struct MyStockLatestQuotesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    feed::String
    currency::Union{Nothing,String}

    # methods -
    MyStockLatestQuotesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), feed, currency);
end

"""
    mutable struct MyStockLatestTradesEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/trades/latest` endpoint.
This endpoint returns the latest stock trade of each of several symbols.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `feed::String`: the market data feed, e.g., `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, or `nothing` to leave it to Alpaca.

### Constructors
- `MyStockLatestTradesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing)`: returns a new `MyStockLatestTradesEndpointModel` instance.
"""
mutable struct MyStockLatestTradesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    feed::String
    currency::Union{Nothing,String}

    # methods -
    MyStockLatestTradesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, feed::String = "iex", currency::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), feed, currency);
end

"""
    mutable struct MyStockAuctionsEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/auctions` endpoint.
This endpoint returns the historical opening and closing auction prints of each of several symbols.

### Fields
- `symbols::Vector{String}`: the symbols to request. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the request, or `nothing` to leave it open.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `feed::String`: the market data feed. Alpaca accepts only `"sip"` for auctions.
- `sort::Union{Nothing,String}`: the sort order of the prints, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.

### Constructors
- `MyStockAuctionsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "sip", sort::Union{Nothing,String} = nothing)`: returns a new `MyStockAuctionsEndpointModel` instance.
"""
mutable struct MyStockAuctionsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    feed::String
    sort::Union{Nothing,String}

    # methods -
    MyStockAuctionsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, feed::String = "sip", sort::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), start, finish, limit, feed, sort);
end

"""
    mutable struct MyStockConditionsEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/meta/conditions/{ticktype}` endpoint.
This endpoint returns the map from each condition code to its name, for the trades or the quotes of one tape.

### Fields
- `ticktype::String`: the kind of tick whose condition codes to list, `"trade"` or `"quote"`. The URL carries it in the path.
- `tape::String`: the tape whose condition codes to list, `"A"`, `"B"`, or `"C"`.

### Constructors
- `MyStockConditionsEndpointModel(; ticktype::String = "trade", tape::String = "A")`: returns a new `MyStockConditionsEndpointModel` instance.
  The constructor throws an `ArgumentError` unless `ticktype` is `"trade"` or `"quote"` and `tape` is `"A"`, `"B"`, or `"C"`.
"""
mutable struct MyStockConditionsEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # data -
    ticktype::String
    tape::String

    # methods -
    function MyStockConditionsEndpointModel(; ticktype::String = "trade", tape::String = "A")

        # the tick type and the tape must be values that Alpaca accepts -
        _check_ticktype(ticktype);
        if (tape != "A" && tape != "B" && tape != "C")
            throw(ArgumentError("`tape` must be \"A\", \"B\", or \"C\""));
        end
        return new(ticktype, tape);
    end
end

"""
    mutable struct MyStockExchangesEndpointModel <: AbstractAlpacaStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/meta/exchanges` endpoint.
This endpoint returns the map from each exchange code to the name of the exchange. The model has no fields.

### Fields
- None: the request has no parameters.

### Constructors
- `MyStockExchangesEndpointModel()`: returns a new `MyStockExchangesEndpointModel` instance.
"""
mutable struct MyStockExchangesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # methods -
    MyStockExchangesEndpointModel() = new();
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
    mutable struct MyCryptoOrderModel <: AbstractAlpacaOrderModel

Order model for one crypto order. The model says what to trade. The `submit` method supplies the order keywords.

### Fields
- `symbol::String`: the crypto pair, e.g., `"BTC/USD"`.
- `side::String`: `"buy"` or `"sell"`.
- `qty::Union{Nothing,Real}`: the number of coins (can be fractional), or `nothing` when `notional` is set.
- `notional::Union{Nothing,Real}`: the dollar amount to trade, or `nothing` when `qty` is set.

### Constructors
- `MyCryptoOrderModel(; symbol::String, side::String, qty::Union{Nothing,Real} = nothing, notional::Union{Nothing,Real} = nothing)`: returns a new `MyCryptoOrderModel` instance.
  The constructor throws an `ArgumentError` unless `side` is `"buy"` or `"sell"` and exactly one of `qty` and `notional` is set.
"""
mutable struct MyCryptoOrderModel <: AbstractAlpacaOrderModel

    # data -
    symbol::String
    side::String
    qty::Union{Nothing,Real}
    notional::Union{Nothing,Real}

    # methods -
    function MyCryptoOrderModel(; symbol::String, side::String, qty::Union{Nothing,Real} = nothing, notional::Union{Nothing,Real} = nothing)

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
- `symbols::Union{Nothing,Vector{String}}`: the symbols that replace the assets of the watchlist, or `nothing`. Alpaca replaces the whole watchlist, so a rename without `symbols` empties the list. Pass the current symbols to keep them. The keyword accepts a `String` or a vector of strings.

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

# _none_set: true when every value in the tuple is nothing -
function _none_set(values::Tuple)::Bool
    for value in values
        if (value !== nothing)
            return false;
        end
    end
    return true;
end

# _decimal_text: a number as the text of an order field. Text that string(x) writes without an exponent is returned as it is.
# A number that string(x) writes with an exponent, e.g., 1.0e-5, becomes a plain decimal with no exponent and no trailing zeros -
function _decimal_text(x::Union{AbstractString,Real})::String
    text = string(x);

    # find the exponent mark; text with no exponent is returned unchanged -
    if (x isa AbstractString)
        return text;
    end
    mark = 0;
    for i in 2:length(text)
        if ((text[i] == 'e' || text[i] == 'f') && isdigit(text[i-1]))
            mark = i;
            break;
        end
    end
    if (mark == 0)
        return text;
    end

    # split the text into the sign, the digits of the mantissa, and the exponent -
    mantissa = text[1:mark-1];
    exponent = parse(Int, text[mark+1:end]);
    sign = "";
    if (startswith(mantissa, "-"))
        sign = "-";
        mantissa = mantissa[2:end];
    end
    dot = findfirst('.', mantissa);
    whole_length = length(mantissa);
    digits = mantissa;
    if (dot !== nothing)
        whole_length = dot - 1;
        digits = mantissa[1:dot-1] * mantissa[dot+1:end];
    end

    # move the decimal point by the exponent -
    point = whole_length + exponent;
    plain = "";
    if (point <= 0)
        plain = "0." * repeat("0", -point) * digits;
    elseif (point >= length(digits))
        plain = digits * repeat("0", point - length(digits));
    else
        plain = digits[1:point] * "." * digits[point+1:end];
    end

    # drop the trailing zeros after the decimal point, and the point itself when nothing follows it -
    if (occursin('.', plain))
        plain = rstrip(plain, '0');
        plain = rstrip(plain, '.');
    end
    return sign * plain;
end

# _number_text: the text that a setting or an order field is sent as, or nothing when the field is not set -
function _number_text(x::Union{Nothing,AbstractString,Real})::Union{Nothing,String}
    if (x === nothing)
        return nothing;
    end
    return _decimal_text(x);
end

"""
    mutable struct MyUpdateAccountConfigurationsEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for changing the account settings with an HTTP PATCH to the Alpaca `/account/configurations` endpoint.
The request holds the settings that are set. The endpoint answers with all the settings of the account.

### Fields
- `disable_overnight_trading::Union{Nothing,Bool}`: `true` turns off overnight trading, or `nothing` to keep the setting.
- `fractional_trading::Union{Nothing,Bool}`: `true` allows fractional trading, or `nothing` to keep the setting.
- `max_margin_multiplier::Union{Nothing,String}`: the maximum margin multiplier, sent as text, or `nothing` to keep the setting.
- `max_options_trading_level::Union{Nothing,Int}`: the maximum options trading level, an integer in `0:3`, or `nothing` to keep the setting.
- `no_shorting::Union{Nothing,Bool}`: `true` blocks short sales, or `nothing` to keep the setting.
- `ptp_no_exception_entry::Union{Nothing,Bool}`: `true` blocks entry orders for publicly traded partnerships, or `nothing` to keep the setting.
- `suspend_trade::Union{Nothing,Bool}`: `true` suspends trading, or `nothing` to keep the setting.
- `trade_confirm_email::Union{Nothing,String}`: the trade confirmation email setting, e.g., `"all"`, or `nothing` to keep the setting.

### Constructors
- `MyUpdateAccountConfigurationsEndpointModel(; disable_overnight_trading = nothing, fractional_trading = nothing, max_margin_multiplier = nothing, max_options_trading_level = nothing, no_shorting = nothing, ptp_no_exception_entry = nothing, suspend_trade = nothing, trade_confirm_email = nothing)`: returns a new `MyUpdateAccountConfigurationsEndpointModel` instance.
  The keyword `max_margin_multiplier` accepts a `String` or a `Real`.
  The constructor throws an `ArgumentError` when no setting is set, or when `max_options_trading_level` is not in `0:3`.
"""
mutable struct MyUpdateAccountConfigurationsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    disable_overnight_trading::Union{Nothing,Bool}
    fractional_trading::Union{Nothing,Bool}
    max_margin_multiplier::Union{Nothing,String}
    max_options_trading_level::Union{Nothing,Int}
    no_shorting::Union{Nothing,Bool}
    ptp_no_exception_entry::Union{Nothing,Bool}
    suspend_trade::Union{Nothing,Bool}
    trade_confirm_email::Union{Nothing,String}

    # methods -
    function MyUpdateAccountConfigurationsEndpointModel(; disable_overnight_trading::Union{Nothing,Bool} = nothing,
        fractional_trading::Union{Nothing,Bool} = nothing, max_margin_multiplier::Union{Nothing,AbstractString,Real} = nothing,
        max_options_trading_level::Union{Nothing,Integer} = nothing, no_shorting::Union{Nothing,Bool} = nothing,
        ptp_no_exception_entry::Union{Nothing,Bool} = nothing, suspend_trade::Union{Nothing,Bool} = nothing,
        trade_confirm_email::Union{Nothing,String} = nothing)

        # the options trading level must be one of the four levels -
        if (max_options_trading_level !== nothing && !(max_options_trading_level in 0:3))
            throw(ArgumentError("`max_options_trading_level` must be an integer in 0:3"));
        end

        # at least one setting must be set -
        if (_none_set((disable_overnight_trading, fractional_trading, max_margin_multiplier, max_options_trading_level,
            no_shorting, ptp_no_exception_entry, suspend_trade, trade_confirm_email)))
            throw(ArgumentError("set at least one account setting"));
        end
        return new(disable_overnight_trading, fractional_trading, _number_text(max_margin_multiplier), max_options_trading_level,
            no_shorting, ptp_no_exception_entry, suspend_trade, trade_confirm_email);
    end
end

"""
    mutable struct MyReplaceOrderEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for replacing an open order with an HTTP PATCH to the Alpaca `/orders/{order_id}` endpoint.
The request holds the order fields that change. The endpoint answers with the replacement order.
Alpaca answers HTTP 422 "pending replacement" when an order is replaced or cancelled before Alpaca has accepted the previous change. Wait and retry.

### Fields
- `id::String`: the identifier of the order to replace.
- `qty::Union{Nothing,String}`: the new quantity, sent as text, or `nothing` to keep it.
- `time_in_force::Union{Nothing,String}`: the new time in force, e.g., `"gtc"`, or `nothing` to keep it.
- `limit_price::Union{Nothing,String}`: the new limit price, sent as text, or `nothing` to keep it.
- `stop_price::Union{Nothing,String}`: the new stop price, sent as text, or `nothing` to keep it.
- `trail::Union{Nothing,String}`: the new trail, sent as text, or `nothing` to keep it.
- `client_order_id::Union{Nothing,String}`: the new order identifier assigned by the client, or `nothing` to keep it.

### Constructors
- `MyReplaceOrderEndpointModel(; id::String, qty = nothing, time_in_force = nothing, limit_price = nothing, stop_price = nothing, trail = nothing, client_order_id = nothing)`: returns a new `MyReplaceOrderEndpointModel` instance.
  The keywords `qty`, `limit_price`, `stop_price`, and `trail` accept a `Real`.
  The constructor throws an `ArgumentError` when no change is set.
"""
mutable struct MyReplaceOrderEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    id::String
    qty::Union{Nothing,String}
    time_in_force::Union{Nothing,String}
    limit_price::Union{Nothing,String}
    stop_price::Union{Nothing,String}
    trail::Union{Nothing,String}
    client_order_id::Union{Nothing,String}

    # methods -
    function MyReplaceOrderEndpointModel(; id::String, qty::Union{Nothing,Real} = nothing, time_in_force::Union{Nothing,String} = nothing,
        limit_price::Union{Nothing,Real} = nothing, stop_price::Union{Nothing,Real} = nothing, trail::Union{Nothing,Real} = nothing,
        client_order_id::Union{Nothing,String} = nothing)

        # at least one change must be set -
        if (_none_set((qty, time_in_force, limit_price, stop_price, trail, client_order_id)))
            throw(ArgumentError("set at least one order change"));
        end
        return new(id, _number_text(qty), time_in_force, _number_text(limit_price), _number_text(stop_price), _number_text(trail),
            client_order_id);
    end
end

"""
    mutable struct MyExerciseOptionEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for exercising an option position with an HTTP POST to the Alpaca `/positions/{symbol_or_contract_id}/exercise` endpoint.
The endpoint answers with no body, so the default handler returns an empty table.

### Fields
- `symbol::String`: the symbol or the contract identifier of the option position.

### Constructors
- `MyExerciseOptionEndpointModel(; symbol::String)`: returns a new `MyExerciseOptionEndpointModel` instance.
"""
mutable struct MyExerciseOptionEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    symbol::String

    # methods -
    MyExerciseOptionEndpointModel(; symbol::String) = new(symbol);
end

"""
    mutable struct MyDoNotExerciseOptionEndpointModel <: AbstractAlpacaTradingEndpointModel

Endpoint model for instructing Alpaca not to exercise an option position with an HTTP POST to the Alpaca `/positions/{symbol_or_contract_id}/do-not-exercise` endpoint.
The endpoint answers with no body, so the default handler returns an empty table.

### Fields
- `symbol::String`: the symbol or the contract identifier of the option position.

### Constructors
- `MyDoNotExerciseOptionEndpointModel(; symbol::String)`: returns a new `MyDoNotExerciseOptionEndpointModel` instance.
"""
mutable struct MyDoNotExerciseOptionEndpointModel <: AbstractAlpacaTradingEndpointModel

    # data -
    symbol::String

    # methods -
    MyDoNotExerciseOptionEndpointModel(; symbol::String) = new(symbol);
end

# _check_global_feed: throws an ArgumentError unless the feed is one of the five feeds for stocks on non-US exchanges -
function _check_global_feed(feed::String)::Nothing

    # the feeds of the Alpaca Stock v3 API -
    allowed = ["euroctp", "xetr", "xhkg", "xlon", "xsau"];
    if (feed in allowed)
        return nothing;
    end
    throw(ArgumentError("feed must be one of $(join(allowed, ", ")), got \"$(feed)\""));
end

"""
    mutable struct MyGlobalStockBarsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/bars` endpoint (Alpaca's "Stock v3" API).
This endpoint returns historical bars of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `timeframe::String`: the width of each bar, e.g., `"1Day"`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`. Alpaca requires this field.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `page_size::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.

### Constructors
- `MyGlobalStockBarsEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)`: returns a new `MyGlobalStockBarsEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockBarsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}
    timeframe::String
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    page_size::Int
    sort::Union{Nothing,String}

    # methods -
    function MyGlobalStockBarsEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols), timeframe, start, finish, page_size, sort);
    end
end

"""
    mutable struct MyGlobalStockQuotesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/quotes` endpoint (Alpaca's "Stock v3" API).
This endpoint returns historical quotes of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`. Alpaca requires this field.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `page_size::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.

### Constructors
- `MyGlobalStockQuotesEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)`: returns a new `MyGlobalStockQuotesEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockQuotesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    page_size::Int
    sort::Union{Nothing,String}

    # methods -
    function MyGlobalStockQuotesEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols), start, finish, page_size, sort);
    end
end

"""
    mutable struct MyGlobalStockTradesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/trades` endpoint (Alpaca's "Stock v3" API).
This endpoint returns historical trades of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{String,Date,DateTime}`: the first time of the request, a `String`, `Date`, or `DateTime`. Alpaca requires this field.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `page_size::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.

### Constructors
- `MyGlobalStockTradesEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)`: returns a new `MyGlobalStockTradesEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockTradesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}
    start::Union{String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    page_size::Int
    sort::Union{Nothing,String}

    # methods -
    function MyGlobalStockTradesEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector}, start::Union{String,Date,DateTime}, finish::Union{Nothing,String,Date,DateTime} = nothing, page_size::Int = 1000, sort::Union{Nothing,String} = nothing)

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols), start, finish, page_size, sort);
    end
end

"""
    mutable struct MyGlobalStockLatestBarsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/latest/bars` endpoint (Alpaca's "Stock v3" API).
This endpoint returns the latest bar of each of several symbols of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyGlobalStockLatestBarsEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector})`: returns a new `MyGlobalStockLatestBarsEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockLatestBarsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}

    # methods -
    function MyGlobalStockLatestBarsEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector})

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols));
    end
end

"""
    mutable struct MyGlobalStockLatestQuotesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/latest/quotes` endpoint (Alpaca's "Stock v3" API).
This endpoint returns the latest quote of each of several symbols of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyGlobalStockLatestQuotesEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector})`: returns a new `MyGlobalStockLatestQuotesEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockLatestQuotesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}

    # methods -
    function MyGlobalStockLatestQuotesEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector})

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols));
    end
end

"""
    mutable struct MyGlobalStockLatestTradesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/latest/trades` endpoint (Alpaca's "Stock v3" API).
This endpoint returns the latest trade of each of several symbols of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyGlobalStockLatestTradesEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector})`: returns a new `MyGlobalStockLatestTradesEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockLatestTradesEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}

    # methods -
    function MyGlobalStockLatestTradesEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector})

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols));
    end
end

"""
    mutable struct MyGlobalStockSnapshotsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

Endpoint model for the Alpaca `/stocks/{feed}/snapshots` endpoint (Alpaca's "Stock v3" API).
This endpoint returns the snapshot of each of several symbols of stocks on non-US exchanges.

### Fields
- `feed::String`: the exchange feed, one of `"euroctp"`, `"xetr"`, `"xhkg"`, `"xlon"`, or `"xsau"`. The URL puts this field in the path.
- `symbols::Vector{String}`: the symbols to request, each in the form `SYMBOL:MIC`, e.g., `"SAP:XETR"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyGlobalStockSnapshotsEndpointModel(; feed::String, symbols::Union{AbstractString,AbstractVector})`: returns a new `MyGlobalStockSnapshotsEndpointModel` instance. The constructor throws an `ArgumentError` when `feed` is not one of the five feeds.
"""
mutable struct MyGlobalStockSnapshotsEndpointModel <: AbstractAlpacaGlobalStockDataEndpointModel

    # data -
    feed::String
    symbols::Vector{String}

    # methods -
    function MyGlobalStockSnapshotsEndpointModel(;
        feed::String, symbols::Union{AbstractString,AbstractVector})

        # check the feed, and build the model -
        _check_global_feed(feed);
        return new(feed, _to_symbol_vector(symbols));
    end
end

# _check_ticktype: throws an ArgumentError unless the tick type is "trade" or "quote" -
function _check_ticktype(ticktype::String)::Nothing

    # the tick types that Alpaca accepts -
    if (ticktype == "trade" || ticktype == "quote")
        return nothing;
    end
    throw(ArgumentError("`ticktype` must be \"trade\" or \"quote\""));
end

"""
    mutable struct MyOptionExchangesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/meta/exchanges` endpoint.
This endpoint returns the map from each option exchange code to the name of the exchange. The model has no fields.

### Fields
- None: the request has no parameters.

### Constructors
- `MyOptionExchangesEndpointModel()`: returns a new `MyOptionExchangesEndpointModel` instance.
"""
mutable struct MyOptionExchangesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # methods -
    MyOptionExchangesEndpointModel() = new();
end

"""
    mutable struct MyOptionConditionsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

Endpoint model for the Alpaca `/options/meta/conditions/{ticktype}` endpoint.
This endpoint returns the map from each option condition code to its name, for the trades or the quotes.

### Fields
- `ticktype::String`: the kind of tick whose condition codes to list, `"trade"` or `"quote"`. The URL carries it in the path.

### Constructors
- `MyOptionConditionsEndpointModel(; ticktype::String = "trade")`: returns a new `MyOptionConditionsEndpointModel` instance.
  The constructor throws an `ArgumentError` unless `ticktype` is `"trade"` or `"quote"`.
"""
mutable struct MyOptionConditionsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # data -
    ticktype::String

    # methods -
    function MyOptionConditionsEndpointModel(; ticktype::String = "trade")

        # check the tick type, and build the model -
        _check_ticktype(ticktype);
        return new(ticktype);
    end
end

# _check_crypto_loc: throws an ArgumentError unless the location is one of the five crypto locations -
function _check_crypto_loc(loc::String)::Nothing

    # the locations of the Alpaca crypto market data API -
    allowed = ["us", "us-1", "us-2", "eu-1", "bs-1"];
    if (loc in allowed)
        return nothing;
    end
    throw(ArgumentError("`loc` must be one of $(join(allowed, ", ")), got \"$(loc)\""));
end

"""
    mutable struct MyCryptoBarsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/bars` endpoint.
This endpoint returns historical bars of crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `timeframe::String`: the width of each bar, e.g., `"1Hour"`.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the request, or `nothing` to leave it to Alpaca.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoBarsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")`: returns a new `MyCryptoBarsEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoBarsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    timeframe::String
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    sort::Union{Nothing,String}
    loc::String

    # methods -
    function MyCryptoBarsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, timeframe::String, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), timeframe, start, finish, limit, sort, loc);
    end
end

"""
    mutable struct MyCryptoQuotesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/quotes` endpoint.
This endpoint returns historical quotes of crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the request, or `nothing` to leave it to Alpaca.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoQuotesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")`: returns a new `MyCryptoQuotesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoQuotesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    sort::Union{Nothing,String}
    loc::String

    # methods -
    function MyCryptoQuotesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), start, finish, limit, sort, loc);
    end
end

"""
    mutable struct MyCryptoTradesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/trades` endpoint.
This endpoint returns historical trades of crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the request, or `nothing` to leave it to Alpaca.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `limit::Int`: the largest number of rows to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoTradesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")`: returns a new `MyCryptoTradesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoTradesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    limit::Int
    sort::Union{Nothing,String}
    loc::String

    # methods -
    function MyCryptoTradesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, limit::Int = 1000, sort::Union{Nothing,String} = nothing, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), start, finish, limit, sort, loc);
    end
end

"""
    mutable struct MyCryptoLatestBarsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/latest/bars` endpoint.
This endpoint returns the latest bar of each of several crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoLatestBarsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, loc::String = "us")`: returns a new `MyCryptoLatestBarsEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoLatestBarsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    loc::String

    # methods -
    function MyCryptoLatestBarsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), loc);
    end
end

"""
    mutable struct MyCryptoLatestQuotesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/latest/quotes` endpoint.
This endpoint returns the latest quote of each of several crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoLatestQuotesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, loc::String = "us")`: returns a new `MyCryptoLatestQuotesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoLatestQuotesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    loc::String

    # methods -
    function MyCryptoLatestQuotesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), loc);
    end
end

"""
    mutable struct MyCryptoLatestTradesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/latest/trades` endpoint.
This endpoint returns the latest trade of each of several crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoLatestTradesEndpointModel(; symbols::Union{AbstractString,AbstractVector}, loc::String = "us")`: returns a new `MyCryptoLatestTradesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoLatestTradesEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    loc::String

    # methods -
    function MyCryptoLatestTradesEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), loc);
    end
end

"""
    mutable struct MyCryptoLatestOrderbooksEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/latest/orderbooks` endpoint.
This endpoint returns the latest order book of each of several crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoLatestOrderbooksEndpointModel(; symbols::Union{AbstractString,AbstractVector}, loc::String = "us")`: returns a new `MyCryptoLatestOrderbooksEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoLatestOrderbooksEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    loc::String

    # methods -
    function MyCryptoLatestOrderbooksEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), loc);
    end
end

"""
    mutable struct MyCryptoSnapshotsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

Endpoint model for the Alpaca `/crypto/{loc}/snapshots` endpoint.
This endpoint returns the snapshot of each of several crypto pairs.

### Fields
- `symbols::Vector{String}`: the crypto pairs to request, e.g., `"BTC/USD"`. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `loc::String`: the crypto location, one of `"us"`, `"us-1"`, `"us-2"`, `"eu-1"`, or `"bs-1"`. The URL puts this field in the path.

### Constructors
- `MyCryptoSnapshotsEndpointModel(; symbols::Union{AbstractString,AbstractVector}, loc::String = "us")`: returns a new `MyCryptoSnapshotsEndpointModel` instance.
  The constructor throws an `ArgumentError` when `loc` is not one of the five locations.
"""
mutable struct MyCryptoSnapshotsEndpointModel <: AbstractAlpacaCryptoDataEndpointModel

    # data -
    symbols::Vector{String}
    loc::String

    # methods -
    function MyCryptoSnapshotsEndpointModel(;
        symbols::Union{AbstractString,AbstractVector}, loc::String = "us")

        # check the location, and build the model -
        _check_crypto_loc(loc);
        return new(_to_symbol_vector(symbols), loc);
    end
end

"""
    mutable struct MyNewsEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/news` endpoint.
This endpoint returns one page of at most 50 news articles. The endpoint is not paginated by `api`, and the default handler drops the `next_page_token` of the response. To get older articles, set `sort = "desc"` and pass the `created_at` of the last row as `finish`. A custom handler can read the `next_page_token` from the response body and pass it as `page_token`.

### Fields
- `symbols::Union{Nothing,Vector{String}}`: the symbols that the articles must mention, or `nothing` for all symbols. The keyword accepts a `String` or a vector of strings.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the request, or `nothing` to leave it open.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `sort::String`: the sort order of the articles by creation time, `"asc"` or `"desc"`.
- `limit::Int`: the largest number of articles to return, at most 50.
- `include_content::Bool`: `true` to include the full content of each article.
- `exclude_contentless::Bool`: `true` to leave out the articles that have no content.
- `page_token::Union{Nothing,String}`: the token of the page to return, or `nothing` for the first page. Only a custom handler can read this token from a response.

### Constructors
- `MyNewsEndpointModel(; symbols = nothing, start = nothing, finish = nothing, sort::String = "desc", limit::Int = 50, include_content::Bool = false, exclude_contentless::Bool = false, page_token::Union{Nothing,String} = nothing)`: returns a new `MyNewsEndpointModel` instance.
"""
mutable struct MyNewsEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    symbols::Union{Nothing,Vector{String}}
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    sort::String
    limit::Int
    include_content::Bool
    exclude_contentless::Bool
    page_token::Union{Nothing,String}

    # methods -
    MyNewsEndpointModel(;
        symbols::Union{Nothing,AbstractString,AbstractVector} = nothing, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, sort::String = "desc", limit::Int = 50, include_content::Bool = false, exclude_contentless::Bool = false, page_token::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), start, finish, sort, limit, include_content, exclude_contentless, page_token);
end

"""
    mutable struct MyMostActivesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/screener/stocks/most-actives` endpoint.
This endpoint returns the most active stocks of the day.

### Fields
- `by::String`: the ranking, `"volume"` or `"trades"`.
- `top::Int`: the number of stocks to return, at most 100.

### Constructors
- `MyMostActivesEndpointModel(; by::String = "volume", top::Int = 10)`: returns a new `MyMostActivesEndpointModel` instance.
  The constructor throws an `ArgumentError` unless `by` is `"volume"` or `"trades"`.
"""
mutable struct MyMostActivesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    by::String
    top::Int

    # methods -
    function MyMostActivesEndpointModel(; by::String = "volume", top::Int = 10)

        # the ranking must be a value that Alpaca accepts -
        if (by != "volume" && by != "trades")
            throw(ArgumentError("`by` must be \"volume\" or \"trades\""));
        end
        return new(by, top);
    end
end

"""
    mutable struct MyMoversEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/screener/{market_type}/movers` endpoint.
This endpoint returns the top gainers and the top losers of the day.

### Fields
- `market_type::String`: the market to screen, `"stocks"` or `"crypto"`. The URL puts this field in the path.
- `top::Int`: the number of gainers and the number of losers to return, at most 50.

### Constructors
- `MyMoversEndpointModel(; market_type::String = "stocks", top::Int = 10)`: returns a new `MyMoversEndpointModel` instance.
  The constructor throws an `ArgumentError` unless `market_type` is `"stocks"` or `"crypto"`.
"""
mutable struct MyMoversEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    market_type::String
    top::Int

    # methods -
    function MyMoversEndpointModel(; market_type::String = "stocks", top::Int = 10)

        # the market type must be a value that Alpaca accepts -
        if (market_type != "stocks" && market_type != "crypto")
            throw(ArgumentError("`market_type` must be \"stocks\" or \"crypto\""));
        end
        return new(market_type, top);
    end
end

"""
    mutable struct MyCorporateActionsEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/v1/corporate-actions` endpoint.
This endpoint returns corporate actions such as cash dividends and splits. Its base URL uses `v1`, not `v1beta1`.

### Fields
- `symbols::Union{Nothing,Vector{String}}`: the symbols to request, or `nothing`. The keyword accepts a `String` or a vector of strings.
- `cusips::Union{Nothing,Vector{String}}`: the CUSIPs to request, or `nothing`. The keyword accepts a `String` or a vector of strings.
- `types::Union{Nothing,Vector{String}}`: the corporate action types to request, e.g., `"cash_dividend"`, or `nothing` for all types. The keyword accepts a `String` or a vector of strings.
- `start::Union{Nothing,String,Date,DateTime}`: the first date of the request, or `nothing` to leave it open.
- `finish::Union{Nothing,String,Date,DateTime}`: the last date of the request, or `nothing` to leave it open. The URL sends this field as `end`.
- `ids::Union{Nothing,Vector{String}}`: the corporate action identifiers to request, or `nothing`. The keyword accepts a `String` or a vector of strings.
- `limit::Int`: the largest number of actions to return per page.
- `sort::Union{Nothing,String}`: the sort order, `"asc"` or `"desc"`, or `nothing` to leave it to Alpaca.
- `region::Union{Nothing,String}`: the region, `"us"`, `"non_us"`, or `"all"`, or `nothing` to leave it to Alpaca.
- `data_quality::Union{Nothing,String}`: `"complete"` or `"all"`, or `nothing` to leave it to Alpaca.

### Constructors
- `MyCorporateActionsEndpointModel(; symbols = nothing, cusips = nothing, types = nothing, start = nothing, finish = nothing, ids = nothing, limit::Int = 100, sort = nothing, region = nothing, data_quality = nothing)`: returns a new `MyCorporateActionsEndpointModel` instance.
"""
mutable struct MyCorporateActionsEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    symbols::Union{Nothing,Vector{String}}
    cusips::Union{Nothing,Vector{String}}
    types::Union{Nothing,Vector{String}}
    start::Union{Nothing,String,Date,DateTime}
    finish::Union{Nothing,String,Date,DateTime}
    ids::Union{Nothing,Vector{String}}
    limit::Int
    sort::Union{Nothing,String}
    region::Union{Nothing,String}
    data_quality::Union{Nothing,String}

    # methods -
    MyCorporateActionsEndpointModel(;
        symbols::Union{Nothing,AbstractString,AbstractVector} = nothing, cusips::Union{Nothing,AbstractString,AbstractVector} = nothing, types::Union{Nothing,AbstractString,AbstractVector} = nothing, start::Union{Nothing,String,Date,DateTime} = nothing, finish::Union{Nothing,String,Date,DateTime} = nothing, ids::Union{Nothing,AbstractString,AbstractVector} = nothing, limit::Int = 100, sort::Union{Nothing,String} = nothing, region::Union{Nothing,String} = nothing, data_quality::Union{Nothing,String} = nothing) = new(_to_symbol_vector(symbols), _to_symbol_vector(cusips), _to_symbol_vector(types), start, finish, _to_symbol_vector(ids), limit, sort, region, data_quality);
end

"""
    mutable struct MyLogoEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/logos/{symbol}` endpoint.
This endpoint returns the logo of a company as a PNG image. It is the one read model whose default handler returns a `Vector{UInt8}` (the bytes of the PNG), not a `DataFrame`.

### Fields
- `symbol::String`: the symbol of the company. The URL puts this field, escaped, in the path.
- `placeholder::Bool`: `true` to get a placeholder image when the company has no logo.

### Constructors
- `MyLogoEndpointModel(; symbol::String, placeholder::Bool = true)`: returns a new `MyLogoEndpointModel` instance.
"""
mutable struct MyLogoEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    symbol::String
    placeholder::Bool

    # methods -
    MyLogoEndpointModel(; symbol::String, placeholder::Bool = true) = new(symbol, placeholder);
end

"""
    mutable struct MyFixedIncomeLatestPricesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/fixed_income/latest/prices` endpoint.
This endpoint returns the latest price and yields of each of several bonds.

### Fields
- `isins::Vector{String}`: the ISINs of the bonds. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.

### Constructors
- `MyFixedIncomeLatestPricesEndpointModel(; isins::Union{AbstractString,AbstractVector})`: returns a new `MyFixedIncomeLatestPricesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `isins` is empty.
"""
mutable struct MyFixedIncomeLatestPricesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    isins::Vector{String}

    # methods -
    function MyFixedIncomeLatestPricesEndpointModel(; isins::Union{AbstractString,AbstractVector})

        # the request needs at least one ISIN -
        isin_vector = _to_symbol_vector(isins);
        if (isempty(isin_vector) == true)
            throw(ArgumentError("`isins` must hold at least one ISIN"));
        end
        return new(isin_vector);
    end
end

"""
    mutable struct MyFixedIncomeLatestQuotesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

Endpoint model for the Alpaca `/fixed_income/latest/quotes` endpoint.
This endpoint returns the latest bid and ask quotes of each of several bonds.

### Fields
- `isins::Vector{String}`: the ISINs of the bonds. The keyword accepts a `String` or a vector of strings, and the model stores a `Vector{String}`.
- `trade_size::Union{Nothing,Int}`: the trade size that the quotes are for, or `nothing` to leave it to Alpaca.

### Constructors
- `MyFixedIncomeLatestQuotesEndpointModel(; isins::Union{AbstractString,AbstractVector}, trade_size::Union{Nothing,Int} = nothing)`: returns a new `MyFixedIncomeLatestQuotesEndpointModel` instance.
  The constructor throws an `ArgumentError` when `isins` is empty.
"""
mutable struct MyFixedIncomeLatestQuotesEndpointModel <: AbstractAlpacaMarketDataEndpointModel

    # data -
    isins::Vector{String}
    trade_size::Union{Nothing,Int}

    # methods -
    function MyFixedIncomeLatestQuotesEndpointModel(; isins::Union{AbstractString,AbstractVector}, trade_size::Union{Nothing,Int} = nothing)

        # the request needs at least one ISIN -
        isin_vector = _to_symbol_vector(isins);
        if (isempty(isin_vector) == true)
            throw(ArgumentError("`isins` must hold at least one ISIN"));
        end
        return new(isin_vector, trade_size);
    end
end
