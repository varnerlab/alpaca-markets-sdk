# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
# Every function in this file is deprecated. Each one keeps its signature and its return value from v0.3.1, and each
# body does three things: it calls Base.depwarn with the replacement, it builds the endpoint model, and it calls api
# with a legacy handler that returns the legacy value.

"""
    get_account(client::AlpacaClient) -> Account

!!! warning "Deprecated"
    `get_account` is deprecated, use `api(client, MyAccountEndpointModel())` instead.

Fetch the authenticated account summary (cash, equity, buying power, status flags).

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.

### Returns
- An `Account` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_account(client::AlpacaClient)::Account

    # warn that the function is deprecated -
    Base.depwarn("`get_account` is deprecated, use `api(client, MyAccountEndpointModel())` instead", :get_account);

    # build the model, and call api with the legacy handler -
    model = MyAccountEndpointModel();
    return api(client, model; handler = _legacy_handler);
end

"""
    get_clock(client::AlpacaClient) -> MarketClock

!!! warning "Deprecated"
    `get_clock` is deprecated, use `api(client, MyClockEndpointModel())` instead.

Current server time plus whether the US equity market is open, and the next open and close timestamps.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.

### Returns
- A `MarketClock` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_clock(client::AlpacaClient)::MarketClock

    # warn that the function is deprecated -
    Base.depwarn("`get_clock` is deprecated, use `api(client, MyClockEndpointModel())` instead", :get_clock);

    # build the model, and call api with the legacy handler -
    model = MyClockEndpointModel();
    return api(client, model; handler = _legacy_handler);
end

"""
    get_calendar(client::AlpacaClient; start = nothing, finish = nothing) -> Vector{CalendarDay}

!!! warning "Deprecated"
    `get_calendar` is deprecated, use `api(client, MyCalendarEndpointModel(start = ..., finish = ...))` instead.

Trading calendar between `start` and `finish` (inclusive).

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `start::Union{Date,AbstractString,Nothing}`: the first day, a `Date` or an ISO `"YYYY-MM-DD"` string, or `nothing`.
- `finish::Union{Date,AbstractString,Nothing}`: the last day, a `Date` or an ISO `"YYYY-MM-DD"` string, or `nothing`.

### Returns
- A `Vector{CalendarDay}`, one value for each trading day.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_calendar(client::AlpacaClient;
    start::Union{Date,AbstractString,Nothing} = nothing,
    finish::Union{Date,AbstractString,Nothing} = nothing)::Vector{CalendarDay}

    # warn that the function is deprecated -
    Base.depwarn("`get_calendar` is deprecated, use `api(client, MyCalendarEndpointModel(start = ..., finish = ...))` instead", :get_calendar);

    # build the model, and call api with the legacy handler -
    model = MyCalendarEndpointModel(start = _model_value(start), finish = _model_value(finish));
    return api(client, model; handler = _legacy_handler);
end

"""
    list_assets(client::AlpacaClient; status = "active", asset_class = "us_equity", tradable_only = true) -> Vector{Asset}

!!! warning "Deprecated"
    `list_assets` is deprecated, use `api(client, MyAssetsEndpointModel(...))` instead.

List the assets that match a status and an asset class. Alpaca returns ETFs under `us_equity`.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `status::AbstractString`: the status filter.
- `asset_class::AbstractString`: the asset class filter.
- `tradable_only::Bool`: when `true`, the result keeps only the assets that are tradable.

### Returns
- A `Vector{Asset}`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function list_assets(client::AlpacaClient;
    status::AbstractString = "active",
    asset_class::AbstractString = "us_equity",
    tradable_only::Bool = true)::Vector{Asset}

    # warn that the function is deprecated -
    Base.depwarn("`list_assets` is deprecated, use `api(client, MyAssetsEndpointModel(...))` instead", :list_assets);

    # build the model, and call api with the legacy handler -
    model = MyAssetsEndpointModel(status = String(status), asset_class = String(asset_class));
    all_assets = api(client, model; handler = _legacy_handler);

    # keep the tradable assets only when the caller asks for them -
    assets = Asset[];
    for asset in all_assets
        if (tradable_only == true && asset.tradable == false)
            continue;
        end
        push!(assets, asset);
    end
    return assets;
end

"""
    get_asset(client::AlpacaClient, symbol_or_id::AbstractString) -> Asset

!!! warning "Deprecated"
    `get_asset` is deprecated, use `api(client, MyAssetEndpointModel(symbol = ...))` instead.

Look up one asset by symbol (e.g., `"AAPL"`) or by asset UUID.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol_or_id::AbstractString`: the symbol or the asset UUID.

### Returns
- An `Asset` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_asset(client::AlpacaClient, symbol_or_id::AbstractString)::Asset

    # warn that the function is deprecated -
    Base.depwarn("`get_asset` is deprecated, use `api(client, MyAssetEndpointModel(symbol = ...))` instead", :get_asset);

    # build the model, and call api with the legacy handler -
    model = MyAssetEndpointModel(symbol = String(symbol_or_id));
    return api(client, model; handler = _legacy_handler);
end

"""
    list_positions(client::AlpacaClient) -> Vector{Position}

!!! warning "Deprecated"
    `list_positions` is deprecated, use `api(client, MyPositionsEndpointModel())` instead.

List the open positions of the account.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.

### Returns
- A `Vector{Position}`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function list_positions(client::AlpacaClient)::Vector{Position}

    # warn that the function is deprecated -
    Base.depwarn("`list_positions` is deprecated, use `api(client, MyPositionsEndpointModel())` instead", :list_positions);

    # build the model, and call api with the legacy handler -
    model = MyPositionsEndpointModel();
    return api(client, model; handler = _legacy_handler);
end

