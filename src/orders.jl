_maybe_string(::Nothing) = nothing
_maybe_string(x) = String(x)

function _parse_legs(v)
    v === nothing && return nothing
    isempty(v)    && return nothing
    return [_parse_order(leg) for leg in v]
end

function _parse_order(o::JSON3.Object)
    return Order(
        String(o.id),
        String(get(o, :client_order_id, "")),
        _maybe_string(get(o, :symbol, nothing)),
        String(get(o, :asset_class, "us_equity")),
        _maybe_string(get(o, :side, nothing)),
        String(o.type),
        String(o.time_in_force),
        String(get(o, :order_class, "")),
        _maybe_string(get(o, :position_intent, nothing)),
        _parse_float(get(o, :qty, nothing)),
        _parse_float_default(get(o, :filled_qty, "0")),
        _parse_float(get(o, :limit_price, nothing)),
        _parse_float(get(o, :stop_price, nothing)),
        _parse_float(get(o, :filled_avg_price, nothing)),
        String(o.status),
        _parse_rfc3339(get(o, :created_at, nothing)),
        _parse_rfc3339(get(o, :submitted_at, nothing)),
        _parse_rfc3339(get(o, :filled_at, nothing)),
        _parse_legs(get(o, :legs, nothing)),
        o,
    )
end

const _MLEG_SIDES   = ("buy", "sell")
const _MLEG_INTENTS = ("buy_to_open", "sell_to_open", "buy_to_close", "sell_to_close")
const _MLEG_TYPES   = ("market", "limit")

function _validate_mleg(legs::Vector{OrderLeg},
                        type::AbstractString,
                        limit_price::Union{Real,Nothing})
    n = length(legs)
    (n in 2:4) || throw(ArgumentError(
        "multi-leg order requires 2–4 legs, got $n"))

    type in _MLEG_TYPES || throw(ArgumentError(
        "type must be one of $(_MLEG_TYPES), got \"$type\""))

    if type == "limit" && limit_price === nothing
        throw(ArgumentError("limit_price is required when type=\"limit\""))
    end

    for (i, l) in pairs(legs)
        l.side in _MLEG_SIDES || throw(ArgumentError(
            "leg $i: side must be \"buy\" or \"sell\", got \"$(l.side)\""))
        l.position_intent in _MLEG_INTENTS || throw(ArgumentError(
            "leg $i: position_intent must be one of $(_MLEG_INTENTS), got \"$(l.position_intent)\""))
        l.ratio_qty >= 1 || throw(ArgumentError(
            "leg $i: ratio_qty must be ≥ 1, got $(l.ratio_qty)"))
        isempty(l.symbol) && throw(ArgumentError("leg $i: symbol is empty"))
    end
    return nothing
end

"""
    submit_order(client, symbol, qty, side; type="market", time_in_force="day",
                 limit_price=nothing, stop_price=nothing, client_order_id=nothing,
                 extended_hours=false, notional=nothing)

Submit an equity/ETF order. Exactly one of `qty` (shares, can be fractional) or
`notional` (dollar amount) should be provided — pass `qty=nothing` when using
`notional`.

- `side`: "buy" or "sell"
- `type`: "market", "limit", "stop", "stop_limit", "trailing_stop"
- `time_in_force`: "day", "gtc", "opg", "cls", "ioc", "fok"
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
                      notional::Union{Real,Nothing} = nothing)
    (qty === nothing && notional === nothing) &&
        throw(ArgumentError("must supply qty or notional"))
    (qty !== nothing && notional !== nothing) &&
        throw(ArgumentError("supply only one of qty or notional"))

    body = Dict{String,Any}(
        "symbol"        => symbol,
        "side"          => side,
        "type"          => type,
        "time_in_force" => time_in_force,
        "extended_hours" => extended_hours,
    )
    qty            === nothing || (body["qty"]             = string(qty))
    notional       === nothing || (body["notional"]        = string(notional))
    limit_price    === nothing || (body["limit_price"]     = string(limit_price))
    stop_price     === nothing || (body["stop_price"]      = string(stop_price))
    trail_price    === nothing || (body["trail_price"]     = string(trail_price))
    trail_percent  === nothing || (body["trail_percent"]   = string(trail_percent))
    client_order_id === nothing || (body["client_order_id"] = client_order_id)

    return _parse_order(_trading_post(client, "/orders"; body = body))
end

"""
    submit_multileg_order(client, legs;
                          type="limit", time_in_force="day",
                          limit_price=nothing, qty=1,
                          client_order_id=nothing,
                          extended_hours=false)

