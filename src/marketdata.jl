# Market data endpoints live under data.alpaca.markets/v2/stocks/...
# Docs: https://docs.alpaca.markets/reference/stockbars

_symbols_param(s::AbstractString) = s
_symbols_param(s::AbstractVector) = join(s, ",")

_fmt_ts(x::AbstractString) = String(x)
_fmt_ts(x::DateTime) = Dates.format(x, dateformat"yyyy-mm-ddTHH:MM:SSZ")
_fmt_ts(x::Date)     = string(x)

function _parse_bar(symbol::AbstractString, o)
    return Bar(
        String(symbol),
        _parse_rfc3339(String(o.t)),
        Float64(o.o),
        Float64(o.h),
        Float64(o.l),
        Float64(o.c),
        Float64(o.v),
        haskey(o, :n)  ? Int(o.n)     : nothing,
        haskey(o, :vw) ? Float64(o.vw) : nothing,
    )
end

function _parse_quote(symbol::AbstractString, o)
    return Quote(
        String(symbol),
        _parse_rfc3339(String(o.t)),
        Float64(get(o, :bp, 0.0)),
        Float64(get(o, :bs, 0.0)),
        Float64(get(o, :ap, 0.0)),
        Float64(get(o, :as, 0.0)),
        String(get(o, :bx, "")),
        String(get(o, :ax, "")),
    )
end

function _parse_trade(symbol::AbstractString, o)
    return Trade(
        String(symbol),
        _parse_rfc3339(String(o.t)),
        Float64(get(o, :p, 0.0)),
        Float64(get(o, :s, 0.0)),
        String(get(o, :x, "")),
        haskey(o, :i) ? Int(o.i) : nothing,
    )
end

"""
    get_bars(client, symbols, timeframe; start, finish=nothing, limit=1000,
             adjustment="raw", feed="iex")

Fetch historical OHLCV bars. `symbols` may be a single ticker or vector.
`timeframe` examples: `"1Min"`, `"5Min"`, `"15Min"`, `"1Hour"`, `"1Day"`.

`feed` defaults to `"iex"` which is free; switch to `"sip"` if your data
subscription allows it. Returns `Dict{String,Vector{Bar}}` keyed by symbol.

Handles pagination automatically via the `next_page_token` cursor.
"""
function get_bars(client::AlpacaClient,
                  symbols::Union{AbstractString,AbstractVector},
                  timeframe::AbstractString;
                  start::Union{AbstractString,DateTime,Date},
                  finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                  limit::Integer = 1000,
                  adjustment::AbstractString = "raw",
                  feed::AbstractString = "iex")
    out = Dict{String,Vector{Bar}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols"    => _symbols_param(symbols),
            "timeframe"  => timeframe,
            "start"      => _fmt_ts(start),
            "limit"      => limit,
            "adjustment" => adjustment,
            "feed"       => feed,
        )
        finish     === nothing || (q["end"]             = _fmt_ts(finish))
        page_token === nothing || (q["page_token"]      = page_token)
        resp = _data_get(client, "/stocks/bars"; query = q)
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
    get_quotes(client, symbols; start, finish=nothing, limit=1000, feed="iex")
"""
function get_quotes(client::AlpacaClient,
                    symbols::Union{AbstractString,AbstractVector};
                    start::Union{AbstractString,DateTime,Date},
                    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                    limit::Integer = 1000,
                    feed::AbstractString = "iex")
    out = Dict{String,Vector{Quote}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols" => _symbols_param(symbols),
            "start"   => _fmt_ts(start),
            "limit"   => limit,
            "feed"    => feed,
        )
        finish     === nothing || (q["end"]        = _fmt_ts(finish))
        page_token === nothing || (q["page_token"] = page_token)
        resp = _data_get(client, "/stocks/quotes"; query = q)
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

"""
    get_trades(client, symbols; start, finish=nothing, limit=1000, feed="iex")
"""
function get_trades(client::AlpacaClient,
                    symbols::Union{AbstractString,AbstractVector};
                    start::Union{AbstractString,DateTime,Date},
                    finish::Union{AbstractString,DateTime,Date,Nothing} = nothing,
                    limit::Integer = 1000,
                    feed::AbstractString = "iex")
    out = Dict{String,Vector{Trade}}()
    page_token = nothing
    while true
        q = Dict{String,Any}(
            "symbols" => _symbols_param(symbols),
            "start"   => _fmt_ts(start),
            "limit"   => limit,
            "feed"    => feed,
        )
        finish     === nothing || (q["end"]        = _fmt_ts(finish))
        page_token === nothing || (q["page_token"] = page_token)
        resp = _data_get(client, "/stocks/trades"; query = q)
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
    get_latest_bar(client, symbol; feed="iex")
"""
function get_latest_bar(client::AlpacaClient, symbol::AbstractString;
                        feed::AbstractString = "iex")
    resp = _data_get(client, "/stocks/$(symbol)/bars/latest"; query = Dict("feed" => feed))
    return _parse_bar(symbol, resp.bar)
end

"""
    get_latest_quote(client, symbol; feed="iex")
"""
function get_latest_quote(client::AlpacaClient, symbol::AbstractString;
                          feed::AbstractString = "iex")
    resp = _data_get(client, "/stocks/$(symbol)/quotes/latest"; query = Dict("feed" => feed))
    return _parse_quote(symbol, resp.quote)
end

"""
    get_latest_trade(client, symbol; feed="iex")
"""
function get_latest_trade(client::AlpacaClient, symbol::AbstractString;
                          feed::AbstractString = "iex")
    resp = _data_get(client, "/stocks/$(symbol)/trades/latest"; query = Dict("feed" => feed))
    return _parse_trade(symbol, resp.trade)
end

"""
    get_snapshot(client, symbols; feed="iex")

Snapshot aggregates latest trade, latest quote, minute bar, daily bar, and
previous daily bar for each symbol. Returns raw `JSON3` keyed by symbol.
"""
function get_snapshot(client::AlpacaClient,
                      symbols::Union{AbstractString,AbstractVector};
                      feed::AbstractString = "iex")
    q = Dict("symbols" => _symbols_param(symbols), "feed" => feed)
    return _data_get(client, "/stocks/snapshots"; query = q)
end