"""
    get_position(client::AlpacaClient, symbol_or_asset_id::AbstractString) -> Position

!!! warning "Deprecated"
    `get_position` is deprecated, use `api(client, MyPositionEndpointModel(symbol = ...))` instead.

Look up the open position of one symbol or asset UUID.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol_or_asset_id::AbstractString`: the symbol or the asset UUID.

### Returns
- A `Position` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_position(client::AlpacaClient, symbol_or_asset_id::AbstractString)::Position

    # warn that the function is deprecated -
    Base.depwarn("`get_position` is deprecated, use `api(client, MyPositionEndpointModel(symbol = ...))` instead", :get_position);

    # build the model, and call api with the legacy handler -
    model = MyPositionEndpointModel(symbol = String(symbol_or_asset_id));
    return api(client, model; handler = _legacy_handler);
end

"""
    list_orders(client::AlpacaClient; status = "open", limit = 50, after = nothing, until = nothing,
        direction = "desc", symbols = nothing) -> Vector{Order}

!!! warning "Deprecated"
    `list_orders` is deprecated, use `api(client, MyOrdersEndpointModel(...))` instead.

List the orders of the account. The request returns one page of orders.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `status::AbstractString`: `"open"`, `"closed"`, or `"all"`.
- `limit::Integer`: the largest number of orders to return.
- `after::Union{AbstractString,DateTime,Nothing}`: return only orders submitted after this time.
- `until::Union{AbstractString,DateTime,Nothing}`: return only orders submitted until this time.
- `direction::AbstractString`: the sort direction, `"asc"` or `"desc"`.
- `symbols::Union{AbstractVector,AbstractString,Nothing}`: a vector of symbols or a comma-separated string.

### Returns
- A `Vector{Order}`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function list_orders(client::AlpacaClient;
    status::AbstractString = "open",
    limit::Integer = 50,
    after::Union{AbstractString,DateTime,Nothing} = nothing,
    until::Union{AbstractString,DateTime,Nothing} = nothing,
    direction::AbstractString = "desc",
    symbols::Union{AbstractVector,AbstractString,Nothing} = nothing)::Vector{Order}

    # warn that the function is deprecated -
    Base.depwarn("`list_orders` is deprecated, use `api(client, MyOrdersEndpointModel(...))` instead", :list_orders);

    # build the model, and call api with the legacy handler -
    model = MyOrdersEndpointModel(status = String(status), limit = Int(limit), after = _model_value(after),
        until = _model_value(until), direction = String(direction), symbols = _model_value(symbols));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_order(client::AlpacaClient, order_id::AbstractString; by_client_order_id = false) -> Order

!!! warning "Deprecated"
    `get_order` is deprecated, use `api(client, MyOrderEndpointModel(...))` instead.

Look up one order by its Alpaca order identifier, or by its client order identifier.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `order_id::AbstractString`: the order identifier.
- `by_client_order_id::Bool`: when `true`, `order_id` is a client order identifier.

### Returns
- An `Order` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_order(client::AlpacaClient, order_id::AbstractString;
    by_client_order_id::Bool = false)::Order

    # warn that the function is deprecated -
    Base.depwarn("`get_order` is deprecated, use `api(client, MyOrderEndpointModel(...))` instead", :get_order);

    # the identifier is either the client order identifier or the Alpaca order identifier -
    model = nothing;
    if (by_client_order_id == true)
        model = MyOrderEndpointModel(client_order_id = String(order_id));
    else
        model = MyOrderEndpointModel(id = String(order_id));
    end

    # call api with the legacy handler -
    return api(client, model; handler = _legacy_handler);
end

