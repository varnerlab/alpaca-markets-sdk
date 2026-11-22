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

The balances and status of the client's account, from the Alpaca `GET /v2/account` endpoint.
The equity of the account is its cash plus the market value of its long and short positions.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row. The columns are `id`, `account_number`, `status`, `currency`, the money columns `cash`, `buying_power`, `portfolio_value`, `equity`, and `last_equity` (`Float64`), and the `Bool` flags `pattern_day_trader`, `trading_blocked`, `transfers_blocked`, and `account_blocked`. The column `last_equity` is the equity at 16:00 ET on the previous trading day, and `portfolio_value` equals `equity`.

### Example
```julia
account = api(client, MyAccountEndpointModel());
```

### Constructors
- `MyAccountEndpointModel()`: returns a new `MyAccountEndpointModel` instance.
"""
mutable struct MyAccountEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyAccountEndpointModel() = new();
end

"""
    mutable struct MyClockEndpointModel <: AbstractAlpacaTradingEndpointModel

The US market clock, from the Alpaca `GET /v2/clock` endpoint.
The clock says whether the market is open now and when the market next opens and closes.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row. The columns are `timestamp`, the current time, `is_open`, which is `true` when the market is open, `next_open`, and `next_close`. The three times are `DateTime` values in UTC.

### Example
```julia
clock = api(client, MyClockEndpointModel());
```

### Constructors
- `MyClockEndpointModel()`: returns a new `MyClockEndpointModel` instance.
"""
mutable struct MyClockEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyClockEndpointModel() = new();
end

"""
    mutable struct MyPositionsEndpointModel <: AbstractAlpacaTradingEndpointModel

The open positions of the account, from the Alpaca `GET /v2/positions` endpoint. A position is the holding of the account in one asset, long or short.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each open position. The columns give the `symbol`, the `qty`, the `side`, the prices per share, such as `avg_entry_price` and `current_price`, and the dollar values `market_value` and `cost_basis`. The columns `unrealized_pl`, in dollars, and `unrealized_plpc`, as a fraction, give the unrealized profit or loss.

### Example
```julia
positions = api(client, MyPositionsEndpointModel());
```

### Constructors
- `MyPositionsEndpointModel()`: returns a new `MyPositionsEndpointModel` instance.
"""
mutable struct MyPositionsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyPositionsEndpointModel() = new();
end

"""
    mutable struct MyCalendarEndpointModel <: AbstractAlpacaTradingEndpointModel

The trading days of the US market, with their open and close times, from the Alpaca `GET /v2/calendar` endpoint.
The open and close times account for early closures.

### Fields
- `start::Union{Nothing,Date,String}`: the first day of the calendar, included. A `String` is a date, `"YYYY-MM-DD"`. Default `nothing`, which starts the calendar in 1970.
- `finish::Union{Nothing,Date,String}`: the last day of the calendar, included. The URL sends this field as `end`. Default `nothing`, which ends the calendar in 2029.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each trading day. The columns are `date`, `open` and `close`, the times of the regular session, and `session_open` and `session_close`, the times of the extended session. The times are `Time` values, and a day with no extended session has `missing` in the two session columns.

### Example
```julia
model = MyCalendarEndpointModel(start = Date(2026, 12, 1), finish = Date(2026, 12, 31));
days = api(client, model);
```

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

The assets that Alpaca offers for trading and market data, from the Alpaca `GET /v2/assets` endpoint.
An asset is one instrument, such as a US stock or a cryptocurrency, with its symbol and its trading flags.

### Fields
- `status::String`: the status of the assets to list, `"active"` or `"inactive"`. Default `"active"`.
- `asset_class::String`: the asset class to list, e.g., `"us_equity"` (US equities), `"us_option"` (US options), or `"crypto"` (cryptocurrencies). Default `"us_equity"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each asset. The columns are `id`, `class`, `exchange`, `symbol`, `name`, `status`, and the `Bool` flags `tradable` (tradable on Alpaca), `marginable`, `shortable`, `easy_to_borrow`, and `fractionable`. To keep only the tradable assets, filter the `tradable` column.

### Example
```julia
assets = api(client, MyAssetsEndpointModel());
```

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

One asset, by symbol or asset identifier, from the Alpaca `GET /v2/assets/{symbol_or_asset_id}` endpoint.
An asset is one instrument that Alpaca offers, such as a US stock.

### Fields
- `symbol::String`: the symbol, e.g., `"AAPL"`, or the asset identifier, which the URL puts, escaped, in the path. The field also accepts the CUSIP of a US equity. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, with the same columns as `MyAssetsEndpointModel`: `id`, `class`, `exchange`, `symbol`, `name`, `status`, `tradable`, `marginable`, `shortable`, `easy_to_borrow`, and `fractionable`.

### Example
```julia
asset = api(client, MyAssetEndpointModel(symbol = "AAPL"));
```

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

The open position of the account in one asset, from the Alpaca `GET /v2/positions/{symbol_or_asset_id}` endpoint.

### Fields
- `symbol::String`: the symbol of the asset, e.g., `"AAPL"`, `"BTC/USD"`, or the symbol of an option contract. The asset id also works. The URL sends a crypto pair without its slash, as `BTCUSD`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, with the columns of `MyPositionsEndpointModel`.

### Example
```julia
positions = api(client, MyPositionsEndpointModel());
position = api(client, MyPositionEndpointModel(symbol = positions.symbol[1]));
```

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

The orders of the account, filtered by status, submission time, and symbol, from the Alpaca `GET /v2/orders` endpoint.

### Fields
- `status::String`: the orders to read: `"open"`, `"closed"`, or `"all"`. Default `"open"`.
- `limit::Int`: the largest number of orders that Alpaca returns, up to `500`. Default `50`.
- `after::Union{Nothing,String,DateTime}`: the start of the range of submission times, excluded. Default `nothing`, which sets no start.
- `until::Union{Nothing,String,DateTime}`: the end of the range of submission times, excluded. Default `nothing`, which sets no end.
- `direction::String`: the sort direction by submission time: `"asc"`, oldest first, or `"desc"`, newest first. Default `"desc"`.
- `symbols::Union{Nothing,Vector{String}}`: the symbols whose orders to read, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Default `nothing`, which reads the orders of every symbol.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each order. Each multi-leg order is followed by one row for each leg, whose `parent_id` is the `id` of the order. The columns describe the order (`symbol`, `side`, `type`, `status`), its quantities and prices (`qty`, `filled_qty`, `limit_price`, `filled_avg_price`), and its UTC times (`created_at`, `submitted_at`, `filled_at`).

### Example
```julia
orders = api(client, MyOrdersEndpointModel(status = "closed", limit = 10));
```

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

One order of the account, found by its id or by its client order id, from the Alpaca `GET /v2/orders/{order_id}` endpoint, or the `GET /v2/orders:by_client_order_id` endpoint when the model holds a client order id.

### Fields
- `id::Union{Nothing,String}`: the id that Alpaca assigned to the order, e.g., from the `id` column of `MyOrdersEndpointModel`. Default `nothing`.
- `client_order_id::Union{Nothing,String}`: the id that the client gave the order, e.g., with the `client_order_id` keyword of `submit`. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for the order, followed by one row for each leg of a multi-leg order. The columns are those of `MyOrdersEndpointModel`.

### Example
```julia
orders = api(client, MyOrdersEndpointModel(status = "closed", limit = 10));
order = api(client, MyOrderEndpointModel(id = orders.id[1]));
```

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

The option contracts that match the filters, from the Alpaca `GET /v2/options/contracts` endpoint.
Each contract has an underlying symbol, a type, `"call"` or `"put"`, a strike price, and an expiration date.

### Fields
- `underlying_symbols::Vector{String}`: the underlying symbols of the contracts, e.g., `["SPY"]`, sent as one comma-separated list. The keyword also accepts one symbol as a `String`. Required.
- `status::String`: the status of the contracts, `"active"` or `"inactive"`. Default `"active"`.
- `expiration_date::Union{Nothing,Date,String}`: the exact expiration date. A `String` is `"YYYY-MM-DD"`. Default `nothing`.
- `expiration_date_gte::Union{Nothing,Date,String}`: the earliest expiration date, included. Default `nothing`.
- `expiration_date_lte::Union{Nothing,Date,String}`: the latest expiration date, included. Default `nothing`, which Alpaca sets to the next weekend.
- `strike_price_gte::Union{Nothing,Real}`: the lowest strike price, included. Default `nothing`.
- `strike_price_lte::Union{Nothing,Real}`: the highest strike price, included. Default `nothing`.
- `type::Union{Nothing,String}`: the contract type, `"call"` or `"put"`. Default `nothing`, which lists both types.
- `style::Union{Nothing,String}`: the exercise style, `"american"` or `"european"`. Default `nothing`, which lists both styles.
- `limit::Int`: the largest number of contracts on one page, at most `10000`. The call `api` reads every page. Default `1000`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each contract. The columns describe the contract (`id`, `symbol`, `name`, `status`, `tradable`, `expiration_date`, `type`, `style`, `strike_price`), its underlying asset (`root_symbol`, `underlying_symbol`, `underlying_asset_id`), its size (`multiplier` and `size`, both `100` for a standard contract), and its `open_interest` and `close_price`, each with a date column.

### Example
```julia
model = MyOptionContractsEndpointModel(underlying_symbols = "SPY", type = "call",
    expiration_date = Date(2026, 12, 18));
