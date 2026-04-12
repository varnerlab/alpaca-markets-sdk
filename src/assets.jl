function _parse_asset(o::JSON3.Object)
    return Asset(
        String(o.id),
        String(o.class),
        String(o.exchange),
        String(o.symbol),
        String(get(o, :name, "")),
        String(o.status),
        Bool(get(o, :tradable, false)),
        Bool(get(o, :marginable, false)),
        Bool(get(o, :shortable, false)),
        Bool(get(o, :easy_to_borrow, false)),
        Bool(get(o, :fractionable, false)),
        o,
    )
end

"""
    list_assets(client; status="active", asset_class="us_equity", tradable_only=true)

List tradable equity/ETF assets. Alpaca returns ETFs under `us_equity`; filter
downstream on the `name` / exchange if you need a finer split.
"""
function list_assets(client::AlpacaClient;
                     status::AbstractString = "active",
                     asset_class::AbstractString = "us_equity",
                     tradable_only::Bool = true)
    q = Dict("status" => status, "asset_class" => asset_class)
    arr = _trading_get(client, "/assets"; query = q)
    out = Asset[]
    for a in arr
        asset = _parse_asset(a)
        (tradable_only && !asset.tradable) && continue
        push!(out, asset)
    end
    return out
end

"""
    get_asset(client, symbol_or_id)

Lookup a single asset by symbol (e.g. `"AAPL"`) or asset UUID.
"""
function get_asset(client::AlpacaClient, symbol_or_id::AbstractString)
    return _parse_asset(_trading_get(client, "/assets/$(symbol_or_id)"))
end