"""
    list_option_contracts(client::AlpacaClient; underlying_symbols, status = "active", expiration_date = nothing,
        expiration_date_gte = nothing, expiration_date_lte = nothing, strike_price_gte = nothing,
        strike_price_lte = nothing, type = nothing, style = nothing, limit = 1000) -> Vector{OptionContract}

!!! warning "Deprecated"
    `list_option_contracts` is deprecated, use `api(client, MyOptionContractsEndpointModel(...))` instead.

Enumerate the contracts of one or more underlyings, optionally filtered by expiration window, strike range,
call or put, or exercise style. The request follows `next_page_token` and returns the contracts of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `underlying_symbols::Union{AbstractString,AbstractVector}`: the underlying symbols, a vector or a comma-separated string.
- `status::AbstractString`: the status filter.
- `expiration_date::Union{AbstractString,Date,Nothing}`: the exact expiration date to match.
- `expiration_date_gte::Union{AbstractString,Date,Nothing}`: the earliest expiration date to match.
- `expiration_date_lte::Union{AbstractString,Date,Nothing}`: the latest expiration date to match.
- `strike_price_gte::Union{Real,Nothing}`: the lowest strike price to match.
- `strike_price_lte::Union{Real,Nothing}`: the highest strike price to match.
- `type::Union{AbstractString,Nothing}`: `"call"` or `"put"`.
- `style::Union{AbstractString,Nothing}`: `"american"` or `"european"`.
- `limit::Integer`: the largest number of contracts to return per page.

### Returns
- A `Vector{OptionContract}`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function list_option_contracts(client::AlpacaClient;
    underlying_symbols::Union{AbstractString,AbstractVector},
    status::AbstractString = "active",
    expiration_date::Union{AbstractString,Date,Nothing} = nothing,
    expiration_date_gte::Union{AbstractString,Date,Nothing} = nothing,
    expiration_date_lte::Union{AbstractString,Date,Nothing} = nothing,
    strike_price_gte::Union{Real,Nothing} = nothing,
    strike_price_lte::Union{Real,Nothing} = nothing,
    type::Union{AbstractString,Nothing} = nothing,
    style::Union{AbstractString,Nothing} = nothing,
    limit::Integer = 1_000)::Vector{OptionContract}

    # warn that the function is deprecated -
    Base.depwarn("`list_option_contracts` is deprecated, use `api(client, MyOptionContractsEndpointModel(...))` instead", :list_option_contracts);

    # build the model, and call api with the legacy handler -
    model = MyOptionContractsEndpointModel(underlying_symbols = _model_value(underlying_symbols), status = String(status),
        expiration_date = _model_value(expiration_date), expiration_date_gte = _model_value(expiration_date_gte),
        expiration_date_lte = _model_value(expiration_date_lte), strike_price_gte = strike_price_gte,
        strike_price_lte = strike_price_lte, type = _model_value(type), style = _model_value(style), limit = Int(limit));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_option_contract(client::AlpacaClient, symbol_or_id::AbstractString) -> OptionContract

!!! warning "Deprecated"
    `get_option_contract` is deprecated, use `api(client, MyOptionContractEndpointModel(symbol = ...))` instead.

Fetch one option contract by OCC symbol (e.g., `"AAPL260117C00150000"`) or by Alpaca contract UUID.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol_or_id::AbstractString`: the OCC symbol or the contract UUID.

### Returns
- An `OptionContract` value.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_contract(client::AlpacaClient, symbol_or_id::AbstractString)::OptionContract

    # warn that the function is deprecated -
    Base.depwarn("`get_option_contract` is deprecated, use `api(client, MyOptionContractEndpointModel(symbol = ...))` instead", :get_option_contract);

    # build the model, and call api with the legacy handler -
    model = MyOptionContractEndpointModel(symbol = String(symbol_or_id));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_bars(client::AlpacaClient, symbols, timeframe::AbstractString; start, finish = nothing, limit = 1000,
        adjustment = "raw", feed = "iex") -> Dict{String,Vector{Bar}}

!!! warning "Deprecated"
    `get_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead.

Fetch historical OHLCV bars. The request follows `next_page_token` and returns the bars of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: a symbol or a vector of symbols.
- `timeframe::AbstractString`: the width of each bar, e.g., `"1Min"`, `"5Min"`, `"15Min"`, `"1Hour"`, or `"1Day"`.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of bars to return per page.
- `adjustment::AbstractString`: the corporate action adjustment of the prices.
- `feed::AbstractString`: the market data feed. The default `"iex"` is free, and `"sip"` needs a data subscription.

### Returns
- A `Dict{String,Vector{Bar}}` keyed by symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_bars(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector}, timeframe::AbstractString;
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1000,
    adjustment::AbstractString = "raw",
    feed::AbstractString = "iex")::Dict{String,Vector{Bar}}

    # warn that the function is deprecated -
    Base.depwarn("`get_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead", :get_bars);

    # build the model, and call api with the legacy handler -
    model = MyStockBarsEndpointModel(symbols = _model_value(symbols), timeframe = String(timeframe),
        start = _model_value(start), finish = _model_value(finish), limit = Int(limit),
        adjustment = String(adjustment), feed = String(feed));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_quotes(client::AlpacaClient, symbols; start, finish = nothing, limit = 1000, feed = "iex") -> Dict{String,Vector{Quote}}

!!! warning "Deprecated"
    `get_quotes` is deprecated, use `api(client, MyStockQuotesEndpointModel(...))` instead.

Fetch historical quotes. The request follows `next_page_token` and returns the quotes of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: a symbol or a vector of symbols.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of quotes to return per page.
- `feed::AbstractString`: the market data feed.

### Returns
- A `Dict{String,Vector{Quote}}` keyed by symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_quotes(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector};
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1000,
    feed::AbstractString = "iex")::Dict{String,Vector{Quote}}

    # warn that the function is deprecated -
    Base.depwarn("`get_quotes` is deprecated, use `api(client, MyStockQuotesEndpointModel(...))` instead", :get_quotes);

    # build the model, and call api with the legacy handler -
    model = MyStockQuotesEndpointModel(symbols = _model_value(symbols), start = _model_value(start),
        finish = _model_value(finish), limit = Int(limit), feed = String(feed));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_trades(client::AlpacaClient, symbols; start, finish = nothing, limit = 1000, feed = "iex") -> Dict{String,Vector{Trade}}

!!! warning "Deprecated"
    `get_trades` is deprecated, use `api(client, MyStockTradesEndpointModel(...))` instead.

Fetch historical trades. The request follows `next_page_token` and returns the trades of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: a symbol or a vector of symbols.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of trades to return per page.
- `feed::AbstractString`: the market data feed.

### Returns
- A `Dict{String,Vector{Trade}}` keyed by symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_trades(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector};
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1000,
    feed::AbstractString = "iex")::Dict{String,Vector{Trade}}

    # warn that the function is deprecated -
    Base.depwarn("`get_trades` is deprecated, use `api(client, MyStockTradesEndpointModel(...))` instead", :get_trades);

    # build the model, and call api with the legacy handler -
    model = MyStockTradesEndpointModel(symbols = _model_value(symbols), start = _model_value(start),
        finish = _model_value(finish), limit = Int(limit), feed = String(feed));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_latest_bar(client::AlpacaClient, symbol::AbstractString; feed = "iex") -> Bar

!!! warning "Deprecated"
    `get_latest_bar` is deprecated, use `api(client, MyStockLatestBarEndpointModel(...))` instead.

Fetch the latest bar of one symbol.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::AbstractString`: the symbol.
- `feed::AbstractString`: the market data feed.

### Returns
- A `Bar` value. The `symbol` argument fills the `symbol` field.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_bar(client::AlpacaClient, symbol::AbstractString; feed::AbstractString = "iex")::Bar

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_bar` is deprecated, use `api(client, MyStockLatestBarEndpointModel(...))` instead", :get_latest_bar);

    # build the model, and call api with the legacy handler -
    model = MyStockLatestBarEndpointModel(symbol = String(symbol), feed = String(feed));
    value = api(client, model; handler = _legacy_handler);
    return _parse_bar(symbol, value.bar);
end

"""
    get_latest_quote(client::AlpacaClient, symbol::AbstractString; feed = "iex") -> Quote

!!! warning "Deprecated"
    `get_latest_quote` is deprecated, use `api(client, MyStockLatestQuoteEndpointModel(...))` instead.

Fetch the latest quote of one symbol.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::AbstractString`: the symbol.
- `feed::AbstractString`: the market data feed.

### Returns
- A `Quote` value. The `symbol` argument fills the `symbol` field.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_quote(client::AlpacaClient, symbol::AbstractString; feed::AbstractString = "iex")::Quote

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_quote` is deprecated, use `api(client, MyStockLatestQuoteEndpointModel(...))` instead", :get_latest_quote);

    # build the model, and call api with the legacy handler -
    model = MyStockLatestQuoteEndpointModel(symbol = String(symbol), feed = String(feed));
    value = api(client, model; handler = _legacy_handler);
    return _parse_quote(symbol, value.quote);