contracts = api(client, model);
```

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

One option contract, by contract symbol or contract identifier, from the Alpaca `GET /v2/options/contracts/{symbol_or_id}` endpoint.

### Fields
- `symbol::String`: the contract symbol, e.g., `"SPY261218C00690000"`, or the contract identifier, which the URL puts in the path. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, with the same columns as `MyOptionContractsEndpointModel`.

### Example
```julia
contract = api(client, MyOptionContractEndpointModel(symbol = "SPY261218C00690000"));
```

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

The price bars of one or more US stocks over a range of times, from the Alpaca `GET /v2/stocks/bars` endpoint.
A bar summarizes the trades of one time interval: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `timeframe::String`: the time interval of each bar: `"1Min"` to `"59Min"`, `"1Hour"` to `"23Hour"`, `"1Day"`, `"1Week"`, or `"1Month"`, `"2Month"`, `"3Month"`, `"4Month"`, `"6Month"`, or `"12Month"`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest bar the account can read.
- `limit::Int`: the largest number of bars on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `adjustment::String`: how the prices are adjusted for corporate actions: `"raw"` (no adjustment), `"split"`, `"dividend"`, `"spin-off"`, or `"all"`. Default `"raw"`.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each bar, sorted by symbol and then by time. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
    start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
bars = api(client, model);
```

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

The quotes of one or more US stocks over a range of times, from the Alpaca `GET /v2/stocks/quotes` endpoint.
A quote is the best bid price and the best ask price for a stock, with the size at each price.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest quote the account can read.
- `limit::Int`: the largest number of quotes on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `feed::String`: the source of the quotes: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each quote, sorted by symbol and then by time. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. The sizes count shares, in round lots before November 3, 2025. The model `MyStockExchangesEndpointModel` names each exchange code.

### Example
```julia
model = MyStockQuotesEndpointModel(symbols = "AAPL", start = DateTime(2026, 11, 20, 15, 0),
    finish = DateTime(2026, 11, 20, 15, 1));
quotes = api(client, model);
```

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

The trades of one or more US stocks over a range of times, from the Alpaca `GET /v2/stocks/trades` endpoint.
A trade is one sale of shares at one price on one exchange.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest trade the account can read.
- `limit::Int`: the largest number of trades on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each trade, sorted by symbol and then by time. The columns are `timestamp` (UTC), `symbol`, `price`, `size` (shares), `exchange` (an exchange code), and `id`, the trade ID that the exchange sent. The model `MyStockExchangesEndpointModel` names each exchange code.

### Example
```julia
model = MyStockTradesEndpointModel(symbols = "AAPL", start = DateTime(2026, 11, 20, 15, 0),
    finish = DateTime(2026, 11, 20, 15, 1));
trades = api(client, model);
```

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

The latest minute bar of one US stock, from the Alpaca `GET /v2/stocks/{symbol}/bars/latest` endpoint.
A minute bar summarizes one minute of trades: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbol::String`: the stock symbol, e.g., `"AAPL"`. The URL puts this field in the path. For several symbols in one call, use `MyStockLatestBarsEndpointModel`. Required.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, the latest bar. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
bar = api(client, MyStockLatestBarEndpointModel(symbol = "AAPL"));
```

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

The latest quote of one US stock, from the Alpaca `GET /v2/stocks/{symbol}/quotes/latest` endpoint.
A quote is the best bid price and the best ask price for a stock, with the size at each price.

### Fields
- `symbol::String`: the stock symbol, e.g., `"AAPL"`. The URL puts this field in the path. For several symbols in one call, use `MyStockLatestQuotesEndpointModel`. Required.
- `feed::String`: the source of the quotes: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, the latest quote. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. The sizes count shares. A price of `0` means that the stock has no active bid or ask. The model `MyStockExchangesEndpointModel` names each exchange code.

### Example
```julia
latest_quote = api(client, MyStockLatestQuoteEndpointModel(symbol = "AAPL"));
```

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

The latest trade of one US stock, from the Alpaca `GET /v2/stocks/{symbol}/trades/latest` endpoint.
A trade is one sale of shares at one price on one exchange.

### Fields
- `symbol::String`: the stock symbol, e.g., `"AAPL"`. The URL puts this field in the path. For several symbols in one call, use `MyStockLatestTradesEndpointModel`. Required.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row, the latest trade. The columns are `timestamp` (UTC), `symbol`, `price`, `size` (shares), `exchange` (an exchange code), and `id`, the trade ID that the exchange sent. Alpaca skips trades whose condition codes keep them out of bar prices.

### Example
```julia
trade = api(client, MyStockLatestTradeEndpointModel(symbol = "AAPL"));
```

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

The latest minute bar of each of several US stocks, from the Alpaca `GET /v2/stocks/bars/latest` endpoint.
A minute bar summarizes one minute of trades: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, as an ISO 4217 code, e.g., `"USD"`. Default `nothing`, which gives the prices in US dollars.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
bars = api(client, MyStockLatestBarsEndpointModel(symbols = ["AAPL", "MSFT"]));
```

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

The latest quote of each of several US stocks, from the Alpaca `GET /v2/stocks/quotes/latest` endpoint.
A quote is the best bid price and the best ask price for a stock, with the size at each price.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `feed::String`: the source of the quotes: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, as an ISO 4217 code, e.g., `"USD"`. Default `nothing`, which gives the prices in US dollars.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. The sizes count shares. A price of `0` means that the stock has no active bid or ask. The model `MyStockExchangesEndpointModel` names each exchange code.

### Example
```julia
quotes = api(client, MyStockLatestQuotesEndpointModel(symbols = ["AAPL", "MSFT"]));
```

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

The latest trade of each of several US stocks, from the Alpaca `GET /v2/stocks/trades/latest` endpoint.
A trade is one sale of shares at one price on one exchange.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `feed::String`: the source of the trades: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.
- `currency::Union{Nothing,String}`: the currency of the prices, as an ISO 4217 code, e.g., `"USD"`. Default `nothing`, which gives the prices in US dollars.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `price`, `size` (shares), `exchange` (an exchange code), and `id`, the trade ID that the exchange sent. Alpaca skips trades whose condition codes keep them out of bar prices.

### Example
```julia
trades = api(client, MyStockLatestTradesEndpointModel(symbols = ["AAPL", "MSFT"]));
```

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

The opening and closing auction prints of US stocks over a range of dates, from the Alpaca `GET /v2/stocks/auctions` endpoint.
An auction print is the price and size of a trade in the opening or closing auction of a day.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Default `nothing`, the beginning of the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest print the account can read.
- `limit::Int`: the largest number of data points on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `feed::String`: the source of the prints. Alpaca accepts only `"sip"`, all US exchanges, for auctions. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"sip"`.
- `sort::Union{Nothing,String}`: the time order of the prints: `"asc"` or `"desc"`. Default `nothing`, which leaves the order to Alpaca.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each auction print. The columns are `timestamp` (UTC), `symbol`, `date` (the trading day), `auction` (`"open"` or `"close"`), `price`, `size` (shares), `exchange` (an exchange code), and `condition` (a condition code). For each symbol and day, the opening prints come before the closing prints.

### Example
```julia
model = MyStockAuctionsEndpointModel(symbols = "AAPL", start = Date(2026, 11, 20),
    finish = Date(2026, 11, 20));
auctions = api(client, model);
```

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

The names of the condition codes of US stock trades or quotes, from the Alpaca `GET /v2/stocks/meta/conditions/{ticktype}` endpoint.
A condition code is a flag on a trade or a quote, e.g., the code `I` marks an odd-lot trade.

