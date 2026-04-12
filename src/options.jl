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
# Contracts (trading API)
# ---------------------------------------------------------------------------

function _parse_option_contract(o::JSON3.Object)
    return OptionContract(
        String(o.id),
        String(o.symbol),
        String(get(o, :name, "")),
        String(get(o, :status, "")),
        Bool(get(o, :tradable, false)),
        Date(String(o.expiration_date)),
        String(get(o, :root_symbol, get(o, :underlying_symbol, ""))),
        String(o.underlying_symbol),
        String(get(o, :underlying_asset_id, "")),
        String(o.type),
        String(get(o, :style, "american")),
        _parse_float_default(get(o, :strike_price, "0")),
        _parse_float_default(get(o, :multiplier, "100")),
        _parse_float_default(get(o, :size, "100")),
        _parse_float(get(o, :open_interest, nothing)),
        _parse_date_maybe(get(o, :open_interest_date, nothing)),
        _parse_float(get(o, :close_price, nothing)),
        _parse_date_maybe(get(o, :close_price_date, nothing)),
        o,
    )
end

"""
    list_option_contracts(client;
                          underlying_symbols,
                          status               = "active",
                          expiration_date      = nothing,
                          expiration_date_gte  = nothing,
                          expiration_date_lte  = nothing,
                          strike_price_gte     = nothing,
                          strike_price_lte     = nothing,
                          type                 = nothing,   # "call" | "put"
                          style                = nothing,   # "american" | "european"
                          limit                = 1000)

Enumerate contracts for one or more underlyings, optionally filtered by
expiration window, strike range, call/put, or exercise style. Pagination
via `next_page_token` is handled automatically and the entire result is
returned as a `Vector{OptionContract}`.
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
                               limit::Integer = 1_000)
    syms = underlying_symbols isa AbstractString ?
        underlying_symbols : join(underlying_symbols, ",")

    out = OptionContract[]
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "underlying_symbols" => syms,
            "status"             => status,
            "limit"              => limit,
        )
        expiration_date     === nothing || (q["expiration_date"]     = string(expiration_date))
        expiration_date_gte === nothing || (q["expiration_date_gte"] = string(expiration_date_gte))
        expiration_date_lte === nothing || (q["expiration_date_lte"] = string(expiration_date_lte))
        strike_price_gte    === nothing || (q["strike_price_gte"]    = string(strike_price_gte))
        strike_price_lte    === nothing || (q["strike_price_lte"]    = string(strike_price_lte))
        type                === nothing || (q["type"]                = type)
        style               === nothing || (q["style"]               = style)
        page_token          === nothing || (q["page_token"]          = page_token)

        resp = _trading_get(client, "/options/contracts"; query = q)
        arr  = get(resp, :option_contracts, get(resp, :contracts, nothing))
        arr === nothing && break
        for c in arr
            push!(out, _parse_option_contract(c))
        end
        page_token = get(resp, :next_page_token, nothing)
        (page_token === nothing || page_token == "") && break
    end
    return out
end

"""
    get_option_contract(client, symbol_or_id)

Fetch a single option contract by OCC symbol (e.g. `"AAPL260117C00150000"`)
or by Alpaca contract UUID.
"""
function get_option_contract(client::AlpacaClient, symbol_or_id::AbstractString)
    return _parse_option_contract(
        _trading_get(client, "/options/contracts/$(symbol_or_id)"))
end

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