end

"""
    get_latest_trade(client::AlpacaClient, symbol::AbstractString; feed = "iex") -> Trade

!!! warning "Deprecated"
    `get_latest_trade` is deprecated, use `api(client, MyStockLatestTradeEndpointModel(...))` instead.

Fetch the latest trade of one symbol.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::AbstractString`: the symbol.
- `feed::AbstractString`: the market data feed.

### Returns
- A `Trade` value. The `symbol` argument fills the `symbol` field.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_trade(client::AlpacaClient, symbol::AbstractString; feed::AbstractString = "iex")::Trade

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_trade` is deprecated, use `api(client, MyStockLatestTradeEndpointModel(...))` instead", :get_latest_trade);

    # build the model, and call api with the legacy handler -
    model = MyStockLatestTradeEndpointModel(symbol = String(symbol), feed = String(feed));
    value = api(client, model; handler = _legacy_handler);
    return _parse_trade(symbol, value.trade);
end

"""
    get_snapshot(client::AlpacaClient, symbols; feed = "iex")

!!! warning "Deprecated"
    `get_snapshot` is deprecated, use `api(client, MyStockSnapshotsEndpointModel(...))` instead.

Snapshot of the latest trade, latest quote, minute bar, daily bar, and previous daily bar of each symbol.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: a symbol or a vector of symbols.
- `feed::AbstractString`: the market data feed.

### Returns
- The parsed `JSON3` value of the response, keyed by symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_snapshot(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector}; feed::AbstractString = "iex")

    # warn that the function is deprecated -
    Base.depwarn("`get_snapshot` is deprecated, use `api(client, MyStockSnapshotsEndpointModel(...))` instead", :get_snapshot);

    # build the model, and call api with the legacy handler -
    model = MyStockSnapshotsEndpointModel(symbols = _model_value(symbols), feed = String(feed));
    return api(client, model; handler = _legacy_handler);
end

"""
    write_bars_csv(path::AbstractString, bars::AbstractVector{Bar}) -> AbstractString

!!! warning "Deprecated"
    `write_bars_csv` has no replacement, write the bars `DataFrame` with a CSV package instead.

Write a vector of `Bar` values to `path` as CSV. The file has a header row and one data row for each bar:

```
timestamp,symbol,open,high,low,close,volume,trade_count,vwap
```

Timestamps are written as UTC ISO-8601 without the trailing `Z`. A missing `trade_count` or `vwap` is an empty value.

### Arguments
- `path::AbstractString`: the path of the CSV file. The function creates the missing directories.
- `bars::AbstractVector{Bar}`: the bars to write.

### Returns
- The `path` argument.

### Throws
- A system error when the file cannot be opened or written.
"""
function write_bars_csv(path::AbstractString, bars::AbstractVector{Bar})

    # warn that the function is deprecated -
    Base.depwarn("`write_bars_csv` is deprecated, write the bars `DataFrame` with a CSV package instead", :write_bars_csv);

    # write the file -
    return _write_bars_csv(path, bars);
end

"""
    read_bars_csv(path::AbstractString) -> Vector{Bar}

!!! warning "Deprecated"
    `read_bars_csv` has no replacement, read the CSV file with a CSV package instead.

Parse a CSV file written by `write_bars_csv` back into a vector of `Bar` values.

### Arguments
- `path::AbstractString`: the path of the CSV file.

### Returns
- A `Vector{Bar}`, one value for each data row.

### Throws
- A system error when the file cannot be read.
"""
function read_bars_csv(path::AbstractString)

    # warn that the function is deprecated -
    Base.depwarn("`read_bars_csv` is deprecated, read the CSV file with a CSV package instead", :read_bars_csv);

    # an empty file has no bars -
    lines = readlines(path);
    bars = Bar[];
    if (isempty(lines) == true)
        return bars;
    end

    # parse each data row, and skip the header row and the empty lines -
    sizehint!(bars, length(lines) - 1);
    for index in 2:length(lines)
        line = lines[index];
        if (isempty(line) == true)
            continue;
        end
        fields = split(line, ',');

        # the trade count and the volume weighted price can be empty -
        trade_count = nothing;
        if (isempty(fields[8]) == false)
            trade_count = parse(Int, fields[8]);
        end
        vwap = nothing;
        if (isempty(fields[9]) == false)
            vwap = parse(Float64, fields[9]);
        end
        push!(bars, Bar(
            String(fields[2]),
            DateTime(String(fields[1])),
            parse(Float64, fields[3]),
            parse(Float64, fields[4]),
            parse(Float64, fields[5]),
            parse(Float64, fields[6]),
            parse(Float64, fields[7]),
            trade_count,
            vwap,
        ));
    end
    return bars;
end

