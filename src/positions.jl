function _parse_position(o::JSON3.Object)
    return Position(
        String(o.asset_id),
        String(o.symbol),
        String(get(o, :exchange, "")),
        String(get(o, :asset_class, "us_equity")),
        _parse_float_default(get(o, :qty, "0")),
        String(get(o, :side, "long")),
        _parse_float_default(get(o, :avg_entry_price, "0")),
        _parse_float_default(get(o, :market_value, "0")),
        _parse_float_default(get(o, :cost_basis, "0")),
        _parse_float_default(get(o, :unrealized_pl, "0")),
        _parse_float_default(get(o, :unrealized_plpc, "0")),
        _parse_float_default(get(o, :current_price, "0")),
        _parse_float_default(get(o, :lastday_price, "0")),
        _parse_float_default(get(o, :change_today, "0")),
        o,
    )
end

"""
    list_positions(client)
"""
function list_positions(client::AlpacaClient)
    arr = _trading_get(client, "/positions")
    return [_parse_position(p) for p in arr]
end

"""
    get_position(client, symbol_or_asset_id)
"""
function get_position(client::AlpacaClient, symbol_or_asset_id::AbstractString)
    return _parse_position(_trading_get(client, "/positions/$(symbol_or_asset_id)"))
end

"""
    close_position(client, symbol; qty=nothing, percentage=nothing)

Liquidate a position. Pass `qty` (shares) or `percentage` (0–100) to partially
close; omit both to close the full position.
"""
function close_position(client::AlpacaClient, symbol::AbstractString;
                        qty::Union{Real,Nothing} = nothing,
                        percentage::Union{Real,Nothing} = nothing)
    q = Dict{String,Any}()
    qty        === nothing || (q["qty"]        = string(qty))
    percentage === nothing || (q["percentage"] = string(percentage))
    return _trading_delete(client, "/positions/$(symbol)";
                           query = isempty(q) ? nothing : q)
end

"""
    close_all_positions(client; cancel_orders=false)
"""
function close_all_positions(client::AlpacaClient; cancel_orders::Bool = false)
    q = Dict("cancel_orders" => cancel_orders)
    return _trading_delete(client, "/positions"; query = q)
end
