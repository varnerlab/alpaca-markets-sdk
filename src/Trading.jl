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
    body = _http_call(client, "DELETE", "$(client.trading_url)/orders");
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

# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
