# =============================================================================
# Trading: the submit and cancel verbs and the helpers that build and send the order requests
# =============================================================================
# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #

"""
    submit(client::AlpacaClient, m::MyEquityOrderModel; type = "market", time_in_force = "day",
        limit_price = nothing, stop_price = nothing, trail_price = nothing, trail_percent = nothing,
        client_order_id = nothing, extended_hours = false) -> Order

Submit one equity or ETF order, using an HTTP POST call to the Alpaca `/orders` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `m::MyEquityOrderModel`: the order model that holds the symbol, the side, and the quantity or the notional.
- `type::String`: `"market"`, `"limit"`, `"stop"`, `"stop_limit"`, or `"trailing_stop"`.
- `time_in_force::String`: `"day"`, `"gtc"`, `"opg"`, `"cls"`, `"ioc"`, or `"fok"`.
- `limit_price`, `stop_price`, `trail_price`, `trail_percent`: the prices of the order, or `nothing`.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when the `type` requires a price that is `nothing`, e.g., `"limit"` without `limit_price`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function submit(client::AlpacaClient, m::MyEquityOrderModel; type::AbstractString = "market", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, stop_price::Union{Nothing,Real} = nothing, trail_price::Union{Nothing,Real} = nothing,
    trail_percent::Union{Nothing,Real} = nothing, client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # check the prices that the order type requires, before any request -
    _check_order_prices(type, limit_price, stop_price, trail_price, trail_percent, true);

    # build the request body from the model and the keywords -
    body = _single_order_body(m.symbol, m.qty, m.side; type = type, time_in_force = time_in_force, limit_price = limit_price,
        stop_price = stop_price, trail_price = trail_price, trail_percent = trail_percent, client_order_id = client_order_id,
        extended_hours = extended_hours, notional = m.notional);

    # send the order -
    return _post_order(client, body);
end

"""
    submit(client::AlpacaClient, leg::MyOptionLegModel; qty = 1, type = "market", time_in_force = "day",
        limit_price = nothing, stop_price = nothing, client_order_id = nothing, extended_hours = false) -> Order