### Fields
- `ticktype::String`: whether to list the codes of trades, `"trade"`, or of quotes, `"quote"`. The URL puts this field in the path. Default `"trade"`.
- `tape::String`: the one-character name of the tape whose codes to list: `"A"`, `"B"`, or `"C"`. Default `"A"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each condition code. The columns are `code` and `name`, which describes the condition.

### Example
```julia
conditions = api(client, MyStockConditionsEndpointModel(ticktype = "trade", tape = "A"));
```

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

The name of each exchange code in Alpaca's US stock data, from the Alpaca `GET /v2/stocks/meta/exchanges` endpoint.
The columns `exchange`, `bid_exchange`, and `ask_exchange` of the trade, quote, and auction tables hold these codes.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each exchange code. The columns are `code` and `name`, the name of the exchange.

### Example
```julia
exchanges = api(client, MyStockExchangesEndpointModel());
```

### Constructors
- `MyStockExchangesEndpointModel()`: returns a new `MyStockExchangesEndpointModel` instance.
"""
mutable struct MyStockExchangesEndpointModel <: AbstractAlpacaStockDataEndpointModel

    # methods -
    MyStockExchangesEndpointModel() = new();
end

"""
    mutable struct MyStockSnapshotsEndpointModel <: AbstractAlpacaStockDataEndpointModel

The snapshot of each of several US stocks, from the Alpaca `GET /v2/stocks/snapshots` endpoint.
A snapshot holds the latest trade, the latest quote, the minute bar, the daily bar, and the previous daily bar of one stock.

### Fields
- `symbols::Vector{String}`: the stock symbols, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Required.
- `feed::String`: the source of the data: `"iex"`, the Investors Exchange, or `"sip"`, all US exchanges. Without a market data subscription, Alpaca refuses `"sip"` data from the latest 15 minutes. Default `"iex"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `symbol`, then the columns that start with `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and `prev_daily_bar_`. Each group holds the trade, quote, or bar columns, e.g., `daily_bar_close`. When a snapshot lacks one of its five parts, every column of that group is `missing`.

### Example
```julia
snapshots = api(client, MyStockSnapshotsEndpointModel(symbols = ["AAPL", "MSFT"]));
```

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

The price bars of one or more option contracts over a range of times, from the Alpaca `GET /v1beta1/options/bars` endpoint.
A bar summarizes the trades of one time interval: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbols::Vector{String}`: the option contract symbols: the underlying symbol, the `YYMMDD` expiration date, `C` or `P`, and the strike price times 1000 in 8 digits, e.g., `"SPY261218C00690000"`. The keyword also accepts one symbol as a `String`. Required.
- `timeframe::String`: the time interval of each bar: `"1Min"` to `"59Min"`, `"1Hour"` to `"23Hour"`, `"1Day"`, `"1Week"`, `"1Month"`, `"2Month"`, `"3Month"`, `"4Month"`, `"6Month"`, or `"12Month"`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest bar the account can read.
- `limit::Int`: the largest number of bars on one page, counted across all contracts. The call `api` reads every page. Default `1000`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each bar, sorted by symbol and then by time. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
model = MyOptionBarsEndpointModel(symbols = "SPY261218C00690000", timeframe = "1Day",
    start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
bars = api(client, model);
```

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

The trades of one or more option contracts over a range of times, from the Alpaca `GET /v1beta1/options/trades` endpoint.

### Fields
- `symbols::Vector{String}`: the contracts, each named by an option contract symbol, e.g., `"SPY261218C00690000"`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest trade the account can read.
- `limit::Int`: the largest number of trades on one page, counted across all contracts. The call `api` reads every page. Default `1000`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each trade, sorted by symbol and then by time. The columns are `timestamp` (UTC), `symbol`, `price`, `size`, `exchange`, and `id`.

### Example
```julia
model = MyOptionTradesEndpointModel(symbols = "SPY261218C00690000",
    start = DateTime(2026, 11, 20, 15, 0), finish = DateTime(2026, 11, 20, 16, 0));
trades = api(client, model);
```

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

The latest quote of each of one or more option contracts, from the Alpaca `GET /v1beta1/options/quotes/latest` endpoint.
A quote holds the bid price and the ask price of a contract, with their sizes and exchanges.

### Fields
- `symbols::Vector{String}`: the contracts, each named by an option contract symbol, e.g., `"SPY261218C00690000"`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each contract. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. Without a real-time subscription, the quotes come from Alpaca's free indicative feed, which modifies them.

### Example
```julia
model = MyOptionLatestQuoteEndpointModel(symbols = "SPY261218C00690000");
latest_quote = api(client, model);
```

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

The latest trade of each of one or more option contracts, from the Alpaca `GET /v1beta1/options/trades/latest` endpoint.

### Fields
- `symbols::Vector{String}`: the contracts, each named by an option contract symbol, e.g., `"SPY261218C00690000"`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each contract. The columns are `timestamp` (UTC), `symbol`, `price`, `size`, `exchange`, and `id`. Without a real-time subscription, the trades come from Alpaca's free indicative feed, which delays them.

### Example
```julia
trade = api(client, MyOptionLatestTradeEndpointModel(symbols = "SPY261218C00690000"));
```

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

The snapshots of one or more option contracts, from the Alpaca `GET /v1beta1/options/snapshots` endpoint.
A snapshot holds a contract's latest trade, latest quote, minute and daily bars, implied volatility, and greeks.

### Fields
- `symbols::Vector{String}`: the contracts, each named by an option contract symbol, e.g., `"SPY261218C00690000"`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each contract. After `symbol` come the columns that start with `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and `prev_daily_bar_`, e.g., `latest_quote_bid_price`. Then come `implied_volatility`, `delta`, `gamma`, `theta`, `vega`, and `rho`. Without a real-time subscription, the data come from Alpaca's free indicative feed, which delays trades and modifies quotes.

### Example
```julia
model = MyOptionSnapshotsEndpointModel(
    symbols = ["SPY261218C00690000", "SPY261218P00690000"]);
snapshots = api(client, model);
```

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

The option chain of one underlying stock, from the Alpaca `GET /v1beta1/options/snapshots/{underlying_symbol}` endpoint.
The chain holds a snapshot of each option contract on that stock: its latest trade, latest quote, minute and daily bars, implied volatility, and greeks.

### Fields
- `underlying::String`: the symbol of the underlying stock, e.g., `"SPY"`. The URL puts this field in the path. Required.
- `type::Union{Nothing,String}`: the contract type to keep, `"call"` or `"put"`. Default `nothing`, which keeps calls and puts.
- `strike_price_gte::Union{Nothing,Real}`: the lowest strike price to keep, included. Default `nothing`, which sets no lower bound.
- `strike_price_lte::Union{Nothing,Real}`: the highest strike price to keep, included. Default `nothing`, which sets no upper bound.
- `expiration_date::Union{Nothing,Date,String}`: the one expiration date to keep. A `String` is a date, `"YYYY-MM-DD"`. Default `nothing`, which keeps every expiration date.
- `expiration_date_gte::Union{Nothing,Date,String}`: the earliest expiration date to keep, included. A `String` is a date, `"YYYY-MM-DD"`. Default `nothing`, which sets no lower bound.
- `expiration_date_lte::Union{Nothing,Date,String}`: the latest expiration date to keep, included. A `String` is a date, `"YYYY-MM-DD"`. Default `nothing`, which sets no upper bound.
- `limit::Int`: the largest number of contracts on one page. The call `api` reads every page. Default `1000`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each contract. After `symbol` come the columns that start with `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and `prev_daily_bar_`, e.g., `latest_quote_bid_price`. Then come `implied_volatility`, `delta`, `gamma`, `theta`, `vega`, and `rho`. Without a real-time subscription, the data come from Alpaca's free indicative feed, which delays trades and modifies quotes.

### Example
```julia
model = MyOptionChainEndpointModel(underlying = "SPY", type = "call",
    expiration_date = Date(2026, 12, 18));
chain = api(client, model);
```

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

The trading settings of the client's account, from the Alpaca `GET /v2/account/configurations` endpoint.
The settings control features such as fractional trading, short sales, and overnight trading.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row and one column for each setting that Alpaca sends: `closing_transactions_only`, `disable_overnight_trading`, `fractional_trading`, `max_margin_multiplier`, `no_shorting`, `ptp_no_exception_entry`, `suspend_trade`, and `trade_confirm_email`. The column `max_margin_multiplier` is text, `"1"`, `"2"`, or `"4"`, and `trade_confirm_email` is `"all"` or `"none"`. The other columns are `Bool`.

### Example
```julia
settings = api(client, MyAccountConfigurationsEndpointModel());
```

### Constructors
- `MyAccountConfigurationsEndpointModel()`: returns a new `MyAccountConfigurationsEndpointModel` instance.
"""
mutable struct MyAccountConfigurationsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyAccountConfigurationsEndpointModel() = new();
end

"""
    mutable struct MyAccountActivitiesEndpointModel <: AbstractAlpacaTradingEndpointModel

The activities of the client's account that match the filters, from the Alpaca `GET /v2/account/activities` and `GET /v2/account/activities/{activity_type}` endpoints.
An activity is one entry in the history of the account, such as an order fill or a dividend.

### Fields
- `activity_type::Union{Nothing,String}`: one activity type, e.g., `"FILL"` for order fills, which the URL puts in the path. Default `nothing`.
- `activity_types::Union{Nothing,Vector{String}}`: several activity types, e.g., `["FILL"]`, sent as one comma-separated list. The keyword also accepts one type as a `String`. Default `nothing`.
- `category::Union{Nothing,String}`: the class of activities, `"trade_activity"` or `"non_trade_activity"`. The URL sends this field only when `activity_type` is `nothing`. Default `nothing`.
- `date::Union{Nothing,Date,String}`: the one day of activities to list, by the date Alpaca created each activity. A `String` is `"YYYY-MM-DD"` or `"YYYY-MM-DDTHH:MM:SSZ"`. Default `nothing`.
- `after::Union{Nothing,Date,DateTime,String}`: the time after which the activities were created. A `String` is `"YYYY-MM-DD"` or `"YYYY-MM-DDTHH:MM:SSZ"`. Default `nothing`.
- `until::Union{Nothing,Date,DateTime,String}`: the time before which the activities were created. A `String` is `"YYYY-MM-DD"` or `"YYYY-MM-DDTHH:MM:SSZ"`. Default `nothing`.
- `direction::String`: the order of the rows by activity time, `"asc"` (oldest first) or `"desc"` (newest first). Default `"desc"`.
- `page_size::Int`: the largest number of activities on one page, at most `100`. Default `100`.
- `page_token::Union{Nothing,String}`: the `id` of the last activity of the previous page, which starts the next page. Default `nothing`, which reads the first page.
- `order_id::Union{Nothing,String}`: the identifier of one order, which lists only the activities of that order, e.g., the fills that make up the order. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each activity on one page. A field that an activity lacks is `missing`. A fill has `id`, `activity_type`, `transaction_time` (UTC), `price`, `qty`, `side`, `symbol`, `order_id`, and more, with the quantities and prices as text. Pass the last `id` as `page_token` to read the next page.

### Example
```julia
fills = api(client, MyAccountActivitiesEndpointModel(activity_type = "FILL"));
```

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

The equity and the profit and loss of the client's account over time, from the Alpaca `GET /v2/account/portfolio/history` endpoint.
Each row of the history is one time window, and the profit and loss is measured from a base value.

### Fields
- `period::Union{Nothing,String}`: the length of the history, e.g., `"1M"`, with the unit `D` (day), `W` (week), `M` (month), or `A` (year). Set at most two of `period`, `start`, and `finish`. Default `nothing`, which Alpaca treats as `"1M"`.
- `timeframe::Union{Nothing,String}`: the time between rows, `"1Min"`, `"5Min"`, `"15Min"`, `"1H"`, or `"1D"`. A period longer than 30 days accepts only `"1D"`. Default `nothing`, which picks the time between rows from the period.
- `intraday_reporting::Union{Nothing,String}`: the hours that get rows when `timeframe` is shorter than `"1D"`: `"market_hours"` (core trading hours), `"extended_hours"` (the whole session), or `"continuous"` (around the clock). Default `nothing`, which Alpaca treats as `"market_hours"`.
- `start::Union{Nothing,Date,DateTime,String}`: the first time of the history. Default `nothing`, which starts the history one `period` before `finish`.
- `finish::Union{Nothing,Date,DateTime,String}`: the last time of the history. The URL sends this field as `end`. Default `nothing`, which ends the history one `period` after `start`, or at the latest market open when `start` is also `nothing`.
- `pnl_reset::Union{Nothing,String}`: the base of the profit and loss for a `timeframe` shorter than `"1D"`: `"per_day"` resets the base to the previous closing equity each trading day, and `"no_reset"` does not. Default `nothing`, which means `"per_day"`.
- `extended_hours::Union{Nothing,Bool}`: includes the extended hours when `true` and `timeframe` is shorter than `"1D"`. Alpaca marks this field as deprecated in favor of `intraday_reporting`. Default `nothing`.
- `cashflow_types::Union{Nothing,Vector{String}}`: the cash flow activities to include, `"ALL"`, `"NONE"`, or activity types, sent as one comma-separated list. The keyword also accepts a `String`. The table has no cash flow column. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each time window. The columns are `timestamp`, the start of the window in UTC, `equity`, the equity of the account at the end of the window, `profit_loss`, the dollar change from `base_value`, `profit_loss_pct`, the same change relative to `base_value`, and `base_value`, which is the same in every row.

### Example
```julia
history = api(client, MyPortfolioHistoryEndpointModel(period = "1M", timeframe = "1D"));
```

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

The calendar of one market, from the Alpaca `GET /v3/calendar/{market}` endpoint.
Each calendar day lists the date, the settlement date, and the start and end times of the pre-market, core, and post-market sessions.

### Fields
- `market::String`: the code of the market, e.g., `"NYSE"` (New York Stock Exchange), `"NASDAQ"`, `"OPRA"` (US options), or `"XLON"` (London Stock Exchange). The URL puts this field in the path. Default `"NYSE"`.
- `start::Union{Nothing,Date,DateTime,String}`: the first day of the calendar, included. A `DateTime` sends only its date. Default `nothing`, which Alpaca treats as today.
- `finish::Union{Nothing,Date,DateTime,String}`: the last day of the calendar, included. The URL sends this field as `end`. Default `nothing`, which Alpaca treats as one week after `start`.
- `timezone::Union{Nothing,String}`: the time zone of the session times, `"UTC"`. Default `nothing`, which gives the times in the time zone of the market.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each calendar day. The columns are `market`, the acronym of the market, `core_end`, `core_start`, `date`, `post_end`, `post_start`, `pre_end`, `pre_start`, and `settlement_date`. The columns that start with `core_`, `pre_`, and `post_` hold the times of the three sessions. Every column is text.

### Example
```julia
model = MyMarketCalendarEndpointModel(market = "NYSE", start = Date(2026, 12, 1),
    finish = Date(2026, 12, 31));
days = api(client, model);
```

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

The clocks of several markets around the world, from the Alpaca `GET /v3/clock` endpoint.
A clock says whether today is a market day, which phase the market is in, and when the market next opens and closes.

### Fields
- `markets::Union{Nothing,Vector{String}}`: the codes of the markets, e.g., `["NYSE", "XLON"]`, sent as one comma-separated list. The keyword also accepts one code as a `String`. Default `nothing`.
- `time::Union{Nothing,Date,DateTime,String}`: the time at which to read the clocks, in place of the current time. Default `nothing`, which reads the clocks at the current time.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each market. The columns are `is_market_day`, `market_acronym`, `market_bic`, `market_name`, `market_timezone`, `next_market_close`, `next_market_open`, `phase`, `phase_until`, `timestamp`, and `market_mic`. The column `phase` names the current phase of the market, and the four times are `DateTime` values in UTC.

### Example
```julia
clocks = api(client, MyMarketClocksEndpointModel());
```

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

An order to buy or sell one stock or ETF, by number of shares or by dollar amount. The verbs `submit` and `close` send the order to the Alpaca `POST /v2/orders` endpoint.

### Fields
- `symbol::String`: the symbol of the stock or ETF, e.g., `"SPY"`. Required.
- `side::String`: the side of the trade, `"buy"` or `"sell"`. Required.
- `qty::Union{Nothing,Real}`: the number of shares, which can be fractional. Set exactly one of `qty` and `notional`. Default `nothing`.
- `notional::Union{Nothing,Real}`: the dollar amount to trade, in place of a number of shares. An order set by `notional` cannot be replaced. Default `nothing`.

### Use
The call `submit(client, model)` sends the order and returns an `Order`. The keyword `type` sets the order type: `"market"` (the default), `"limit"`, `"stop"`, `"stop_limit"`, or `"trailing_stop"`. The keywords `limit_price`, `stop_price`, `trail_price`, and `trail_percent` set the prices that the type needs. The call `close(client, model)` sends the same order on the opposite side. See `submit` for the other keywords.

### Example
```julia
model = MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 1);
order = submit(client, model; type = "limit", limit_price = 500.0);
```

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

An order to buy or sell one crypto pair, by number of coins or by dollar amount. The verb `submit` sends the order to the Alpaca `POST /v2/orders` endpoint.

### Fields
- `symbol::String`: the crypto pair, e.g., `"BTC/USD"`. Required.
- `side::String`: the side of the trade, `"buy"` or `"sell"`. Required.
- `qty::Union{Nothing,Real}`: the number of coins, which can be fractional. Set exactly one of `qty` and `notional`. Default `nothing`.
- `notional::Union{Nothing,Real}`: the dollar amount to trade, in place of a number of coins. Default `nothing`.

### Use
The call `submit(client, model)` sends the order and returns an `Order`. The keyword `type` sets the order type: `"market"` (the default), `"limit"`, or `"stop_limit"`. The keywords `limit_price` and `stop_price` set the prices that the type needs. The keyword `time_in_force` is `"gtc"` (the default) or `"ioc"`. The call `close(client, "BTC/USD")` closes the position at market. See `submit` for the other keywords.

### Example
```julia
quotes = api(client, MyCryptoLatestQuotesEndpointModel(symbols = ["BTC/USD"]));
model = MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", qty = 0.001);
order = submit(client, model; type = "limit", limit_price = round(quotes.bid_price[1] / 2));
```

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

One leg of an option order: a contract, a side, and a ratio. The verbs `submit`, `close`, and `roll` send legs to the Alpaca `POST /v2/orders` endpoint, and each verb sets whether a leg opens or closes a position.

### Fields
- `symbol::String`: the symbol of the option contract in OCC format, e.g., `"SPY261218C00690000"`. Required.
- `side::String`: the side of the leg when it opens: `"buy"` (long the contract) or `"sell"` (short the contract). The verb `close` sends the opposite side. Required.
- `ratio::Int`: the number of contracts of this leg in one unit of a structure, a set of legs traded together. An order for `qty` units sends `qty * ratio` contracts. Default `1`.

### Use
The call `submit` opens the legs, `close` closes them, and `roll` closes old legs and opens new legs. Each call returns an `Order`. The keyword `type` sets the order type. For 2 to 4 legs, `limit_price` is the net price of one unit: positive for a debit, negative for a credit. See `submit` for the rest.

### Example
```julia
leg = MyOptionLegModel(symbol = "SPY261218C00690000", side = "buy");
order = submit(client, leg; type = "limit", limit_price = 1.0);
```

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

An order for shares and option legs, e.g., a covered call. Alpaca cannot fill shares and options in one order, so the verbs `submit` and `close` send the model to the Alpaca `POST /v2/orders` endpoint as two orders in sequence.

### Fields
- `equity::MyEquityOrderModel`: the equity order. When a leg sells a call, the equity order must buy, by `qty` and not `notional`, at least 100 shares of the underlying symbol for each call contract. Required.
- `options::Vector{MyOptionLegModel}`: the option legs, from 1 to 4 legs. Required.

### Use
The call `submit` sends the equity order at market, waits for the fill, and then sends the option order. The call `close` reverses the option order first and the equity order second. Both calls return a `Vector{Order}`. The keywords `qty`, `type`, and `limit_price` set the option order, and `close` takes the same `qty` as `submit`. See `submit` for the rest.

### Example
```julia
shares = MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 100);
call = MyOptionLegModel(symbol = "SPY261218C00690000", side = "sell");
orders = submit(client, MyMixedOrderModel(equity = shares, options = [call]);
    limit_price = 100.0);
