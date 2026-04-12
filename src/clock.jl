"""
    get_clock(client)

Current server time plus whether the US equity market is open, and the
next open / close timestamps.
"""
function get_clock(client::AlpacaClient)
    o = _trading_get(client, "/clock")
    return MarketClock(
        _parse_rfc3339(String(o.timestamp)),
        Bool(o.is_open),
        _parse_rfc3339(String(o.next_open)),
        _parse_rfc3339(String(o.next_close)),
    )
end

"""
    get_calendar(client; start=nothing, finish=nothing)

Trading calendar between `start` and `finish` (inclusive). Dates may be
passed as `Date` or ISO `"YYYY-MM-DD"` strings.
"""
function get_calendar(client::AlpacaClient;
                      start::Union{Date,AbstractString,Nothing} = nothing,
                      finish::Union{Date,AbstractString,Nothing} = nothing)
    q = Dict{String,Any}()
    start  === nothing || (q["start"]  = string(start))
    finish === nothing || (q["end"]    = string(finish))
    arr = _trading_get(client, "/calendar"; query = q)
    out = CalendarDay[]
    for d in arr
        push!(out, CalendarDay(
            Date(String(d.date)),
            Time(String(d.open)),
            Time(String(d.close)),
            haskey(d, :session_open)  ? Time(String(d.session_open))  : nothing,
            haskey(d, :session_close) ? Time(String(d.session_close)) : nothing,
        ))
    end
    return out
end