Submit a multi-leg options order (Alpaca `order_class="mleg"`).

- `legs::Vector{OrderLeg}`: 2–4 option legs, all on the same underlying.
- `qty`: number of spread units. Each leg's submitted quantity is
  `qty * leg.ratio_qty`.
- `type`: `"market"` or `"limit"`. For `"limit"`, `limit_price` is the **net
  price for one spread unit** (positive = debit, negative = credit), per
  Alpaca's convention.
- `time_in_force`: `"day"` is the only TIF Alpaca currently accepts for mleg.

Returns the parsed parent [`Order`](@ref) with `legs` populated from Alpaca's
response.

Stock+option combos (covered calls, married puts, collars-with-shares) are
not supported as a single mleg order by Alpaca; submit the equity side via
[`submit_order`](@ref) and the option side via this function.
"""
function submit_multileg_order(client::AlpacaClient,
                                legs::Vector{OrderLeg};
                                type::AbstractString = "limit",
                                time_in_force::AbstractString = "day",
                                limit_price::Union{Real,Nothing} = nothing,
                                qty::Integer = 1,
                                client_order_id::Union{AbstractString,Nothing} = nothing,
                                extended_hours::Bool = false)
    _validate_mleg(legs, type, limit_price)

    body = Dict{String,Any}(
        "order_class"    => "mleg",
        "qty"            => string(qty),
        "type"           => type,
        "time_in_force"  => time_in_force,
        "extended_hours" => extended_hours,
        "legs"           => [
            Dict(
                "symbol"          => l.symbol,
                "ratio_qty"       => string(l.ratio_qty),
                "side"            => l.side,
                "position_intent" => l.position_intent,
            ) for l in legs
        ],
    )
    limit_price     === nothing || (body["limit_price"]     = string(limit_price))
    client_order_id === nothing || (body["client_order_id"] = client_order_id)

    return _parse_order(_trading_post(client, "/orders"; body = body))
end

"""
    list_orders(client; status="open", limit=50, after=nothing, until=nothing,
                direction="desc", symbols=nothing)

List orders. `status` is one of `"open"`, `"closed"`, or `"all"`.
`symbols` may be a `Vector{String}` or comma-separated string.
"""
function list_orders(client::AlpacaClient;
                     status::AbstractString = "open",
                     limit::Integer = 50,
                     after::Union{AbstractString,DateTime,Nothing} = nothing,
                     until::Union{AbstractString,DateTime,Nothing} = nothing,
                     direction::AbstractString = "desc",
                     symbols::Union{AbstractVector,AbstractString,Nothing} = nothing)
    q = Dict{String,Any}("status" => status, "limit" => limit, "direction" => direction)
    after  === nothing || (q["after"] = string(after))
    until  === nothing || (q["until"] = string(until))
    if symbols !== nothing
        q["symbols"] = symbols isa AbstractString ? symbols : join(symbols, ",")
    end
    arr = _trading_get(client, "/orders"; query = q)
    return [_parse_order(o) for o in arr]
end

"""
    get_order(client, order_id; by_client_order_id=false)
"""
function get_order(client::AlpacaClient, order_id::AbstractString;
                   by_client_order_id::Bool = false)
    path = by_client_order_id ? "/orders:by_client_order_id" : "/orders/$(order_id)"
    q = by_client_order_id ? Dict("client_order_id" => order_id) : nothing
    return _parse_order(_trading_get(client, path; query = q))
end

"""
    cancel_order(client, order_id)
"""
function cancel_order(client::AlpacaClient, order_id::AbstractString)
    _trading_delete(client, "/orders/$(order_id)")
    return nothing
end

"""
    cancel_all_orders(client)

Attempt to cancel every open order. Returns the server response payload
(per-order cancel status) as a `JSON3` object.
"""
function cancel_all_orders(client::AlpacaClient)
    return _trading_delete(client, "/orders")
end