"""
    download_bars(client::AlpacaClient, symbols, timeframe::AbstractString; start, finish = nothing, limit = 10_000,
        adjustment = "raw", feed = "iex", save_dir = nothing, chunk_months = nothing, verbose = false) -> Dict{String,Vector{Bar}}

!!! warning "Deprecated"
    `download_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead, which follows every page.

Bulk historical bar download. The arguments mirror `get_bars`, with three extras: `save_dir`, `chunk_months`, and `verbose`.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: a symbol or a vector of symbols.
- `timeframe::AbstractString`: the width of each bar, e.g., `"1Min"`, `"1Day"`, or `"1Week"`.
- `start`: the first time of the request.
- `finish`: the last time of the request, or `nothing` to leave it open. The `chunk_months` argument needs a `finish`.
- `limit::Integer`: the largest number of bars to return per page.
- `adjustment::AbstractString`: the corporate action adjustment of the prices.
- `feed::AbstractString`: the market data feed.
- `save_dir::Union{AbstractString,Nothing}`: when set, the function writes each symbol to `<save_dir>/<symbol>_<timeframe>.csv`.
- `chunk_months::Union{Integer,Nothing}`: when set, the function splits `start` to `finish` into windows of this many months and fetches each window separately.
- `verbose::Bool`: when `true`, the function prints the status of each chunk.

### Returns
- A `Dict{String,Vector{Bar}}` keyed by symbol.

### Throws
- `ArgumentError`: when `chunk_months` is set and `finish` is `nothing`, or when `chunk_months` is not positive.
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function download_bars(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector}, timeframe::AbstractString;
    start,
    finish = nothing,
    limit::Integer = 10_000,
    adjustment::AbstractString = "raw",
    feed::AbstractString = "iex",
    save_dir::Union{AbstractString,Nothing} = nothing,
    chunk_months::Union{Integer,Nothing} = nothing,
    verbose::Bool = false)::Dict{String,Vector{Bar}}

    # warn that the function is deprecated -
    Base.depwarn("`download_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead", :download_bars);

    # without chunks, one request covers start to finish -
    result = Dict{String,Vector{Bar}}();
    if (chunk_months === nothing)
        if (verbose == true)
            println("[download_bars] ", _symbols_desc(symbols), " ", timeframe, " ", start, " → ", finish);
        end
        model = MyStockBarsEndpointModel(symbols = _model_value(symbols), timeframe = String(timeframe),
            start = _model_value(start), finish = _model_value(finish), limit = Int(limit),
            adjustment = String(adjustment), feed = String(feed));
        result = api(client, model; handler = _legacy_handler);
    else

        # chunks need an explicit finish -
        if (finish === nothing)
            throw(ArgumentError("chunk_months requires an explicit `finish`"));
        end

        # fetch each chunk, and collect the bars of each symbol in chunk order -
        chunks = _month_chunks(start, finish, chunk_months);
        total = length(chunks);
        for (index, chunk) in enumerate(chunks)
            if (verbose == true)
                println("[download_bars $(index)/$(total)] ", _symbols_desc(symbols), " ", timeframe, " ",
                    chunk[1], " → ", chunk[2]);
            end
            model = MyStockBarsEndpointModel(symbols = _model_value(symbols), timeframe = String(timeframe),
                start = _model_value(chunk[1]), finish = _model_value(chunk[2]), limit = Int(limit),
                adjustment = String(adjustment), feed = String(feed));
            part = api(client, model; handler = _legacy_handler);
            for (symbol, rows) in part
                bucket = get!(result, String(symbol), Bar[]);
                append!(bucket, rows);
            end
        end
    end

    # print the totals -
    if (verbose == true)
        bar_count = 0;
        for rows in values(result)
            bar_count += length(rows);
        end
        println("[download_bars] done: ", bar_count, " bars across ", length(result), " symbol(s)");
    end

    # write one CSV file for each symbol -
    if (save_dir !== nothing)
        mkpath(save_dir);
        timeframe_tag = replace(timeframe, " " => "");
        for (symbol, rows) in result
            path = joinpath(save_dir, "$(symbol)_$(timeframe_tag).csv");
            _write_bars_csv(path, rows);
            if (verbose == true)
                println("[download_bars] wrote ", length(rows), " rows → ", path);
            end
        end
    end
    return result;
end

"""
    get_option_bars(client::AlpacaClient, symbols, timeframe::AbstractString; start, finish = nothing, limit = 1000) -> Dict{String,Vector{Bar}}

!!! warning "Deprecated"
    `get_option_bars` is deprecated, use `api(client, MyOptionBarsEndpointModel(...))` instead.

Historical OHLCV bars of one or more option contracts. The request follows `next_page_token` and returns the bars of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.
- `timeframe::AbstractString`: the width of each bar, e.g., `"1Day"`.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of bars to return per page.

### Returns
- A `Dict{String,Vector{Bar}}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_bars(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector}, timeframe::AbstractString;
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1_000)::Dict{String,Vector{Bar}}

    # warn that the function is deprecated -
    Base.depwarn("`get_option_bars` is deprecated, use `api(client, MyOptionBarsEndpointModel(...))` instead", :get_option_bars);

    # build the model, and call api with the legacy handler -
    model = MyOptionBarsEndpointModel(symbols = _model_value(symbols), timeframe = String(timeframe),
        start = _model_value(start), finish = _model_value(finish), limit = Int(limit));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_option_trades(client::AlpacaClient, symbols; start, finish = nothing, limit = 1000) -> Dict{String,Vector{Trade}}

!!! warning "Deprecated"
    `get_option_trades` is deprecated, use `api(client, MyOptionTradesEndpointModel(...))` instead.

Historical trades of one or more option contracts. The request follows `next_page_token` and returns the trades of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of trades to return per page.

### Returns
- A `Dict{String,Vector{Trade}}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_trades(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector};
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1_000)::Dict{String,Vector{Trade}}

    # warn that the function is deprecated -
    Base.depwarn("`get_option_trades` is deprecated, use `api(client, MyOptionTradesEndpointModel(...))` instead", :get_option_trades);

    # build the model, and call api with the legacy handler -
    model = MyOptionTradesEndpointModel(symbols = _model_value(symbols), start = _model_value(start),
        finish = _model_value(finish), limit = Int(limit));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_option_quotes(client::AlpacaClient, symbols; start, finish = nothing, limit = 1000) -> Dict{String,Vector{Quote}}

!!! warning "Deprecated"
    `get_option_quotes` is deprecated, use `api(client, MyOptionQuotesEndpointModel(...))` instead.

Historical quotes of one or more option contracts. The request follows `next_page_token` and returns the quotes of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.
- `start::Union{AbstractString,DateTime,Date}`: the first time of the request.
- `finish::Union{AbstractString,DateTime,Date,Nothing}`: the last time of the request, or `nothing` to leave it open.
- `limit::Integer`: the largest number of quotes to return per page.