```

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

The watchlists of the account, without their assets, from the Alpaca `GET /v2/watchlists` endpoint. A watchlist is a named list of assets saved under the account.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each watchlist. The columns are `id`, `account_id`, `created_at` and `updated_at` (UTC), and `name`. An account with no watchlists gets an empty `DataFrame` with no columns.

### Example
```julia
watchlists = api(client, MyWatchlistsEndpointModel());
```

### Constructors
- `MyWatchlistsEndpointModel()`: returns a new `MyWatchlistsEndpointModel` instance.
"""
mutable struct MyWatchlistsEndpointModel <: AbstractAlpacaTradingEndpointModel

    # methods -
    MyWatchlistsEndpointModel() = new();
end

"""
    mutable struct MyWatchlistEndpointModel <: AbstractAlpacaTradingEndpointModel

One watchlist with its assets, found by its id or by its name, from the Alpaca `GET /v2/watchlists/{watchlist_id}` endpoint, or the `GET /v2/watchlists:by_name` endpoint when the model holds a name.

### Fields
- `id::Union{Nothing,String}`: the id that Alpaca assigned to the watchlist, e.g., from the `id` column of `MyWatchlistsEndpointModel`. Default `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, e.g., `"Tech"`. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each asset of the watchlist. The columns are `watchlist_id` and `watchlist_name`, then the columns of `MyAssetsEndpointModel`, such as `symbol`, `name` (the asset name), and `tradable`. A watchlist with no assets gives zero rows. A name that matches no watchlist gets an `AlpacaError` with status 404.

