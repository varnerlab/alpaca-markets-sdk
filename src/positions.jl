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
