# Alpaca options support.
#
# Two separate API surfaces are involved:
#
#   1. Trading / contract metadata lives on the normal trading base URL
#      under /options/contracts. Response payloads are wrapped in
#      {"option_contracts": [...], "next_page_token": ...}.
#
#   2. Market data (historical bars / trades / quotes, latest-* endpoints,
#      and snapshots with greeks/IV) lives on the v1beta1 options data host.
#      Paths mirror the stock data layout under /options/*.
#
# Alpaca may (and periodically does) rev these beta endpoints. If a request
# starts 404'ing, the first thing to check is the URL path below.

# ---------------------------------------------------------------------------
# Historical market data  (/v1beta1/options/bars|trades|quotes)
# ---------------------------------------------------------------------------

"""
    get_option_bars(client, symbols, timeframe; start, finish=nothing, limit=1000)

Historical OHLCV bars for one or more option contracts. `symbols` are
OCC-encoded option symbols. Returns `Dict{String,Vector{Bar}}` keyed by
option symbol; pagination is automatic.
"""
function get_option_bars(client::AlpacaClient,
                         symbols::Union{AbstractString,AbstractVector},
                         timeframe::AbstractString;
                         start::Union{AbstractString,DateTime,Date},
                         finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                         limit::Integer = 1_000)
    out = Dict{String,Vector{Bar}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols"   => _symbols_param(symbols),
            "timeframe" => timeframe,
            "start"     => _fmt_ts(start),
            "limit"     => limit,
        )
        finish     === nothing || (q["end"]        = _fmt_ts(finish))
        page_token === nothing || (q["page_token"] = page_token)
        resp = _options_data_get(client, "/options/bars"; query = q)
        if haskey(resp, :bars) && resp.bars !== nothing
            for (sym, arr) in pairs(resp.bars)
                bucket = get!(out, String(sym), Bar[])
                for b in arr
                    push!(bucket, _parse_bar(String(sym), b))
                end
            end
        end
        page_token = get(resp, :next_page_token, nothing)
        (page_token === nothing || page_token == "") && break
    end
    return out
end

"""
    get_option_trades(client, symbols; start, finish=nothing, limit=1000)
"""
function get_option_trades(client::AlpacaClient,
                           symbols::Union{AbstractString,AbstractVector};
                           start::Union{AbstractString,DateTime,Date},
                           finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                           limit::Integer = 1_000)
    out = Dict{String,Vector{Trade}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols" => _symbols_param(symbols),
            "start"   => _fmt_ts(start),
            "limit"   => limit,
        )
        finish     === nothing || (q["end"]        = _fmt_ts(finish))
        page_token === nothing || (q["page_token"] = page_token)
        resp = _options_data_get(client, "/options/trades"; query = q)
        if haskey(resp, :trades) && resp.trades !== nothing
            for (sym, arr) in pairs(resp.trades)
                bucket = get!(out, String(sym), Trade[])
                for t in arr
                    push!(bucket, _parse_trade(String(sym), t))
                end
            end
        end
        page_token = get(resp, :next_page_token, nothing)
        (page_token === nothing || page_token == "") && break
    end
    return out
end

"""
    get_option_quotes(client, symbols; start, finish=nothing, limit=1000)
"""
function get_option_quotes(client::AlpacaClient,
                           symbols::Union{AbstractString,AbstractVector};
                           start::Union{AbstractString,DateTime,Date},
                           finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                           limit::Integer = 1_000)
    out = Dict{String,Vector{Quote}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols" => _symbols_param(symbols),
            "start"   => _fmt_ts(start),
            "limit"   => limit,
        )
        finish     === nothing || (q["end"]        = _fmt_ts(finish))
        page_token === nothing || (q["page_token"] = page_token)
        resp = _options_data_get(client, "/options/quotes"; query = q)
        if haskey(resp, :quotes) && resp.quotes !== nothing
            for (sym, arr) in pairs(resp.quotes)
                bucket = get!(out, String(sym), Quote[])
                for qo in arr
                    push!(bucket, _parse_quote(String(sym), qo))
                end
            end
        end
        page_token = get(resp, :next_page_token, nothing)
        (page_token === nothing || page_token == "") && break
    end
    return out
end

# ---------------------------------------------------------------------------
# Latest-* endpoints (batch)
# ---------------------------------------------------------------------------

"""
    get_latest_option_bar(client, symbols)

Returns `Dict{String,Bar}` keyed by OCC option symbol. `symbols` may be a
single symbol or a vector.
"""
function get_latest_option_bar(client::AlpacaClient,
                               symbols::Union{AbstractString,AbstractVector})
    resp = _options_data_get(client, "/options/bars/latest";
                             query = Dict("symbols" => _symbols_param(symbols)))
    out = Dict{String,Bar}()
    if haskey(resp, :bars) && resp.bars !== nothing
        for (sym, obj) in pairs(resp.bars)
            out[String(sym)] = _parse_bar(String(sym), obj)
        end
    end
    return out
end

"""
    get_latest_option_quote(client, symbols)
"""
function get_latest_option_quote(client::AlpacaClient,
                                 symbols::Union{AbstractString,AbstractVector})
    resp = _options_data_get(client, "/options/quotes/latest";
                             query = Dict("symbols" => _symbols_param(symbols)))
    out = Dict{String,Quote}()
    if haskey(resp, :quotes) && resp.quotes !== nothing
        for (sym, obj) in pairs(resp.quotes)
            out[String(sym)] = _parse_quote(String(sym), obj)
        end
    end
    return out