### Returns
- A `Dict{String,Vector{Quote}}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_quotes(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector};
    start::Union{AbstractString,DateTime,Date},
    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
    limit::Integer = 1_000)::Dict{String,Vector{Quote}}

    # warn that the function is deprecated -
    Base.depwarn("`get_option_quotes` is deprecated, use `api(client, MyOptionQuotesEndpointModel(...))` instead", :get_option_quotes);

    # build the model, and call api with the legacy handler -
    model = MyOptionQuotesEndpointModel(symbols = _model_value(symbols), start = _model_value(start),
        finish = _model_value(finish), limit = Int(limit));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_latest_option_bar(client::AlpacaClient, symbols) -> Dict{String,Bar}

!!! warning "Deprecated"
    `get_latest_option_bar` is deprecated, use `api(client, MyOptionLatestBarEndpointModel(...))` instead.

Fetch the latest bar of one or more option contracts.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.

### Returns
- A `Dict{String,Bar}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_option_bar(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector})::Dict{String,Bar}

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_option_bar` is deprecated, use `api(client, MyOptionLatestBarEndpointModel(...))` instead", :get_latest_option_bar);

    # build the model, and call api with the legacy handler -
    model = MyOptionLatestBarEndpointModel(symbols = _model_value(symbols));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_latest_option_quote(client::AlpacaClient, symbols) -> Dict{String,Quote}

!!! warning "Deprecated"
    `get_latest_option_quote` is deprecated, use `api(client, MyOptionLatestQuoteEndpointModel(...))` instead.

Fetch the latest quote of one or more option contracts.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.

### Returns
- A `Dict{String,Quote}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_option_quote(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector})::Dict{String,Quote}

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_option_quote` is deprecated, use `api(client, MyOptionLatestQuoteEndpointModel(...))` instead", :get_latest_option_quote);

    # build the model, and call api with the legacy handler -
    model = MyOptionLatestQuoteEndpointModel(symbols = _model_value(symbols));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_latest_option_trade(client::AlpacaClient, symbols) -> Dict{String,Trade}

!!! warning "Deprecated"
    `get_latest_option_trade` is deprecated, use `api(client, MyOptionLatestTradeEndpointModel(...))` instead.

Fetch the latest trade of one or more option contracts.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.

### Returns
- A `Dict{String,Trade}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_latest_option_trade(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector})::Dict{String,Trade}

    # warn that the function is deprecated -
    Base.depwarn("`get_latest_option_trade` is deprecated, use `api(client, MyOptionLatestTradeEndpointModel(...))` instead", :get_latest_option_trade);

    # build the model, and call api with the legacy handler -
    model = MyOptionLatestTradeEndpointModel(symbols = _model_value(symbols));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_option_snapshots(client::AlpacaClient, symbols) -> Dict{String,OptionSnapshot}

!!! warning "Deprecated"
    `get_option_snapshots` is deprecated, use `api(client, MyOptionSnapshotsEndpointModel(...))` instead.

Snapshots of one or more option contracts. Each snapshot holds the latest quote and trade, the intraday bars, the
implied volatility, and the greeks when they are available.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbols::Union{AbstractString,AbstractVector}`: an OCC option symbol or a vector of OCC option symbols.

### Returns
- A `Dict{String,OptionSnapshot}` keyed by option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_snapshots(client::AlpacaClient, symbols::Union{AbstractString,AbstractVector})::Dict{String,OptionSnapshot}

    # warn that the function is deprecated -
    Base.depwarn("`get_option_snapshots` is deprecated, use `api(client, MyOptionSnapshotsEndpointModel(...))` instead", :get_option_snapshots);

    # build the model, and call api with the legacy handler -
    model = MyOptionSnapshotsEndpointModel(symbols = _model_value(symbols));
    return api(client, model; handler = _legacy_handler);
end

"""
    get_option_chain_snapshot(client::AlpacaClient, underlying_symbol::AbstractString; type = nothing,
        strike_price_gte = nothing, strike_price_lte = nothing, expiration_date = nothing,
        expiration_date_gte = nothing, expiration_date_lte = nothing, limit = 1000) -> Dict{String,OptionSnapshot}

!!! warning "Deprecated"
    `get_option_chain_snapshot` is deprecated, use `api(client, MyOptionChainEndpointModel(...))` instead.

Snapshot of the whole option chain of an underlying (all strikes, all expirations, calls and puts), with optional
filters. The request follows `next_page_token` and returns the snapshots of every page.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `underlying_symbol::AbstractString`: the symbol of the underlying.
- `type::Union{AbstractString,Nothing}`: `"call"` or `"put"`.
- `strike_price_gte::Union{Real,Nothing}`: the lowest strike price to match.
- `strike_price_lte::Union{Real,Nothing}`: the highest strike price to match.
- `expiration_date::Union{AbstractString,Date,Nothing}`: the exact expiration date to match.
- `expiration_date_gte::Union{AbstractString,Date,Nothing}`: the earliest expiration date to match.
- `expiration_date_lte::Union{AbstractString,Date,Nothing}`: the latest expiration date to match.
- `limit::Integer`: the largest number of snapshots to return per page.

### Returns
- A `Dict{String,OptionSnapshot}` keyed by OCC option symbol.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function get_option_chain_snapshot(client::AlpacaClient, underlying_symbol::AbstractString;
    type::Union{AbstractString,Nothing} = nothing,
    strike_price_gte::Union{Real,Nothing} = nothing,
    strike_price_lte::Union{Real,Nothing} = nothing,
    expiration_date::Union{AbstractString,Date,Nothing} = nothing,
    expiration_date_gte::Union{AbstractString,Date,Nothing} = nothing,
    expiration_date_lte::Union{AbstractString,Date,Nothing} = nothing,
    limit::Integer = 1_000)::Dict{String,OptionSnapshot}

    # warn that the function is deprecated -
    Base.depwarn("`get_option_chain_snapshot` is deprecated, use `api(client, MyOptionChainEndpointModel(...))` instead", :get_option_chain_snapshot);

    # build the model, and call api with the legacy handler -
    model = MyOptionChainEndpointModel(underlying = String(underlying_symbol), type = _model_value(type),
        strike_price_gte = strike_price_gte, strike_price_lte = strike_price_lte,
        expiration_date = _model_value(expiration_date), expiration_date_gte = _model_value(expiration_date_gte),
        expiration_date_lte = _model_value(expiration_date_lte), limit = Int(limit));
    return api(client, model; handler = _legacy_handler);
end
"""
    submit_order(client, symbol, qty, side; type="market", time_in_force="day", limit_price=nothing, stop_price=nothing,
        trail_price=nothing, trail_percent=nothing, client_order_id=nothing, extended_hours=false, notional=nothing) -> Order

!!! warning "Deprecated"
    `submit_order` is deprecated, use `submit(client, MyEquityOrderModel(...); ...)` instead, or `submit(client, MyOptionLegModel(...); ...)` for an option symbol.

Submit an equity or ETF order. Exactly one of `qty` (shares, can be fractional) or `notional` (dollar amount) is given. Pass `qty = nothing` when using `notional`.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::AbstractString`: the symbol of the asset.
- `qty::Union{Real,Nothing}`: the number of shares.
- `side::AbstractString`: `"buy"` or `"sell"`.
- `type::AbstractString`: `"market"`, `"limit"`, `"stop"`, `"stop_limit"`, or `"trailing_stop"`.
- `time_in_force::AbstractString`: `"day"`, `"gtc"`, `"opg"`, `"cls"`, `"ioc"`, or `"fok"`.
- `limit_price`, `stop_price`, `trail_price`, `trail_percent`: the prices of the order, when the type needs them.
- `client_order_id`: the identifier of the order that the caller chooses.
- `extended_hours::Bool`: `true` allows the order to fill outside regular hours.
- `notional::Union{Real,Nothing}`: the dollar amount of the order.