### Example
```julia
watchlist = api(client, MyWatchlistEndpointModel(name = "Tech"));
```

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

Creates a watchlist, a named list of assets saved under the account, through the Alpaca `POST /v2/watchlists` endpoint.

### Fields
- `name::String`: the name of the new watchlist, at most 64 characters, e.g., `"Tech"`. Required.
- `symbols::Vector{String}`: the symbols of the assets that the watchlist starts with, e.g., `["AAPL", "MSFT"]`. The keyword also accepts one symbol as a `String`. Default `String[]`, which creates an empty watchlist.

### Result
The call `api(client, model)` returns a `DataFrame` of the new watchlist, with one row for each asset and the same columns as `MyWatchlistEndpointModel`.

### Example
```julia
model = MyCreateWatchlistEndpointModel(name = "Tech", symbols = ["AAPL", "MSFT"]);
watchlist = api(client, model);
```

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

Renames a watchlist or replaces its assets through the Alpaca `PUT /v2/watchlists/{watchlist_id}` endpoint, or the `PUT /v2/watchlists:by_name` endpoint when the model holds a name.

### Fields
- `id::Union{Nothing,String}`: the id that Alpaca assigned to the watchlist, e.g., from the `watchlist_id` column of `MyWatchlistEndpointModel`. Default `nothing`.
- `name::Union{Nothing,String}`: the current name of the watchlist, e.g., `"Tech"`. Default `nothing`.
- `new_name::Union{Nothing,String}`: the new name of the watchlist, at most 64 characters. The request sends this field as `name`. Default `nothing`, which keeps the name.
- `symbols::Union{Nothing,Vector{String}}`: the symbols that replace the assets of the watchlist. A rename without `symbols` empties the watchlist, so pass the current symbols to keep them. The keyword also accepts one symbol as a `String`. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` of the watchlist after the change, with one row for each asset and the same columns as `MyWatchlistEndpointModel`.

### Example
```julia
model = MyUpdateWatchlistEndpointModel(name = "Tech", new_name = "Favorites",
    symbols = ["AAPL", "MSFT", "NVDA"]);
watchlist = api(client, model);
```

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

Adds one asset to the end of a watchlist through the Alpaca `POST /v2/watchlists/{watchlist_id}` endpoint, or the `POST /v2/watchlists:by_name` endpoint when the model holds a name.

### Fields
- `id::Union{Nothing,String}`: the id that Alpaca assigned to the watchlist, e.g., from the `watchlist_id` column of `MyWatchlistEndpointModel`. Default `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, e.g., `"Tech"`. Default `nothing`.
- `symbol::String`: the symbol of the asset to add, e.g., `"NVDA"`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` of the watchlist after the change, with one row for each asset and the same columns as `MyWatchlistEndpointModel`.

### Example
```julia
watchlist = api(client, MyAddWatchlistAssetEndpointModel(name = "Tech", symbol = "NVDA"));
```

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

Removes one asset from a watchlist through the Alpaca `DELETE /v2/watchlists/{watchlist_id}/{symbol}` endpoint. Alpaca has no by-name form of this endpoint, so the model needs the id of the watchlist.

### Fields
- `id::String`: the id that Alpaca assigned to the watchlist, e.g., from the `watchlist_id` column of `MyWatchlistEndpointModel`. Required.
- `symbol::String`: the symbol of the asset to remove, e.g., `"MSFT"`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` of the watchlist after the change, with one row for each asset and the same columns as `MyWatchlistEndpointModel`.

### Example
```julia
current = api(client, MyWatchlistEndpointModel(name = "Favorites"));
model = MyRemoveWatchlistAssetEndpointModel(id = current.watchlist_id[1], symbol = "MSFT");
watchlist = api(client, model);
```

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

Deletes a watchlist permanently through the Alpaca `DELETE /v2/watchlists/{watchlist_id}` endpoint, or the `DELETE /v2/watchlists:by_name` endpoint when the model holds a name.

### Fields
- `id::Union{Nothing,String}`: the id that Alpaca assigned to the watchlist, e.g., from the `watchlist_id` column of `MyWatchlistEndpointModel`. Default `nothing`.
- `name::Union{Nothing,String}`: the name of the watchlist, e.g., `"Tech"`. Default `nothing`.

### Result
The call `api(client, model)` returns an empty `DataFrame`, because Alpaca answers with no body.

### Example
```julia
result = api(client, MyDeleteWatchlistEndpointModel(name = "Favorites"));
```

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

