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
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
