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

A trading order. Returned by [`submit_order`](@ref), [`get_order`](@ref), and
[`list_orders`](@ref).

Selected fields:

- `id`, `client_order_id`, `symbol`, `asset_class`
- `side` (`"buy"` or `"sell"`), `type`, `time_in_force`, `status`
- `qty`, `filled_qty`, `limit_price`, `stop_price`, `filled_avg_price`
- `created_at`, `submitted_at`, `filled_at` (all `DateTime` in UTC, may be `nothing`)
- `raw` — the original `JSON3.Object` payload
"""
struct Order
    id::String
    client_order_id::String
    symbol::String
    asset_class::String
    side::String
    type::String
    time_in_force::String
    qty::Union{Float64,Nothing}
    filled_qty::Float64
    limit_price::Union{Float64,Nothing}
    stop_price::Union{Float64,Nothing}
    filled_avg_price::Union{Float64,Nothing}
    status::String
    created_at::Union{DateTime,Nothing}
    submitted_at::Union{DateTime,Nothing}
    filled_at::Union{DateTime,Nothing}
    raw::JSON3.Object
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