A change to the trading settings of the client's account, sent to the Alpaca `PATCH /v2/account/configurations` endpoint.
The request holds only the settings that are not `nothing`, and Alpaca keeps the other settings.

### Fields
- `disable_overnight_trading::Union{Nothing,Bool}`: turns overnight trading off when `true` and on when `false`. Default `nothing`, which keeps the setting.
- `fractional_trading::Union{Nothing,Bool}`: turns fractional trading on when `true` and off when `false`. Default `nothing`, which keeps the setting.
- `max_margin_multiplier::Union{Nothing,String}`: the largest buying power multiplier of the account, `"1"`, `"2"`, or `"4"`. The keyword also accepts a `Real`, which the model stores as text. Default `nothing`, which keeps the setting.
- `max_options_trading_level::Union{Nothing,Int}`: the highest options trading level: `0` (disabled), `1` (covered calls and cash-secured puts), `2` (long calls and puts), or `3` (spreads and straddles). Default `nothing`, which keeps the setting.
- `no_shorting::Union{Nothing,Bool}`: blocks short sales when `true`, so the account holds only long positions. Default `nothing`, which keeps the setting.
- `ptp_no_exception_entry::Union{Nothing,Bool}`: accepts orders for publicly traded partnerships without a qualified notice when `true`, and blocks those orders when `false`. Default `nothing`, which keeps the setting.
- `suspend_trade::Union{Nothing,Bool}`: blocks new orders when `true`. Default `nothing`, which keeps the setting.
- `trade_confirm_email::Union{Nothing,String}`: whether Alpaca emails a confirmation of each order fill: `"all"` sends the emails, and `"none"` does not. Default `nothing`, which keeps the setting.

### Result
The call `api(client, model)` sends one PATCH request and returns a `DataFrame` with one row: every setting of the account after the change, with the same columns as `MyAccountConfigurationsEndpointModel`.

### Example
```julia
model = MyUpdateAccountConfigurationsEndpointModel(trade_confirm_email = "none");
settings = api(client, model);
```

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

Replaces an open order with a new order through the Alpaca `PATCH /v2/orders/{order_id}` endpoint. Each field that is set overrides that field of the order, and the other fields stay the same.

### Fields
- `id::String`: the id of the open order to replace, e.g., from the `id` column of `MyOrdersEndpointModel`. Required.
- `qty::Union{Nothing,String}`: the new number of shares, a whole number, sent as text. The keyword also accepts a `Real`. The quantity of a fractional order cannot change. Default `nothing`.
- `time_in_force::Union{Nothing,String}`: the new time in force, which sets how long the order stays live, e.g., `"day"`, one trading day, or `"gtc"`, until canceled. Default `nothing`.
- `limit_price::Union{Nothing,String}`: the new limit price, sent as text. The keyword also accepts a `Real`. For a multi-leg order, a positive price is a debit and a negative price is a credit. Default `nothing`.
- `stop_price::Union{Nothing,String}`: the new stop price, sent as text. The keyword also accepts a `Real`. Default `nothing`.
- `trail::Union{Nothing,String}`: the new trail price or trail percent of a `"trailing_stop"` order, sent as text. The keyword also accepts a `Real`. Default `nothing`.
- `client_order_id::Union{Nothing,String}`: the id that the client gives the new order, at most 128 characters. Default `nothing`, which lets Alpaca generate the id.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for the new order, which has its own `id`, and the columns of `MyOrdersEndpointModel`. Alpaca refuses to replace an order whose status is `"accepted"`, `"pending_new"`, `"pending_cancel"`, or `"pending_replace"`. A change sent before Alpaca has accepted the previous change gets an `AlpacaError` with status 422, "pending replacement". Wait and retry.

### Example
```julia
order = submit(client, MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 1);
    type = "limit", limit_price = 500.0);
model = MyReplaceOrderEndpointModel(id = order.id, limit_price = 495.0);
replacement = api(client, model);
```

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

Exercises an option position through the Alpaca `POST /v2/positions/{symbol_or_contract_id}/exercise` endpoint. Exercise converts every held contract of the option into the underlying asset, on the terms of the contract.

### Fields
- `symbol::String`: the symbol of the option contract, e.g., `"SPY261218C00690000"`. The contract id also works. Required.

### Result
The call `api(client, model)` returns an empty `DataFrame`, because Alpaca answers with no body. Alpaca processes the exercise at once and rejects a request sent between the market close and midnight. An account that does not hold enough of the contract gets an `AlpacaError` with status 403.

### Example
```julia
result = api(client, MyExerciseOptionEndpointModel(symbol = "SPY261218C00690000"));
```

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

Tells Alpaca not to exercise an option position at expiration, through the Alpaca `POST /v2/positions/{symbol_or_contract_id}/do-not-exercise` endpoint. Without this instruction, Alpaca exercises an in-the-money contract at expiration.

### Fields
- `symbol::String`: the symbol of the option contract, e.g., `"SPY261218C00690000"`. The contract id also works. Required.

### Result
The call `api(client, model)` returns an empty `DataFrame`, because Alpaca answers with no body. An account that does not hold the contract gets an `AlpacaError` with status 403.

### Example
```julia
result = api(client, MyDoNotExerciseOptionEndpointModel(symbol = "SPY261218C00690000"));
```

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

The historical price bars of stocks on non-US exchanges, from the Alpaca `GET /v3/stocks/{feed}/bars` endpoint.
A bar summarizes the trades of one time interval: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `feed::String`: the source of the trades: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.
- `timeframe::String`: the time interval of each bar: `"1Min"` to `"59Min"`, `"1Hour"` to `"23Hour"`, `"1Day"`, `"1Week"`, or `"1Month"`, `"2Month"`, `"3Month"`, `"4Month"`, `"6Month"`, or `"12Month"`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A date means midnight in the market's time zone. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. A date means the end of that day in the market's time zone. The URL sends this field as `end`. Default `nothing`, the current time.
- `page_size::Int`: the largest number of bars on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the time order of the bars of each symbol: `"asc"` or `"desc"`. Default `nothing`, which leaves the order to Alpaca.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each bar. The bars of each symbol are in time order. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = ["BMW:XETR", "SAP:XETR"],
    timeframe = "1Day", start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
bars = api(client, model);
```

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

The quotes of stocks on non-US exchanges over a range of times, from the Alpaca `GET /v3/stocks/{feed}/quotes` endpoint.
A quote is the best bid price and the best ask price for a stock, with the size at each price.

### Fields
- `feed::String`: the source of the quotes: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A date means midnight in the market's time zone. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. A date means the end of that day in the market's time zone. The URL sends this field as `end`. Default `nothing`, the current time.
- `page_size::Int`: the largest number of quotes on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the time order of the quotes of each symbol: `"asc"` or `"desc"`. Default `nothing`, which leaves the order to Alpaca.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each quote. The quotes of each symbol are in time order. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockQuotesEndpointModel(feed = "xetr", symbols = "SAP:XETR",
    start = DateTime(2026, 11, 20, 9, 0), finish = DateTime(2026, 11, 20, 9, 1));
quotes = api(client, model);
```

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

The trades of stocks on non-US exchanges over a range of times, from the Alpaca `GET /v3/stocks/{feed}/trades` endpoint.
A trade is one sale of shares at one price on one exchange.

### Fields
- `feed::String`: the source of the trades: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.
- `start::Union{String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A date means midnight in the market's time zone. A `DateTime` is a UTC time. Required.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. A date means the end of that day in the market's time zone. The URL sends this field as `end`. Default `nothing`, the current time.
- `page_size::Int`: the largest number of trades on one page, counted across all symbols, from `1` to `10000`. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the time order of the trades of each symbol: `"asc"` or `"desc"`. Default `nothing`, which leaves the order to Alpaca.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each trade. The trades of each symbol are in time order. The columns are `timestamp` (UTC), `symbol`, `price`, `size`, `exchange`, and `id`, the trade ID. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockTradesEndpointModel(feed = "xetr", symbols = "SAP:XETR",
    start = DateTime(2026, 11, 20, 9, 0), finish = DateTime(2026, 11, 20, 9, 1));
trades = api(client, model);
```

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

The latest minute bar of each of several stocks on non-US exchanges, from the Alpaca `GET /v3/stocks/{feed}/latest/bars` endpoint.
A minute bar summarizes one minute of trades: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `feed::String`: the source of the trades: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockLatestBarsEndpointModel(feed = "xetr",
    symbols = ["BMW:XETR", "SAP:XETR"]);