### Returns
- The submitted `Order`.

### Throws
- `ArgumentError`: when both or neither of `qty` and `notional` are given.
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function submit_order(client::AlpacaClient,
                      symbol::AbstractString,
                      qty::Union{Real,Nothing},
                      side::AbstractString;
                      type::AbstractString = "market",
                      time_in_force::AbstractString = "day",
                      limit_price::Union{Real,Nothing} = nothing,
                      stop_price::Union{Real,Nothing} = nothing,
                      trail_price::Union{Real,Nothing} = nothing,
                      trail_percent::Union{Real,Nothing} = nothing,
                      client_order_id::Union{AbstractString,Nothing} = nothing,
                      extended_hours::Bool = false,
                      notional::Union{Real,Nothing} = nothing)::Order

    # warn that the function is deprecated -
    Base.depwarn("`submit_order` is deprecated, use `submit(client, MyEquityOrderModel(...))` instead, or `submit(client, MyOptionLegModel(...))` for an option symbol", :submit_order);

    # build the body without a position_intent, so that an option symbol still sends none, and post it -
    body = _single_order_body(symbol, qty, side; type = type, time_in_force = time_in_force, limit_price = limit_price,
        stop_price = stop_price, trail_price = trail_price, trail_percent = trail_percent, client_order_id = client_order_id,
        extended_hours = extended_hours, notional = notional);
    return _post_order(client, body);
end

"""
    submit_multileg_order(client, legs; type="limit", time_in_force="day", limit_price=nothing, qty=1,
        client_order_id=nothing, extended_hours=false) -> Order

!!! warning "Deprecated"
    `submit_multileg_order` is deprecated, use `submit`, `close`, or `roll` with `MyOptionLegModel` legs instead.

Submit a multi-leg options order (Alpaca `order_class = "mleg"`). Each leg submits `qty * leg.ratio_qty` contracts. For `type = "limit"`, `limit_price` is the net price of one spread unit, positive for a debit and negative for a credit.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `legs::Vector{OrderLeg}`: 2 to 4 option legs on the same underlying.
- `type::AbstractString`: `"market"` or `"limit"`.
- `time_in_force::AbstractString`: `"day"` is the only value that Alpaca accepts for a multi-leg order.
- `limit_price::Union{Real,Nothing}`: the net price of one spread unit.
- `qty::Integer`: the number of spread units.
- `client_order_id`: the identifier of the order that the caller chooses.
- `extended_hours::Bool`: `true` allows the order to fill outside regular hours.

### Returns
- The parent `Order`, with its `legs` filled from the response.

### Throws
- `ArgumentError`: when the legs, the type, or the limit price are not valid.
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function submit_multileg_order(client::AlpacaClient,
                               legs::Vector{OrderLeg};
                               type::AbstractString = "limit",
                               time_in_force::AbstractString = "day",
                               limit_price::Union{Real,Nothing} = nothing,
                               qty::Integer = 1,
                               client_order_id::Union{AbstractString,Nothing} = nothing,
                               extended_hours::Bool = false)::Order

    # warn that the function is deprecated -
    Base.depwarn("`submit_multileg_order` is deprecated, use `submit`, `close`, or `roll` with `MyOptionLegModel` legs instead", :submit_multileg_order);

    # split the legs into one vector for each field -
    symbols, sides, intents, ratios = _split_legs(legs);

    # build the body, which checks the legs first, and post it -
    body = _mleg_body(symbols, sides, intents, ratios; qty = qty, type = type, time_in_force = time_in_force,
        limit_price = limit_price, client_order_id = client_order_id, extended_hours = extended_hours);
    return _post_order(client, body);
end

"""
    cancel_order(client, order_id) -> Nothing

!!! warning "Deprecated"
    `cancel_order` is deprecated, use `cancel(client, id)` instead.

Cancel one open order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `order_id::AbstractString`: the id of the order.

### Returns
- `nothing`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function cancel_order(client::AlpacaClient, order_id::AbstractString)

    # warn that the function is deprecated -
    Base.depwarn("`cancel_order` is deprecated, use `cancel(client, id)` instead", :cancel_order);

    # send the request, and discard the response body -
    _cancel_order(client, String(order_id));
    return nothing;
end

"""
    cancel_all_orders(client)

!!! warning "Deprecated"
    `cancel_all_orders` is deprecated, use `cancel(client; all = true)` instead.

Attempt to cancel every open order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.

### Returns
- The response payload (the cancel status of each order) as a `JSON3` value, or `nothing` for an empty body.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function cancel_all_orders(client::AlpacaClient)

    # warn that the function is deprecated -
    Base.depwarn("`cancel_all_orders` is deprecated, use `cancel(client; all = true)` instead", :cancel_all_orders);

    # send the request, and parse the response body -
    return _parse_body(_cancel_all_orders(client));
end

"""
    close_position(client, symbol; qty=nothing, percentage=nothing)