end

"""
    get_latest_option_trade(client, symbols)
"""
function get_latest_option_trade(client::AlpacaClient,
                                 symbols::Union{AbstractString,AbstractVector})
    resp = _options_data_get(client, "/options/trades/latest";
                             query = Dict("symbols" => _symbols_param(symbols)))
    out = Dict{String,Trade}()
    if haskey(resp, :trades) && resp.trades !== nothing
        for (sym, obj) in pairs(resp.trades)
            out[String(sym)] = _parse_trade(String(sym), obj)
        end
    end
    return out
end

# ---------------------------------------------------------------------------
# Snapshots (with greeks / IV)
# ---------------------------------------------------------------------------

_maybe_float(o, k) = haskey(o, k) && o[k] !== nothing ? Float64(o[k]) : nothing

function _parse_greeks(o)
    o === nothing && return nothing
    return OptionGreeks(
        _maybe_float(o, :delta),
        _maybe_float(o, :gamma),
        _maybe_float(o, :theta),
        _maybe_float(o, :vega),
        _maybe_float(o, :rho),
    )
end

function _parse_option_snapshot(symbol::AbstractString, o::JSON3.Object)
    lq = haskey(o, :latestQuote) && o.latestQuote !== nothing ?
        _parse_quote(String(symbol), o.latestQuote) : nothing
    lt = haskey(o, :latestTrade) && o.latestTrade !== nothing ?
        _parse_trade(String(symbol), o.latestTrade) : nothing
    mb = haskey(o, :minuteBar) && o.minuteBar !== nothing ?
        _parse_bar(String(symbol), o.minuteBar) : nothing
    db = haskey(o, :dailyBar) && o.dailyBar !== nothing ?
        _parse_bar(String(symbol), o.dailyBar) : nothing
    pb = haskey(o, :prevDailyBar) && o.prevDailyBar !== nothing ?
        _parse_bar(String(symbol), o.prevDailyBar) : nothing
    iv = haskey(o, :impliedVolatility) && o.impliedVolatility !== nothing ?
        Float64(o.impliedVolatility) : nothing
    gr = haskey(o, :greeks) && o.greeks !== nothing ? _parse_greeks(o.greeks) : nothing
    return OptionSnapshot(String(symbol), lq, lt, mb, db, pb, iv, gr, o)
end

"""
    get_option_snapshots(client, symbols)

Per-contract snapshots for the given OCC option symbols. Returns
`Dict{String,OptionSnapshot}` including latest quote/trade, intraday bars,
implied volatility, and greeks when available.
"""
function get_option_snapshots(client::AlpacaClient,
                              symbols::Union{AbstractString,AbstractVector})
    resp = _options_data_get(client, "/options/snapshots";
                             query = Dict("symbols" => _symbols_param(symbols)))
    out = Dict{String,OptionSnapshot}()
    snapshots = get(resp, :snapshots, resp)  # endpoint variants either wrap or don't
    for (sym, obj) in pairs(snapshots)
        out[String(sym)] = _parse_option_snapshot(String(sym), obj)
    end
    return out
end

"""
    get_option_chain_snapshot(client, underlying_symbol;
                              type=nothing, strike_price_gte=nothing,
                              strike_price_lte=nothing,
                              expiration_date=nothing,
                              expiration_date_gte=nothing,
                              expiration_date_lte=nothing,
                              limit=1000)

Snapshot of the whole option chain for an underlying (all strikes,
expirations, calls + puts), with optional server-side filters. Returns
`Dict{String,OptionSnapshot}` keyed by OCC symbol. Pagination is automatic.
"""
function get_option_chain_snapshot(client::AlpacaClient,
                                   underlying_symbol::AbstractString;
                                   type::Union{AbstractString,Nothing} = nothing,
                                   strike_price_gte::Union{Real,Nothing} = nothing,
                                   strike_price_lte::Union{Real,Nothing} = nothing,
                                   expiration_date::Union{AbstractString,Date,Nothing} = nothing,
                                   expiration_date_gte::Union{AbstractString,Date,Nothing} = nothing,
                                   expiration_date_lte::Union{AbstractString,Date,Nothing} = nothing,
                                   limit::Integer = 1_000)
    out = Dict{String,OptionSnapshot}()
    page_token = nothing
    while true
        q = Dict{String,Any}("limit" => limit)
        type                === nothing || (q["type"]                = type)
        strike_price_gte    === nothing || (q["strike_price_gte"]    = string(strike_price_gte))
        strike_price_lte    === nothing || (q["strike_price_lte"]    = string(strike_price_lte))
        expiration_date     === nothing || (q["expiration_date"]     = string(expiration_date))
        expiration_date_gte === nothing || (q["expiration_date_gte"] = string(expiration_date_gte))
        expiration_date_lte === nothing || (q["expiration_date_lte"] = string(expiration_date_lte))
        page_token          === nothing || (q["page_token"]          = page_token)

        resp = _options_data_get(client, "/options/snapshots/$(underlying_symbol)";
                                 query = q)
        snapshots = get(resp, :snapshots, nothing)
        if snapshots !== nothing
            for (sym, obj) in pairs(snapshots)
                out[String(sym)] = _parse_option_snapshot(String(sym), obj)
            end
        end
        page_token = get(resp, :next_page_token, nothing)
        (page_token === nothing || page_token == "") && break
    end
    return out
end