bars = api(client, model);
```

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

The latest quote of each of several stocks on non-US exchanges, from the Alpaca `GET /v3/stocks/{feed}/latest/quotes` endpoint.
A quote is the best bid price and the best ask price for a stock, with the size at each price.

### Fields
- `feed::String`: the source of the quotes: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockLatestQuotesEndpointModel(feed = "xetr",
    symbols = ["BMW:XETR", "SAP:XETR"]);
quotes = api(client, model);
```

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

The latest trade of each of several stocks on non-US exchanges, from the Alpaca `GET /v3/stocks/{feed}/latest/trades` endpoint.
A trade is one sale of shares at one price on one exchange.

### Fields
- `feed::String`: the source of the trades: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `timestamp` (UTC), `symbol`, `price`, `size`, `exchange`, and `id`, the trade ID. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockLatestTradesEndpointModel(feed = "xetr",
    symbols = ["BMW:XETR", "SAP:XETR"]);
trades = api(client, model);
```

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

The snapshot of each of several stocks on non-US exchanges, from the Alpaca `GET /v3/stocks/{feed}/snapshots` endpoint.
A snapshot holds the latest trade, the latest quote, the minute bar, the daily bar, and the previous daily bar of one stock.

### Fields
- `feed::String`: the source of the data: `"euroctp"` (all EU trading venues), `"xetr"` (Xetra, Frankfurt), `"xhkg"` (Hong Kong Stock Exchange), `"xlon"` (London Stock Exchange), or `"xsau"` (Saudi Exchange). The URL puts this field in the path. Required.
- `symbols::Vector{String}`: the symbols in the form `TICKER:MIC`, where `MIC` is the code of the symbol's primary market, e.g., `["BMW:XETR", "SAP:XETR"]`. The keyword also accepts one symbol as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each symbol. The columns are `symbol`, then the columns that start with `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and `prev_daily_bar_`. Each group holds the trade, quote, or bar columns, e.g., `daily_bar_close`. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
model = MyGlobalStockSnapshotsEndpointModel(feed = "xetr",
    symbols = ["BMW:XETR", "SAP:XETR"]);
snapshots = api(client, model);
```

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

The code and the name of each option exchange, from the Alpaca `GET /v1beta1/options/meta/exchanges` endpoint.

### Fields
This model has no fields.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each exchange. The columns are `code` and `name`. The option trade and quote tables name each exchange by one of these codes.

### Example
```julia
exchanges = api(client, MyOptionExchangesEndpointModel());
```

### Constructors
- `MyOptionExchangesEndpointModel()`: returns a new `MyOptionExchangesEndpointModel` instance.
"""
mutable struct MyOptionExchangesEndpointModel <: AbstractAlpacaOptionDataEndpointModel

    # methods -
    MyOptionExchangesEndpointModel() = new();
end

"""
    mutable struct MyOptionConditionsEndpointModel <: AbstractAlpacaOptionDataEndpointModel

The name of each condition code of option trades or option quotes, from the Alpaca `GET /v1beta1/options/meta/conditions/{ticktype}` endpoint.

### Fields
- `ticktype::String`: whether the call lists the condition codes of trades, `"trade"`, or of quotes, `"quote"`. The URL puts this field in the path. Default `"trade"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each condition code. The columns are `code` and `name`.

### Example
```julia
conditions = api(client, MyOptionConditionsEndpointModel(ticktype = "trade"));
```

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

The price bars of one or more crypto pairs over a range of times, from the Alpaca `GET /v1beta3/crypto/{loc}/bars` endpoint.
A bar summarizes the trades of one time interval: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `timeframe::String`: the time interval of each bar: `"1Min"` to `"59Min"`, `"1Hour"` to `"23Hour"`, `"1Day"`, `"1Week"`, `"1Month"`, `"2Month"`, `"3Month"`, `"4Month"`, `"6Month"`, or `"12Month"`. Required.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Default `nothing`, which starts the range at the beginning of the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest bar the account can read.
- `limit::Int`: the largest number of bars on one page, counted across all pairs. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the order of the rows, `"asc"` (ascending) or `"desc"` (descending). Default `nothing`, which leaves the order to Alpaca.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each bar. The columns are `timestamp` (UTC), `symbol` (the pair), `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
model = MyCryptoBarsEndpointModel(symbols = "BTC/USD", timeframe = "1Hour",
    start = DateTime(2026, 11, 20), finish = DateTime(2026, 11, 21));
bars = api(client, model);
```

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

The quotes of one or more crypto pairs over a range of times, from the Alpaca `GET /v1beta3/crypto/{loc}/quotes` endpoint.
A quote holds the bid price and the ask price of a pair, with their sizes.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Default `nothing`, which starts the range at the beginning of the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest quote the account can read.
- `limit::Int`: the largest number of quotes on one page, counted across all pairs. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the order of the rows, `"asc"` (ascending) or `"desc"` (descending). Default `nothing`, which leaves the order to Alpaca.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each quote. The columns are `timestamp` (UTC), `symbol` (the pair), `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. Alpaca sends no exchange for crypto, so `bid_exchange` and `ask_exchange` are `missing`.

### Example
```julia
model = MyCryptoQuotesEndpointModel(symbols = "BTC/USD",
    start = DateTime(2026, 11, 20, 15, 0), finish = DateTime(2026, 11, 20, 15, 1));
quotes = api(client, model);
```

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

The trades of one or more crypto pairs over a range of times, from the Alpaca `GET /v1beta3/crypto/{loc}/trades` endpoint.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Default `nothing`, which starts the range at the beginning of the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the latest trade the account can read.
- `limit::Int`: the largest number of trades on one page, counted across all pairs. The call `api` reads every page. Default `1000`.
- `sort::Union{Nothing,String}`: the order of the rows, `"asc"` (ascending) or `"desc"` (descending). Default `nothing`, which leaves the order to Alpaca.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each trade. The columns are `timestamp` (UTC), `symbol` (the pair), `price`, `size`, `exchange`, and `id`, a whole number that identifies the trade. Alpaca sends no exchange for crypto, so `exchange` is `missing`.

### Example
```julia
model = MyCryptoTradesEndpointModel(symbols = "BTC/USD",
    start = DateTime(2026, 11, 20, 15, 0), finish = DateTime(2026, 11, 20, 16, 0));
trades = api(client, model);
```

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

The latest minute bar of one or more crypto pairs, from the Alpaca `GET /v1beta3/crypto/{loc}/latest/bars` endpoint.
A bar summarizes the trades of one time interval: the open, high, low, and close prices, the volume, and the number of trades.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each pair. The columns are `timestamp` (UTC), `symbol` (the pair), `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`, the volume-weighted average price.

### Example
```julia
bars = api(client, MyCryptoLatestBarsEndpointModel(symbols = ["BTC/USD", "ETH/USD"]));
```

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

The latest quote of each of one or more crypto pairs, from the Alpaca `GET /v1beta3/crypto/{loc}/latest/quotes` endpoint.
A quote holds the bid price and the ask price of a pair, with their sizes.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each pair. The columns are `timestamp` (UTC), `symbol` (the pair), `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. Alpaca sends no exchange for crypto, so `bid_exchange` and `ask_exchange` are `missing`.

### Example
```julia
quotes = api(client, MyCryptoLatestQuotesEndpointModel(symbols = ["BTC/USD", "ETH/USD"]));
```

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

The latest trade of each of one or more crypto pairs, from the Alpaca `GET /v1beta3/crypto/{loc}/latest/trades` endpoint.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each pair. The columns are `timestamp` (UTC), `symbol` (the pair), `price`, `size`, `exchange`, and `id`, a whole number that identifies the trade. Alpaca sends no exchange for crypto, so `exchange` is `missing`.

### Example
```julia
trades = api(client, MyCryptoLatestTradesEndpointModel(symbols = ["BTC/USD", "ETH/USD"]));
```

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

The latest order book of each of one or more crypto pairs, from the Alpaca `GET /v1beta3/crypto/{loc}/latest/orderbooks` endpoint.
An order book lists the price levels of the bids and of the asks, with the size at each price level.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each price level. The columns are `timestamp` (UTC), `symbol` (the pair), `side`, `price`, and `size`. The column `side` is `"bid"` or `"ask"`. For each pair, the rows list all the bids first and then all the asks, in the order that Alpaca sends them.

### Example
```julia
books = api(client, MyCryptoLatestOrderbooksEndpointModel(symbols = "BTC/USD"));
```

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

The snapshot of each of one or more crypto pairs, from the Alpaca `GET /v1beta3/crypto/{loc}/snapshots` endpoint.
A snapshot holds a pair's latest trade, latest quote, latest minute bar, latest daily bar, and previous daily bar.