!!! warning "Deprecated"
    `close_position` is deprecated, use `close(client, symbol; qty, percentage)` instead.

Liquidate a position. Pass `qty` (shares) or `percentage` (0 to 100) to close part of the position. Omit both to close the full position.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::AbstractString`: the symbol of the position.
- `qty::Union{Real,Nothing}`: the number of shares to close.
- `percentage::Union{Real,Nothing}`: the percentage of the position to close.

### Returns
- The response payload as a `JSON3` value, or `nothing` for an empty body.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function close_position(client::AlpacaClient, symbol::AbstractString;
                        qty::Union{Real,Nothing} = nothing,
                        percentage::Union{Real,Nothing} = nothing)

    # warn that the function is deprecated -
    Base.depwarn("`close_position` is deprecated, use `close(client, symbol; qty, percentage)` instead", :close_position);

    # send the request, and parse the response body -
    return _parse_body(_close_position(client, symbol; qty = qty, percentage = percentage));
end

"""
    close_all_positions(client; cancel_orders=false)

!!! warning "Deprecated"
    `close_all_positions` is deprecated, use `close(client; all = true, cancel_orders)` instead.

Liquidate every open position. With `cancel_orders = true`, Alpaca cancels the open orders first.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `cancel_orders::Bool`: `true` cancels the open orders before the positions are closed.

### Returns
- The response payload as a `JSON3` value, or `nothing` for an empty body.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function close_all_positions(client::AlpacaClient; cancel_orders::Bool = false)

    # warn that the function is deprecated -
    Base.depwarn("`close_all_positions` is deprecated, use `close(client; all = true, cancel_orders)` instead", :close_all_positions);

    # send the request, and parse the response body -
    return _parse_body(_close_all_positions(client; cancel_orders = cancel_orders));
end

# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
# _model_value: the models store text as a String. A legacy argument can be any AbstractString (e.g., a SubString),
# so this function converts text to a String and passes every other value (nothing, a Date, a vector) unchanged -
function _model_value(value)
    if (value isa AbstractString)
        return String(value);
    end
    return value;
end

# _BAR_CSV_HEADER: the header row of a bars CSV file -
const _BAR_CSV_HEADER = "timestamp,symbol,open,high,low,close,volume,trade_count,vwap";

# _write_bars_csv: write the bars to a CSV file, and close the file when the write ends or fails -
function _write_bars_csv(path::AbstractString, bars::AbstractVector{Bar})

    # create the missing directories, and open the file -
    mkpath(dirname(abspath(path)));
    io = open(path, "w");
    try
        println(io, _BAR_CSV_HEADER);
        for bar in bars

            # the trade count and the volume weighted price are empty when they are missing -
            trade_count = "";
            if (bar.n !== nothing)
                trade_count = bar.n;
            end
            vwap = "";
            if (bar.vw !== nothing)
                vwap = bar.vw;
            end
            print(io, Dates.format(bar.t, dateformat"yyyy-mm-ddTHH:MM:SS"));
            print(io, ",", bar.symbol);
            print(io, ",", bar.o, ",", bar.h, ",", bar.l, ",", bar.c);
            print(io, ",", bar.v);
            print(io, ",", trade_count);
            print(io, ",", vwap);
            println(io);
        end
    finally
        close(io);
    end
    return path;
end

# _as_date: a Date, a DateTime, or a date string as a Date, for the chunk arithmetic -
function _as_date(value::Date)::Date
    return value;
end

function _as_date(value::DateTime)::Date
    return Date(value);
end

function _as_date(value::AbstractString)::Date
    return Date(String(value));
end

# _month_chunks: split start to finish into windows of the given number of months. The first window starts at the
# original start, and the last window ends at the original finish, so a DateTime keeps its time of day -
function _month_chunks(start, finish, months::Integer)
    if (months <= 0)
        throw(ArgumentError("chunk_months must be positive"));
    end
    start_date = _as_date(start);
    finish_date = _as_date(finish);
    chunks = Tuple{Any,Any}[];
    cursor = start_date;
    while (cursor <= finish_date)
        window_end = min(finish_date, cursor + Month(months) - Day(1));
        push!(chunks, (cursor, window_end));
        cursor = window_end + Day(1);
    end
    if (isempty(chunks) == true)
        return chunks;
    end
    chunks[1] = (start, chunks[1][2]);
    chunks[end] = (chunks[end][1], finish);
    return chunks;
end

# _symbols_desc: a symbol or a vector of symbols as text for the verbose output -
function _symbols_desc(symbols::AbstractString)
    return symbols;
end

function _symbols_desc(symbols::AbstractVector)::String
    return "[" * join(symbols, ",") * "]";
end
# _parse_body: the legacy value of a response body. An empty body is nothing, and any other body is parsed as JSON -
function _parse_body(body::String)
    if (isempty(body))
        return nothing;
    end
    return JSON3.read(body);
end

# _split_legs: split the OrderLeg values into one vector for each field -
function _split_legs(legs::Vector{OrderLeg})::Tuple{Vector{String},Vector{String},Vector{String},Vector{Int}}
    symbols = String[];
    sides = String[];
    intents = String[];
    ratios = Int[];
    for leg in legs
        push!(symbols, leg.symbol);
        push!(sides, leg.side);
        push!(intents, leg.position_intent);
        push!(ratios, leg.ratio_qty);
    end
    return (symbols, sides, intents, ratios);
end

# _validate_mleg: check OrderLeg values with the checks of the Trading.jl method. The legacy tests call this form -
function _validate_mleg(legs::Vector{OrderLeg}, type::AbstractString, limit_price::Union{Real,Nothing})::Nothing
    symbols, sides, intents, ratios = _split_legs(legs);
    return _validate_mleg(symbols, sides, intents, ratios, type, limit_price);
end

# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