Submit one option order that opens the leg, using an HTTP POST call to the Alpaca `/orders` endpoint.
The order sends `qty * leg.ratio` contracts with the position intent `buy_to_open` or `sell_to_open`.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `leg::MyOptionLegModel`: the option leg to open.
- `qty::Int`: the number of units of the leg.
- `type::String`: `"market"`, `"limit"`, `"stop"`, or `"stop_limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`, `stop_price`: the prices of the order, or `nothing`.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when `leg.side` is not `"buy"` or `"sell"`, when `leg.ratio < 1`, or when the `type` requires a price that is `nothing`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function submit(client::AlpacaClient, leg::MyOptionLegModel; qty::Int = 1, type::AbstractString = "market", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, stop_price::Union{Nothing,Real} = nothing,
    client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # the model is mutable, so check the side and the ratio of the leg again -
    _check_leg_fields(leg.side, leg.ratio);

    # check the prices that the order type requires, before any request -
    _check_order_prices(type, limit_price, stop_price, nothing, nothing, false);

    # the number of contracts is the number of units times the ratio of the leg -
    contracts = qty * leg.ratio;

    # build the request body, with the intent that opens the leg -
    body = _single_order_body(leg.symbol, contracts, leg.side; type = type, time_in_force = time_in_force, limit_price = limit_price,
        stop_price = stop_price, client_order_id = client_order_id, extended_hours = extended_hours,
        position_intent = leg.side * "_to_open");

    # send the order -
    return _post_order(client, body);
end

"""
    submit(client::AlpacaClient, legs::Vector{MyOptionLegModel}; qty = 1, type = "limit", time_in_force = "day",
        limit_price = nothing, client_order_id = nothing, extended_hours = false) -> Order

Submit a structure of option legs that opens every leg, using an HTTP POST call to the Alpaca `/orders` endpoint.
One leg is sent as a single option order. Two to four legs are sent as one atomic `mleg` order.
For an `mleg` order, `limit_price` is the net price of one unit of the structure (positive is a debit, negative is a credit).

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `legs::Vector{MyOptionLegModel}`: the legs to open.
- `qty::Int`: the number of units of the structure.
- `type::String`: `"market"` or `"limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`: the limit price, or `nothing`. A limit order requires it.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when there are no legs, more than 4 legs, or a leg is invalid. For one leg, the single-leg checks apply, e.g., `"limit"` requires `limit_price`. For 2 to 4 legs, a `"limit"` order requires `limit_price`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function submit(client::AlpacaClient, legs::Vector{MyOptionLegModel}; qty::Int = 1, type::AbstractString = "limit", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # one leg is a single option order -
    if (length(legs) == 1)
        return submit(client, legs[1]; qty = qty, type = type, time_in_force = time_in_force, limit_price = limit_price,
            client_order_id = client_order_id, extended_hours = extended_hours);
    end

    # collect the symbols, sides, intents, and ratios of the legs -
    symbols = String[];
    sides = String[];
    intents = String[];
    ratios = Int[];
    for leg in legs
        push!(symbols, leg.symbol);
        push!(sides, leg.side);
        push!(intents, leg.side * "_to_open");
        push!(ratios, leg.ratio);
    end

    # build the mleg body (this checks the legs, so an invalid order sends nothing) and send the order -
    body = _mleg_body(symbols, sides, intents, ratios; qty = qty, type = type, time_in_force = time_in_force,
        limit_price = limit_price, client_order_id = client_order_id, extended_hours = extended_hours);
    return _post_order(client, body);
end

"""
    cancel(client::AlpacaClient, order::Order) -> Nothing

Cancel an order that has not filled, using an HTTP DELETE call to the Alpaca `/orders/{id}` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `order::Order`: the order to cancel.

### Returns
- `nothing`.

### Throws
- `AlpacaError`: when Alpaca rejects the request, e.g., the order already filled.
"""
function cancel(client::AlpacaClient, order::Order)::Nothing
    _cancel_order(client, order.id);
    return nothing;
end

"""
    cancel(client::AlpacaClient, id::String) -> Nothing

Cancel an order that has not filled, using an HTTP DELETE call to the Alpaca `/orders/{id}` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `id::String`: the order identifier assigned by Alpaca, e.g., from the `id` column of an orders `DataFrame`.

### Returns
- `nothing`.

### Throws
- `AlpacaError`: when Alpaca rejects the request, e.g., the order already filled.
"""
function cancel(client::AlpacaClient, id::String)::Nothing
    _cancel_order(client, id);
    return nothing;
end

"""
    cancel(client::AlpacaClient; all::Bool = false) -> DataFrame

Cancel every open order, using an HTTP DELETE call to the Alpaca `/orders` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `all::Bool`: must be `true`. The keyword makes the cancel of every order explicit.

### Returns
- `DataFrame`: one row for each order that Alpaca tried to cancel, with the columns `id` and `status`.

### Throws
- `ArgumentError`: when `all` is not `true`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function cancel(client::AlpacaClient; all::Bool = false)::DataFrame

    # cancelling every order must be requested explicitly -
    if (all == false)
        throw(ArgumentError("pass `all = true` to cancel every open order"));
    end

    # send the request and read the per-order status -
    body = _cancel_all_orders(client);
    ids = String[];
    statuses = Any[];
    if (isempty(body) == false)
        for record in _json_records(body, String[])
            push!(ids, String(get(record, :id, "")));
            push!(statuses, get(record, :status, nothing));
        end
    end
    return DataFrame(id = ids, status = statuses);
end

"""
    Base.close(client::AlpacaClient, symbol::String; qty = nothing, percentage = nothing) -> Order

Close the position in one symbol at market, using an HTTP DELETE call to the Alpaca `/positions/{symbol}` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `symbol::String`: the symbol of the position, e.g., `"AAPL"` or an OCC contract symbol.
- `qty`: the number of shares or contracts to close, or `nothing` to close the whole position.
- `percentage`: the percentage of the position to close, or `nothing`.

### Returns
- `Order`: the order that Alpaca created to close the position.

### Throws
- `AlpacaError`: when Alpaca rejects the request, e.g., there is no position in the symbol.
"""
function Base.close(client::AlpacaClient, symbol::String; qty::Union{Nothing,Real} = nothing, percentage::Union{Nothing,Real} = nothing)::Order
    response = _close_position(client, symbol; qty = qty, percentage = percentage);
    return _parse_order(JSON3.read(response));
end

"""
    Base.close(client::AlpacaClient; all::Bool = false, cancel_orders::Bool = false) -> DataFrame

Close every position at market, using an HTTP DELETE call to the Alpaca `/positions` endpoint.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `all::Bool`: must be `true`. The keyword makes the close of every position explicit.
- `cancel_orders::Bool`: `true` cancels the open orders before the positions close.

### Returns
- `DataFrame`: one row for each position that Alpaca tried to close, with the columns `symbol` and `status`.

### Throws
- `ArgumentError`: when `all` is not `true`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function Base.close(client::AlpacaClient; all::Bool = false, cancel_orders::Bool = false)::DataFrame

    # closing every position must be requested explicitly -
    if (all == false)
        throw(ArgumentError("pass `all = true` to close every position"));
    end

    # send the request and read the per-position status -
    body = _close_all_positions(client; cancel_orders = cancel_orders);
    symbols = String[];
    statuses = Any[];
    if (isempty(body) == false)
        for record in _json_records(body, String[])
            push!(symbols, String(get(record, :symbol, "")));
            push!(statuses, get(record, :status, nothing));
        end
    end
    return DataFrame(symbol = symbols, status = statuses);
end

"""
    Base.close(client::AlpacaClient, m::MyEquityOrderModel; type = "market", time_in_force = "day",
        limit_price = nothing, stop_price = nothing, trail_price = nothing, trail_percent = nothing,
        client_order_id = nothing, extended_hours = false) -> Order

Close an equity or ETF order by submitting the reverse order, using an HTTP POST call to the Alpaca `/orders` endpoint.
The reverse order has the opposite side and the same `qty` or `notional` as the model.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `m::MyEquityOrderModel`: the order model to reverse.
- `type::String`: `"market"`, `"limit"`, `"stop"`, `"stop_limit"`, or `"trailing_stop"`.
- `time_in_force::String`: `"day"`, `"gtc"`, `"opg"`, `"cls"`, `"ioc"`, or `"fok"`.
- `limit_price`, `stop_price`, `trail_price`, `trail_percent`: the prices of the order, or `nothing`.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when the `type` requires a price that is `nothing`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function Base.close(client::AlpacaClient, m::MyEquityOrderModel; type::AbstractString = "market", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, stop_price::Union{Nothing,Real} = nothing, trail_price::Union{Nothing,Real} = nothing,
    trail_percent::Union{Nothing,Real} = nothing, client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # run the same checks as submit, before any request -
    _check_order_prices(type, limit_price, stop_price, trail_price, trail_percent, true);

    # build the body of the reverse order -
    body = _single_order_body(m.symbol, m.qty, _opposite_side(m.side); type = type, time_in_force = time_in_force, limit_price = limit_price,
        stop_price = stop_price, trail_price = trail_price, trail_percent = trail_percent, client_order_id = client_order_id,
        extended_hours = extended_hours, notional = m.notional);

    # send the order -
    return _post_order(client, body);
end

"""
    Base.close(client::AlpacaClient, leg::MyOptionLegModel; qty = 1, type = "market", time_in_force = "day",
        limit_price = nothing, stop_price = nothing, client_order_id = nothing, extended_hours = false) -> Order

Close an option leg by submitting the reverse order, using an HTTP POST call to the Alpaca `/orders` endpoint.
The reverse order has the opposite side of the leg, sends `qty * leg.ratio` contracts, and has the position intent `buy_to_close` or `sell_to_close`.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `leg::MyOptionLegModel`: the option leg to close.
- `qty::Int`: the number of units of the leg.
- `type::String`: `"market"`, `"limit"`, `"stop"`, or `"stop_limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`, `stop_price`: the prices of the order, or `nothing`.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when `leg.side` is not `"buy"` or `"sell"`, when `leg.ratio < 1`, or when the `type` requires a price that is `nothing`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function Base.close(client::AlpacaClient, leg::MyOptionLegModel; qty::Int = 1, type::AbstractString = "market", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, stop_price::Union{Nothing,Real} = nothing,
    client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # run the same checks as submit, before any request -
    _check_leg_fields(leg.side, leg.ratio);
    _check_order_prices(type, limit_price, stop_price, nothing, nothing, false);

    # the number of contracts is the number of units times the ratio of the leg -
    contracts = qty * leg.ratio;

    # build the body of the reverse order, with the intent that closes the leg -
    reverse_side = _opposite_side(leg.side);
    body = _single_order_body(leg.symbol, contracts, reverse_side; type = type, time_in_force = time_in_force, limit_price = limit_price,
        stop_price = stop_price, client_order_id = client_order_id, extended_hours = extended_hours,
        position_intent = reverse_side * "_to_close");

    # send the order -
    return _post_order(client, body);
end

"""
    Base.close(client::AlpacaClient, legs::Vector{MyOptionLegModel}; qty = 1, type = "limit", time_in_force = "day",
        limit_price = nothing, client_order_id = nothing, extended_hours = false) -> Order

Close a structure of option legs by submitting the reverse order, using an HTTP POST call to the Alpaca `/orders` endpoint.
The reverse order has the opposite side of every leg and the position intent `buy_to_close` or `sell_to_close`.
One leg is sent as a single option order. Two to four legs are sent as one atomic `mleg` order.
For an `mleg` order, `limit_price` is the net price of one unit of the structure (positive is a debit, negative is a credit).

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `legs::Vector{MyOptionLegModel}`: the legs to close.
- `qty::Int`: the number of units of the structure.
- `type::String`: `"market"` or `"limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`: the limit price, or `nothing`. A limit order requires it.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.
- `extended_hours::Bool`: `true` allows the order to fill outside regular trading hours.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when there are no legs, more than 4 legs, or a leg is invalid. A `"limit"` order requires `limit_price`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function Base.close(client::AlpacaClient, legs::Vector{MyOptionLegModel}; qty::Int = 1, type::AbstractString = "limit", time_in_force::AbstractString = "day",
    limit_price::Union{Nothing,Real} = nothing, client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Order

    # one leg is a single option order -
    if (length(legs) == 1)
        return close(client, legs[1]; qty = qty, type = type, time_in_force = time_in_force, limit_price = limit_price,
            client_order_id = client_order_id, extended_hours = extended_hours);
    end

    # check the fields of each leg -
    for leg in legs
        _check_leg_fields(leg.side, leg.ratio);
    end

    # reverse every leg -
    symbols = String[];
    sides = String[];
    intents = String[];
    ratios = Int[];
    _append_legs!(symbols, sides, intents, ratios, legs, true);

    # build the mleg body (this checks the legs, so an invalid order sends nothing) and send the order -
    body = _mleg_body(symbols, sides, intents, ratios; qty = qty, type = type, time_in_force = time_in_force,
        limit_price = limit_price, client_order_id = client_order_id, extended_hours = extended_hours);
    return _post_order(client, body);
end

"""
    Base.close(client::AlpacaClient, order::Order; type = "market", limit_price = nothing, time_in_force = "day") -> Order

Close a filled order by submitting the reverse order, using an HTTP POST call to the Alpaca `/orders` endpoint.
The reverse order uses the filled quantities of the order. The kind of the order comes from the `Order` value:
an order with `legs` is a multi-leg order, an order with the asset class `"us_option"` is a single option order, and any other order is an equity order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `order::Order`: the filled order to reverse, e.g., an order that `submit` returned.
- `type::String`: the type of the reverse order. Use `"market"` or `"limit"`.
- `limit_price`: the limit price of the reverse order, or `nothing`. For a multi-leg order, this is the net price of one unit of the structure.
- `time_in_force::String`: the time in force of the reverse order, e.g., `"day"`.

### Returns
- `Order`: the reverse order as Alpaca accepted it.

### Throws
- `ArgumentError`: when the status of `order` is not `"filled"`. Use `cancel` for an order that has not filled. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function Base.close(client::AlpacaClient, order::Order; type::AbstractString = "market", limit_price::Union{Nothing,Real} = nothing,
    time_in_force::AbstractString = "day")::Order

    # only a filled order can be reversed -
    _check_filled(order);

    # a multi-leg order is reversed as one unit of every leg, for each filled unit -
    if (order.legs !== nothing)
        return close(client, _legs_from_order(order); qty = Int(order.filled_qty), type = type, time_in_force = time_in_force,
            limit_price = limit_price);
    end

    # a single option order is reversed with the close intent -
    if (order.asset_class == "us_option")
        leg = MyOptionLegModel(symbol = order.symbol, side = order.side);
        return close(client, leg; qty = Int(order.filled_qty), type = type, time_in_force = time_in_force, limit_price = limit_price);
    end

    # any other order is an equity order, reversed with the filled quantity -
    m = MyEquityOrderModel(symbol = order.symbol, side = order.side, qty = _whole_qty(order.filled_qty));
    return close(client, m; type = type, time_in_force = time_in_force, limit_price = limit_price);
end

"""
    roll(client::AlpacaClient, from, to; qty = 1, type = "limit", time_in_force = "day",
        limit_price = nothing, client_order_id = nothing) -> Order

Roll option legs from one set of contracts to another, using an HTTP POST call to the Alpaca `/orders` endpoint.
The call sends one atomic `mleg` order. Each `from` leg is reversed with the position intent `buy_to_close` or `sell_to_close`,
and each `to` leg is opened with the position intent `buy_to_open` or `sell_to_open`.
`limit_price` is the net price of one unit of the structure (positive is a debit, negative is a credit).

`roll` covers a single contract (2 legs) and a vertical spread (4 legs). An iron condor has 8 legs, so it rolls as two `roll` calls, one for each wing.
The two calls are not atomic: the first order can fill while the second order does not.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `from::Union{MyOptionLegModel,Vector{MyOptionLegModel}}`: the legs to close.
- `to::Union{MyOptionLegModel,Vector{MyOptionLegModel}}`: the legs to open.
- `qty::Int`: the number of units of the structure.
- `type::String`: `"market"` or `"limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`: the limit price, or `nothing`. A limit order requires it.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when the `from` and `to` legs together are fewer than 2 or more than 4, when a leg is invalid, or when a `"limit"` order has no `limit_price`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function roll(client::AlpacaClient, from::Union{MyOptionLegModel,Vector{MyOptionLegModel}}, to::Union{MyOptionLegModel,Vector{MyOptionLegModel}};
    qty::Int = 1, type::AbstractString = "limit", time_in_force::AbstractString = "day", limit_price::Union{Nothing,Real} = nothing,
    client_order_id::Union{Nothing,AbstractString} = nothing)::Order

    # a single leg is a vector of one leg -
    from_legs = _as_legs(from);
    to_legs = _as_legs(to);

    # check the fields of each leg -
    for leg in from_legs
        _check_leg_fields(leg.side, leg.ratio);
    end
    for leg in to_legs
        _check_leg_fields(leg.side, leg.ratio);
    end

    # close the from legs, then open the to legs -
    symbols = String[];
    sides = String[];
    intents = String[];
    ratios = Int[];
    _append_legs!(symbols, sides, intents, ratios, from_legs, true);
    _append_legs!(symbols, sides, intents, ratios, to_legs, false);

    # build the mleg body (this checks the number of legs, so an invalid roll sends nothing) and send the order -
    body = _mleg_body(symbols, sides, intents, ratios; qty = qty, type = type, time_in_force = time_in_force,
        limit_price = limit_price, client_order_id = client_order_id);
    return _post_order(client, body);
end

"""
    roll(client::AlpacaClient, from::Order, to; qty = nothing, type = "limit", time_in_force = "day",
        limit_price = nothing, client_order_id = nothing) -> Order

Roll the legs of a filled option order to another set of contracts. The legs of `from` are the legs to close. A single option order is one leg, and a multi-leg order is one leg for each of its legs.
When `qty` is `nothing`, the call uses the filled quantity of `from`.
The call sends one atomic `mleg` order, as described for `roll(client, from, to)`.
An iron condor rolls as two `roll` calls, one for each wing, and the two calls are not atomic.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `from::Order`: the filled option order that holds the legs to close, e.g., an order that `submit` returned.
- `to::Union{MyOptionLegModel,Vector{MyOptionLegModel}}`: the legs to open.
- `qty`: the number of units of the structure, or `nothing` to use the filled quantity of `from`.
- `type::String`: `"market"` or `"limit"`.
- `time_in_force::String`: the time in force of the order, e.g., `"day"`.
- `limit_price`: the limit price, or `nothing`. A limit order requires it.
- `client_order_id`: the order identifier assigned by the client, or `nothing`.

### Returns
- `Order`: the order as Alpaca accepted it.

### Throws
- `ArgumentError`: when the status of `from` is not `"filled"`, when `from` is an equity order (use `close` or `submit` for shares), when the legs together are fewer than 2 or more than 4, or when a `"limit"` order has no `limit_price`. The call sends no request.
- `AlpacaError`: when Alpaca rejects the request.
"""
function roll(client::AlpacaClient, from::Order, to::Union{MyOptionLegModel,Vector{MyOptionLegModel}}; qty::Union{Nothing,Int} = nothing,
    type::AbstractString = "limit", time_in_force::AbstractString = "day", limit_price::Union{Nothing,Real} = nothing,
    client_order_id::Union{Nothing,AbstractString} = nothing)::Order

    # only a filled order can be rolled -
    _check_filled(from);

    # the default number of units is the filled quantity -
    units = qty;
    if (units === nothing)
        units = Int(from.filled_qty);
    end

    # convert the filled order to legs, then roll the legs -
    return roll(client, _legs_from_order(from), to; qty = units, type = type, time_in_force = time_in_force,
        limit_price = limit_price, client_order_id = client_order_id);
end

"""
    submit(client::AlpacaClient, m::MyMixedOrderModel; qty = 1, type = "limit", limit_price = nothing, time_in_force = "day",
        fill_timeout = 30.0, poll_interval = 0.5) -> Vector{Order}

Submit shares and options together as two orders, because Alpaca cannot fill them in one order. The method first sends the equity order at market
and waits until it fills. It then sends the option order, which is one single-leg order or one multi-leg order. The method does not wait on the option order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `m::MyMixedOrderModel`: the structure that holds the equity part and the option legs.
- `qty::Int`: the number of units of the option legs. The share quantity is the `qty` of the equity model.
- `type::String`: the type of the option order, `"market"` or `"limit"`.
- `limit_price`: the limit price of the option order, or `nothing`.
- `time_in_force::String`: the time in force of the option order, e.g., `"day"`.
- `fill_timeout::Real`: the number of seconds to wait for the equity order to fill.
- `poll_interval::Real`: the number of seconds between two polls of the equity order.

### Returns
- `Vector{Order}`: the filled equity order and the option order as Alpaca accepted it. The option order may still be resting.

### Throws
- `ArgumentError`: when the shares do not cover a short call, when `qty < 1`, `poll_interval <= 0`, or `fill_timeout < 0`, or when either order is invalid. The call sends no request.
- `AlpacaError`: when Alpaca rejects the equity order. The method sends no option order.
- `AlpacaSequenceError`: when the equity order does not fill in time (the method cancels it and sends no option order),
  when polling the equity order fails (the method tries to cancel it and sends no option order, and `cause` holds the polling error),
  or when the option order fails, e.g., Alpaca rejects it (`cause` holds that error). The error holds the equity order.
"""
function submit(client::AlpacaClient, m::MyMixedOrderModel; qty::Int = 1, type::AbstractString = "limit",
    limit_price::Union{Nothing,Real} = nothing, time_in_force::AbstractString = "day", fill_timeout::Real = 30.0,
    poll_interval::Real = 0.5)::Vector{Order}

    # check the coverage and both orders, before any request -
    _check_coverage(m, qty);
    _check_mixed_orders(m, false, qty, type, limit_price, fill_timeout, poll_interval);

    # send the equity order at market, and wait until it fills -
    equity_order = submit(client, m.equity);
    filled_order = _wait_for_fill(client, equity_order, Float64(fill_timeout), Float64(poll_interval));

    # send the option order. We do not wait on it -
    option_order = nothing;
    try
        option_order = submit(client, m.options; qty = qty, type = type, limit_price = limit_price, time_in_force = time_in_force);
    catch error
        if (error isa InterruptException)
            rethrow();
        end
        throw(AlpacaSequenceError("the equity order filled, but the option order failed", [filled_order], error));
    end
    return [filled_order, option_order];
end

"""
    Base.close(client::AlpacaClient, m::MyMixedOrderModel; qty = 1, type = "limit", limit_price = nothing, time_in_force = "day",
        fill_timeout = 30.0, poll_interval = 0.5) -> Vector{Order}

Close shares and options together as two orders. The method first sends the reverse option order and waits until it fills.
It then sends the reverse equity order at market. The method does not wait on the equity order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `m::MyMixedOrderModel`: the structure to reverse.
- `qty::Int`: the number of units of the option legs. The share quantity is the `qty` of the equity model.
  Use the same `qty` as in the `submit` call. The method buys back `qty` units of the option legs, and then sells all `m.equity.qty` shares, so a smaller `qty` leaves a short call uncovered.
- `type::String`: the type of the reverse option order, `"market"` or `"limit"`.
- `limit_price`: the limit price of the reverse option order, or `nothing`.
- `time_in_force::String`: the time in force of the reverse option order, e.g., `"day"`.
- `fill_timeout::Real`: the number of seconds to wait for the option order to fill.
- `poll_interval::Real`: the number of seconds between two polls of the option order.

### Returns
- `Vector{Order}`: the filled option order and the equity order as Alpaca accepted it. The equity order may still be resting.

### Throws
- `ArgumentError`: when `qty < 1`, `poll_interval <= 0`, or `fill_timeout < 0`, or when either reverse order is invalid. The call sends no request.
- `AlpacaError`: when Alpaca rejects the reverse option order. The method sends no equity order.
- `AlpacaSequenceError`: when the option order does not fill in time (the method cancels it and sends no equity order),
  when polling the option order fails (the method tries to cancel it and sends no equity order, and `cause` holds the polling error),
  or when the equity order fails, e.g., Alpaca rejects it (`cause` holds that error). The error holds the option order.
"""
function Base.close(client::AlpacaClient, m::MyMixedOrderModel; qty::Int = 1, type::AbstractString = "limit",
    limit_price::Union{Nothing,Real} = nothing, time_in_force::AbstractString = "day", fill_timeout::Real = 30.0,
    poll_interval::Real = 0.5)::Vector{Order}

    # check both orders, before any request -
    _check_mixed_orders(m, true, qty, type, limit_price, fill_timeout, poll_interval);

    # send the reverse option order, and wait until it fills -
    option_order = close(client, m.options; qty = qty, type = type, limit_price = limit_price, time_in_force = time_in_force);
    filled_order = _wait_for_fill(client, option_order, Float64(fill_timeout), Float64(poll_interval));

    # send the reverse equity order at market. We do not wait on it -
    equity_order = nothing;
    try
        equity_order = close(client, m.equity);
    catch error
        if (error isa InterruptException)
            rethrow();
        end
        throw(AlpacaSequenceError("the option order filled, but the equity order failed", [filled_order], error));
    end
    return [filled_order, equity_order];
end

# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
const _LEG_SIDES = ("buy", "sell");
const _LEG_INTENTS = ("buy_to_open", "sell_to_open", "buy_to_close", "sell_to_close");
const _MLEG_ORDER_TYPES = ("market", "limit");

# _check_order_prices: check that the prices that the order type requires are set. This runs in the public submit methods -
function _check_order_prices(type::AbstractString, limit_price, stop_price, trail_price, trail_percent, is_equity::Bool)::Nothing

    # limit and stop_limit orders need a limit price -
    if ((type == "limit" || type == "stop_limit") && limit_price === nothing)
        throw(ArgumentError("limit_price is required when type=\"$(type)\""));
    end

    # stop and stop_limit orders need a stop price -
    if ((type == "stop" || type == "stop_limit") && stop_price === nothing)
        throw(ArgumentError("stop_price is required when type=\"$(type)\""));
    end

    # an equity trailing stop needs a trail price or a trail percent -
    if (is_equity == true && type == "trailing_stop" && trail_price === nothing && trail_percent === nothing)
        throw(ArgumentError("trail_price or trail_percent is required when type=\"trailing_stop\""));
    end
    return nothing;
end

# _check_leg_fields: check the side and the ratio of an option leg. The leg model is mutable, so its fields can change after construction -
function _check_leg_fields(side::AbstractString, ratio::Integer)::Nothing

    # the side is buy or sell -
    if ((side in _LEG_SIDES) == false)
        throw(ArgumentError("side must be \"buy\" or \"sell\", got \"$(side)\""));
    end

    # the ratio is at least 1 -
    if (ratio < 1)
        throw(ArgumentError("ratio must be at least 1, got $(ratio)"));
    end
    return nothing;
end

# _single_order_body: build the body of a single-leg order. Prices are written with string(x), so 150.25 is sent as "150.25" -
function _single_order_body(symbol, qty, side; type = "market", time_in_force = "day", limit_price = nothing, stop_price = nothing,
    trail_price = nothing, trail_percent = nothing, client_order_id = nothing, extended_hours = false, notional = nothing,
    position_intent = nothing)::Dict{String,Any}

    # exactly one of qty and notional must be set -
    if (qty === nothing && notional === nothing)
        throw(ArgumentError("must supply qty or notional"));
    end
    if (qty !== nothing && notional !== nothing)
        throw(ArgumentError("supply only one of qty or notional"));
    end

    # the keys that are always sent -
    body = Dict{String,Any}(
        "symbol" => symbol,
        "side" => side,
        "type" => type,
        "time_in_force" => time_in_force,
        "extended_hours" => extended_hours,
    );

    # the keys that are sent only when set -
    if (qty !== nothing)
        body["qty"] = string(qty);
    end
    if (notional !== nothing)
        body["notional"] = string(notional);
    end
    if (limit_price !== nothing)
        body["limit_price"] = string(limit_price);
    end
    if (stop_price !== nothing)
        body["stop_price"] = string(stop_price);
    end
    if (trail_price !== nothing)
        body["trail_price"] = string(trail_price);
    end
    if (trail_percent !== nothing)
        body["trail_percent"] = string(trail_percent);
    end
    if (client_order_id !== nothing)
        body["client_order_id"] = client_order_id;
    end
    if (position_intent !== nothing)
        body["position_intent"] = position_intent;
    end
    return body;
end

# _validate_mleg: check the legs of a multi-leg order before anything is sent -
function _validate_mleg(symbols::Vector{String}, sides::Vector{String}, intents::Vector{String}, ratios::Vector{Int},
    type::AbstractString, limit_price::Union{Nothing,Real})::Nothing

    # a multi-leg order has 2 to 4 legs -
    n = length(symbols);
    if ((n in 2:4) == false)
        throw(ArgumentError("multi-leg order requires 2–4 legs, got $n"));
    end

    # the type is market or limit -
    if ((type in _MLEG_ORDER_TYPES) == false)
        throw(ArgumentError("type must be one of $(_MLEG_ORDER_TYPES), got \"$type\""));
    end

    # a limit order requires a limit price -
    if (type == "limit" && limit_price === nothing)
        throw(ArgumentError("limit_price is required when type=\"limit\""));
    end

    # check each leg -
    for i in 1:n
        if ((sides[i] in _LEG_SIDES) == false)
            throw(ArgumentError("leg $i: side must be \"buy\" or \"sell\", got \"$(sides[i])\""));
        end
        if ((intents[i] in _LEG_INTENTS) == false)
            throw(ArgumentError("leg $i: position_intent must be one of $(_LEG_INTENTS), got \"$(intents[i])\""));
        end
        if (ratios[i] < 1)
            throw(ArgumentError("leg $i: ratio_qty must be ≥ 1, got $(ratios[i])"));
        end
        if (isempty(symbols[i]))
            throw(ArgumentError("leg $i: symbol is empty"));
        end
    end
    return nothing;
end

# _mleg_body: build the body of an atomic multi-leg order. The legs are checked first -
function _mleg_body(symbols::Vector{String}, sides::Vector{String}, intents::Vector{String}, ratios::Vector{Int}; qty::Integer = 1,
    type::AbstractString = "limit", time_in_force::AbstractString = "day", limit_price::Union{Nothing,Real} = nothing,
    client_order_id::Union{Nothing,AbstractString} = nothing, extended_hours::Bool = false)::Dict{String,Any}

    # check the legs -
    _validate_mleg(symbols, sides, intents, ratios, type, limit_price);

    # build the body of each leg -
    leg_bodies = Any[];
    for i in eachindex(symbols)
        push!(leg_bodies, Dict(
            "symbol" => symbols[i],
            "ratio_qty" => string(ratios[i]),
            "side" => sides[i],
            "position_intent" => intents[i],
        ));
    end

    # build the body of the order -
    body = Dict{String,Any}(
        "order_class" => "mleg",
        "qty" => string(qty),
        "type" => type,
        "time_in_force" => time_in_force,
        "extended_hours" => extended_hours,
        "legs" => leg_bodies,
    );
    if (limit_price !== nothing)
        body["limit_price"] = string(limit_price);
    end
    if (client_order_id !== nothing)
        body["client_order_id"] = client_order_id;
    end
    return body;
end

# _post_order: send an order body to POST /orders and parse the response -
function _post_order(client::AlpacaClient, body::Dict{String,Any})::Order
    response = _http_call(client, "POST", "$(client.trading_url)/orders"; body = body);
    return _parse_order(JSON3.read(response));
end

# _get_order: read one order with GET /orders/{id} and parse the response -
function _get_order(client::AlpacaClient, id::String)::Order
    response = _http_call(client, "GET", "$(client.trading_url)/orders/$(id)");
    return _parse_order(JSON3.read(response));
end

# _cancel_order: send DELETE /orders/{id}. Alpaca answers 204 with an empty body -
function _cancel_order(client::AlpacaClient, id::String)::String
    return _http_call(client, "DELETE", "$(client.trading_url)/orders/$(id)");
end

# _opposite_side: the side that reverses a leg or an order -
function _opposite_side(side::AbstractString)::String
    if (side == "buy")
        return "sell";
    end
    return "buy";
end

# _whole_qty: a whole-number quantity becomes an Int, so it is sent as "7" and not "7.0" -
function _whole_qty(x::Float64)::Union{Int,Float64}
    if (x == round(x))
        return Int(x);
    end
    return x;
end

# _check_filled: only a filled order can be closed or rolled -
function _check_filled(order::Order)::Nothing
    if (order.status != "filled")
        throw(ArgumentError("order $(order.id) has status $(order.status); use `cancel` for an order that has not filled"));
    end
    return nothing;
end

# _as_legs: a single leg is a vector of one leg, and a vector of legs stays as it is -
function _as_legs(leg::MyOptionLegModel)::Vector{MyOptionLegModel}
    return [leg];
end

function _as_legs(legs::Vector{MyOptionLegModel})::Vector{MyOptionLegModel}
    return legs;
end

# _append_legs!: add the symbol, side, intent, and ratio of each leg. A closing leg is reversed and gets the *_to_close intent -
function _append_legs!(symbols::Vector{String}, sides::Vector{String}, intents::Vector{String}, ratios::Vector{Int},
    legs::Vector{MyOptionLegModel}, closing::Bool)::Nothing
    for leg in legs
        push!(symbols, leg.symbol);
        push!(ratios, leg.ratio);
        if (closing == true)
            reverse_side = _opposite_side(leg.side);
            push!(sides, reverse_side);
            push!(intents, reverse_side * "_to_close");
        else
            push!(sides, leg.side);
            push!(intents, leg.side * "_to_open");
        end
    end
    return nothing;
end

# _leg_ratio: the number of contracts of a leg in one unit of the structure. Alpaca sends ratio_qty as a string or a number -
function _leg_ratio(leg::Order, parent::Order)::Int
    if (haskey(leg.raw, :ratio_qty) && leg.raw.ratio_qty !== nothing)
        value = leg.raw.ratio_qty;
        if (value isa AbstractString)
            return parse(Int, value);
        end
        return Int(value);
    end
    return Int(leg.qty / parent.qty);
end

# _legs_from_order: convert an option order to option leg models. A multi-leg order gives one leg for each of its legs,
# a single option order gives one leg, and an equity order raises an ArgumentError -
function _legs_from_order(order::Order)::Vector{MyOptionLegModel}
    legs = MyOptionLegModel[];

    # a multi-leg order gives one leg model for each leg -
    if (order.legs !== nothing)
        for leg in order.legs
            push!(legs, MyOptionLegModel(symbol = leg.symbol, side = leg.side, ratio = _leg_ratio(leg, order)));
        end
        return legs;
    end

    # a single option order gives one leg model -
    if (order.asset_class == "us_option")
        push!(legs, MyOptionLegModel(symbol = order.symbol, side = order.side, ratio = 1));
        return legs;
    end

    # an equity order has no option legs -
    throw(ArgumentError("order $(order.id) is an equity order; `roll` is for option orders, use `close` or `submit` for shares"));
end

# _cancel_all_orders: send DELETE /orders and return the response body -
function _cancel_all_orders(client::AlpacaClient)::String
    return _http_call(client, "DELETE", "$(client.trading_url)/orders");
end

# _close_position: send DELETE /positions/{symbol}, with the qty and percentage query parameters when set, and return the response body -
function _close_position(client::AlpacaClient, symbol::AbstractString; qty::Union{Nothing,Real} = nothing,
    percentage::Union{Nothing,Real} = nothing)::String
    query = Dict{String,Any}();
    if (qty !== nothing)
        query["qty"] = string(qty);
    end
    if (percentage !== nothing)
        query["percentage"] = string(percentage);
    end
    request_url = _build_url(client.trading_url, "/positions/$(symbol)", query);
    return _http_call(client, "DELETE", request_url);
end

# _close_all_positions: send DELETE /positions?cancel_orders=<bool> and return the response body -
function _close_all_positions(client::AlpacaClient; cancel_orders::Bool = false)::String
    request_url = _build_url(client.trading_url, "/positions", Dict("cancel_orders" => cancel_orders));
    return _http_call(client, "DELETE", request_url);
end

# _check_coverage: shares must cover every short call. A call has the OCC type character C at position length(symbol) - 8,
# and the OCC root (all characters before the last 15) is the underlying -
function _check_coverage(m::MyMixedOrderModel, qty::Int)::Nothing

    # sum the ratios of the short call legs -
    short_calls = 0;
    for leg in m.options

        # an OCC symbol has a root and 15 more characters -
        if (length(leg.symbol) < 16)
            throw(ArgumentError("\"$(leg.symbol)\" is not an OCC option symbol"));
        end
        if (leg.side == "sell" && leg.symbol[length(leg.symbol) - 8] == 'C')

            # the short call must be on the shares of the equity part -
            if (leg.symbol[1:end-15] != m.equity.symbol)
                throw(ArgumentError("the short call $(leg.symbol) is on $(leg.symbol[1:end-15]), but the equity part trades $(m.equity.symbol)"));
            end
            short_calls += leg.ratio;
        end
    end

    # a model without a short call needs no cover -
    if (short_calls == 0)
        return nothing;
    end

    # the equity part must buy shares, set by qty -
    if (m.equity.side != "buy")
        throw(ArgumentError("a short call needs the equity side \"buy\", got \"$(m.equity.side)\""));
    end
    if (m.equity.qty === nothing)
        throw(ArgumentError("a short call needs the equity model to set `qty`, not `notional`"));
    end

    # the shares must cover 100 shares per short contract -
    needed = 100 * qty * short_calls;
    if (m.equity.qty < needed)
        throw(ArgumentError("a short call needs $(needed) shares, the equity model buys $(m.equity.qty)"));
    end
    return nothing;
end

# _check_mixed_orders: run the checks of both orders, so an invalid order sends nothing. A closing structure reverses both parts -
function _check_mixed_orders(m::MyMixedOrderModel, closing::Bool, qty::Int, type::AbstractString, limit_price,
    fill_timeout::Real, poll_interval::Real)::Nothing

    # check the quantity and the wait settings -
    if (qty < 1)
        throw(ArgumentError("qty must be at least 1, got $(qty)"));
    end
    if (poll_interval <= 0)
        throw(ArgumentError("poll_interval must be positive, got $(poll_interval)"));
    end
    if (fill_timeout < 0)
        throw(ArgumentError("fill_timeout must not be negative, got $(fill_timeout)"));
    end

    # check the equity order. The equity part trades at market -
    equity_side = m.equity.side;
    if (closing == true)
        equity_side = _opposite_side(m.equity.side);
    end
    _check_order_prices("market", nothing, nothing, nothing, nothing, true);
    _single_order_body(m.equity.symbol, m.equity.qty, equity_side; notional = m.equity.notional);

    # check the fields of each option leg -
    for leg in m.options
        _check_leg_fields(leg.side, leg.ratio);
    end

    # check the option order -
    if (length(m.options) == 1)
        _check_order_prices(type, limit_price, nothing, nothing, nothing, false);
    else
        symbols = String[];
        sides = String[];
        intents = String[];
        ratios = Int[];
        _append_legs!(symbols, sides, intents, ratios, m.options, closing);
        _validate_mleg(symbols, sides, intents, ratios, type, limit_price);
    end
    return nothing;
end

# _wait_for_fill: poll the order until it fills. On a timeout or an early stop, cancel the order, read it again, and throw unless it filled -
function _wait_for_fill(client::AlpacaClient, order::Order, fill_timeout::Float64, poll_interval::Float64)::Order

    # poll until the deadline. A failed poll cancels the order, as far as possible, and ends the sequence -
    deadline = time() + fill_timeout;
    last_order = order;
    try
        while (true)
            last_order = _get_order(client, order.id);

            # a filled order ends the wait -
            if (last_order.status == "filled")
                return last_order;
            end

            # a canceled, expired, or rejected order ends the wait early -
            if (last_order.status in ("canceled", "expired", "rejected"))
                break;
            end

            # a late order ends the wait -
            if (time() >= deadline)
                break;
            end
            sleep(poll_interval);
        end
    catch error
        if (error isa InterruptException)
            rethrow();
        end
        try
            _cancel_order(client, order.id);
        catch cancel_error
            if (cancel_error isa InterruptException)
                rethrow();
            end
        end
        throw(AlpacaSequenceError("polling order $(order.id) failed, so the sequence stopped", [last_order], error));
    end

    # cancel the order. Alpaca may refuse, e.g., when the order filled or ended, so any error from the cancel is ignored -
    try
        _cancel_order(client, order.id);
    catch cancel_error
        if (cancel_error isa InterruptException)
            rethrow();
        end
    end

    # read the order again. The order may have filled before the cancel. If the read fails, keep the last polled order -
    fresh_order = last_order;
    try
        fresh_order = _get_order(client, order.id);
    catch fresh_error
        if (fresh_error isa InterruptException)
            rethrow();
        end
    end
    if (fresh_order.status == "filled")
        return fresh_order;
    end
    throw(AlpacaSequenceError("order $(order.id) did not fill: status $(fresh_order.status), filled_qty $(fresh_order.filled_qty), so the sequence stopped",
        [fresh_order], nothing));
end

# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