### Fields
- `symbols::Vector{String}`: the crypto pairs, e.g., `["BTC/USD", "ETH/USD"]`. The keyword also accepts one pair as a `String`. Required.
- `loc::String`: the crypto location whose market data the call reads: `"us"` (Alpaca US), `"us-1"` (Kraken US), `"us-2"`, `"eu-1"` (Kraken EU), or `"bs-1"`. The URL puts this field in the path. Default `"us"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each pair. After `symbol` come the columns that start with `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and `prev_daily_bar_`, e.g., `daily_bar_close`. The columns of a trade, quote, or bar that Alpaca does not send are `missing`. The timestamps are in UTC.

### Example
```julia
snapshots = api(client, MyCryptoSnapshotsEndpointModel(symbols = ["BTC/USD", "ETH/USD"]));
```

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

News articles about stocks and crypto, from the Alpaca `GET /v1beta1/news` endpoint.
Each article has a headline, a source, a summary, and the symbols that the article mentions.

### Fields
- `symbols::Union{Nothing,Vector{String}}`: the symbols that the articles must mention, e.g., `["AAPL"]`, sent as one comma-separated list. The keyword also accepts one symbol as a `String`. Default `nothing`, which lists articles on all symbols.
- `start::Union{Nothing,String,Date,DateTime}`: the first time of the range, included. A `String` is a date, `"YYYY-MM-DD"`, or an RFC-3339 time. A `DateTime` is a UTC time. Default `nothing`, which starts the range at the beginning of the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last time of the range, included. The URL sends this field as `end`. Default `nothing`, which ends the range at the current time, or 15 minutes earlier without real-time access.
- `sort::String`: the order of the articles by update time, `"asc"` (oldest first) or `"desc"` (newest first). Default `"desc"`.
- `limit::Int`: the largest number of articles in the response, at most `50`. Default `50`.
- `include_content::Bool`: puts the full text of each article in the `content` column when `true`. An article without content has `missing` in that column. Default `false`.
- `exclude_contentless::Bool`: leaves out the articles that have no content when `true`. Default `false`.
- `page_token::Union{Nothing,String}`: the token of the page to read, from the `next_page_token` of a response. Only a custom handler can read that token. Default `nothing`, which reads the first page.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each article. The columns are `id`, `created_at` and `updated_at` (UTC), `headline`, `author`, `source`, `summary`, `url`, `symbols` (joined with commas), and `content`. The call reads one page of at most `limit` articles. To read older articles, set `finish` to an earlier time.

### Example
```julia
news = api(client, MyNewsEndpointModel(symbols = "AAPL", limit = 10));
```

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

The most active stocks of the day, ranked by volume or by number of trades, from the Alpaca `GET /v1beta1/screener/stocks/most-actives` endpoint.
Alpaca ranks the stocks with real-time SIP data, which covers all US exchanges.

### Fields
- `by::String`: the measure that ranks the stocks, `"volume"` or `"trades"`, the number of trades. Default `"volume"`.
- `top::Int`: the number of stocks to return, at most `100`. Default `10`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each stock. The columns are `symbol`, `volume`, and `trade_count`, the number of trades. Both numbers are `Float64`.

### Example
```julia
actives = api(client, MyMostActivesEndpointModel(by = "volume", top = 10));
```

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

The stocks or crypto with the largest price gains and losses, from the Alpaca `GET /v1beta1/screener/{market_type}/movers` endpoint.
The change of each symbol runs from the previous closing price to the latest closing price.

### Fields
- `market_type::String`: the market to screen, `"stocks"` or `"crypto"`, which the URL puts in the path. Default `"stocks"`.
- `top::Int`: the number of gainers and the number of losers to return, at most `50`. Default `10`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each mover, the gainers first and then the losers. The columns are `direction` (`"gainer"` or `"loser"`), `symbol`, `price`, `change`, and `percent_change`. Until the stock market opens, the stock movers are those of the previous market day. The crypto movers reset at midnight.

### Example
```julia
movers = api(client, MyMoversEndpointModel(market_type = "stocks", top = 10));
```

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

The corporate actions of companies, such as cash dividends, splits, mergers, and name changes, from the Alpaca `GET /v1/corporate-actions` endpoint.

### Fields
- `symbols::Union{Nothing,Vector{String}}`: the symbols, e.g., `["AAPL"]`, sent as one comma-separated list. The keyword also accepts one symbol as a `String`. Default `nothing`.
- `cusips::Union{Nothing,Vector{String}}`: the CUSIPs of the securities, sent as one comma-separated list. The keyword also accepts one CUSIP as a `String`. Default `nothing`.
- `types::Union{Nothing,Vector{String}}`: the action types, e.g., `"cash_dividend"`, `"forward_split"`, `"reverse_split"`, or `"spin_off"`, sent as one comma-separated list. The keyword also accepts one type as a `String`. Default `nothing`, which lists all types.
- `start::Union{Nothing,String,Date,DateTime}`: the first date of the range, included. A `String` is `"YYYY-MM-DD"`, and a `DateTime` sends only its date. Default `nothing`, which Alpaca treats as the current day.
- `finish::Union{Nothing,String,Date,DateTime}`: the last date of the range, included. The URL sends this field as `end`. Default `nothing`, which Alpaca treats as the current day.
- `ids::Union{Nothing,Vector{String}}`: the identifiers of the actions, sent as one comma-separated list. Do not combine `ids` with the other filters. The keyword also accepts one identifier as a `String`. Default `nothing`.
- `limit::Int`: the largest number of actions on one page, counted across all symbols. The call `api` reads every page. Default `100`.
- `sort::Union{Nothing,String}`: the order of the actions by process date, `"asc"` or `"desc"`. Default `nothing`, which leaves the order to Alpaca.
- `region::Union{Nothing,String}`: the region of the actions, `"us"`, `"non_us"`, or `"all"`. Default `nothing`, which Alpaca treats as `"us"`.
- `data_quality::Union{Nothing,String}`: the actions to include: `"complete"` leaves out the incomplete actions that Alpaca has not processed yet, and `"all"` keeps those actions. Default `nothing`, which Alpaca treats as `"complete"`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each action. The first column, `type`, is the group of the action, e.g., `"cash_dividends"`. A cash dividend adds `cusip`, `ex_date`, `foreign`, `id`, `payable_date`, `process_date`, `rate`, `record_date`, `special`, and `symbol`, with the dates as text. Other types add their own columns, and a field that an action lacks is `missing`.

### Example
```julia
model = MyCorporateActionsEndpointModel(symbols = "AAPL", start = Date(2026, 1, 1),
    finish = Date(2026, 11, 20));
actions = api(client, model);
```

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

The logo of a company as a PNG image, from the Alpaca `GET /v1beta1/logos/{symbol}` endpoint.

### Fields
- `symbol::String`: the symbol of the company, e.g., `"AAPL"`, which the URL puts, escaped, in the path. Required.
- `placeholder::Bool`: returns a placeholder image when `true` and the company has no logo. Default `true`.

### Result
The call `api(client, model)` returns the PNG image as a `Vector{UInt8}`, the bytes of the response, not a `DataFrame`. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
logo = api(client, MyLogoEndpointModel(symbol = "AAPL"));
```

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

The latest price and yields of one or more bonds, from the Alpaca `GET /v1beta1/fixed_income/latest/prices` endpoint.
Each bond is named by its ISIN, a security identifier such as `"US912797KJ59"`.

### Fields
- `isins::Vector{String}`: the ISINs of the bonds, e.g., `["US912797KJ59"]`, at most `1000`, sent as one comma-separated list. The keyword also accepts one ISIN as a `String`. Required.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each ISIN. The columns are `isin`, `t`, the time of the price in UTC, `p`, the price, `ytm`, the yield to maturity, and `ytw`, the yield to worst. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
prices = api(client, MyFixedIncomeLatestPricesEndpointModel(isins = "US912797KJ59"));
```

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

The latest quotes of one or more bonds, from the Alpaca `GET /v1beta1/fixed_income/latest/quotes` endpoint.
A quote gives the best bid price and the best ask price, with their sizes and yields.

### Fields
- `isins::Vector{String}`: the ISINs of the bonds, e.g., `["US912797KJ59"]`, at most `100`, sent as one comma-separated list. The keyword also accepts one ISIN as a `String`. Required.
- `trade_size::Union{Nothing,Int}`: the cap on the minimum trade size, in par value, of the best bid and ask. A negative value gives the best bid and ask for the smallest trade size. Default `nothing`.

### Result
The call `api(client, model)` returns a `DataFrame` with one row for each ISIN. The columns are `isin`, `t`, the time of the quote in UTC, `bp` and `bs`, the bid price and size, `ap` and `as`, the ask price and size, and the yield columns. A paper account without a market data subscription gets an `AlpacaError` with status 403.

### Example
```julia
quotes = api(client, MyFixedIncomeLatestQuotesEndpointModel(isins = "US912797KJ59"));
```

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
