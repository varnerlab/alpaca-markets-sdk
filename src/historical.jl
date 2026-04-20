# Convenience helpers on top of `get_bars` for bulk historical downloads.
# Designed for the "grab me 10 years of 1-minute SPY bars, write it to a
# CSV I can feed into my simulator" use case. Zero new dependencies — CSVs
# are written with a hand-rolled serializer keyed on the fixed `Bar` layout.

const _BAR_CSV_HEADER = "timestamp,symbol,open,high,low,close,volume,trade_count,vwap"

"""
    write_bars_csv(path, bars::AbstractVector{Bar})

Write a vector of [`Bar`](@ref) records to `path` as CSV. The file has a
header row and one data row per bar:

```
timestamp,symbol,open,high,low,close,volume,trade_count,vwap
```

Timestamps are written as UTC ISO-8601 without the trailing `Z`.
Empty values are used when `trade_count` / `vwap` are missing.
"""
function write_bars_csv(path::AbstractString, bars::AbstractVector{Bar})
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        println(io, _BAR_CSV_HEADER)
        for b in bars
            print(io, Dates.format(b.t, dateformat"yyyy-mm-ddTHH:MM:SS"))
            print(io, ",", b.symbol)
            print(io, ",", b.o, ",", b.h, ",", b.l, ",", b.c)
            print(io, ",", b.v)
            print(io, ",", b.n  === nothing ? "" : b.n)
            print(io, ",", b.vw === nothing ? "" : b.vw)
            println(io)
        end
    end
    return path
end

"""
    read_bars_csv(path) -> Vector{Bar}

Parse a CSV written by [`write_bars_csv`](@ref) back into a vector of
[`Bar`](@ref) records. Useful for round-trip tests and for loading cached
data back into memory without a CSV dependency.
"""
function read_bars_csv(path::AbstractString)
    lines = readlines(path)
    isempty(lines) && return Bar[]
    bars = Bar[]
    sizehint!(bars, length(lines) - 1)
    for line in Iterators.drop(lines, 1)
        isempty(line) && continue
        f = split(line, ',')
        push!(bars, Bar(
            String(f[2]),
            DateTime(String(f[1])),
            parse(Float64, f[3]),
            parse(Float64, f[4]),
            parse(Float64, f[5]),
            parse(Float64, f[6]),
            parse(Float64, f[7]),
            isempty(f[8]) ? nothing : parse(Int, f[8]),
            isempty(f[9]) ? nothing : parse(Float64, f[9]),
        ))
    end
    return bars
end

# Convert either a Date or DateTime to a Date at day boundary for chunk math.
_as_date(x::Date)     = x
_as_date(x::DateTime) = Date(x)
_as_date(x::AbstractString) = Date(String(x))

function _month_chunks(start, finish, months::Integer)
    months > 0 || throw(ArgumentError("chunk_months must be positive"))
    s_date = _as_date(start)
    e_date = _as_date(finish)
    chunks = Tuple{Any,Any}[]
    cursor = s_date
    while cursor <= e_date
        next_end = min(e_date, cursor + Month(months) - Day(1))
        push!(chunks, (cursor, next_end))
        cursor = next_end + Day(1)
    end
    isempty(chunks) && return chunks
    # Splice caller's original start/finish onto the first/last chunk so
    # DateTime precision is preserved for intraday downloads.
    chunks[1]   = (start, chunks[1][2])
    chunks[end] = (chunks[end][1], finish)
    return chunks
end

"""
    download_bars(client, symbols, timeframe;
                  start,
                  finish        = nothing,
                  adjustment    = "raw",
                  feed          = "iex",
                  save_dir      = nothing,
                  chunk_months  = nothing,
                  verbose       = false)

Bulk historical bar download, built on top of [`get_bars`](@ref).

Arguments mirror `get_bars` (same `timeframe` strings: `"1Min"`, `"5Min"`,
`"15Min"`, `"1Hour"`, `"1Day"`, `"1Week"`, `"1Month"`, plus any valid
multiplier), with three download-specific extras:

- `save_dir`: if set, each symbol is written to
  `<save_dir>/<symbol>_<timeframe>.csv` via [`write_bars_csv`](@ref)
- `chunk_months`: split `start..finish` into this-many-month windows and
  fetch each separately. Doesn't change the total request count (pagination
  still happens under the hood), but gives you a tangible progress signal
  when pulling multi-year minute data. Leave as `nothing` for a single call.
- `verbose`: print per-chunk status to stdout

Returns `Dict{String,Vector{Bar}}` keyed by symbol, same as `get_bars`.
"""
function download_bars(client::AlpacaClient,
                       symbols::Union{AbstractString,AbstractVector},
                       timeframe::AbstractString;
                       start,
                       finish = nothing,
                       limit::Integer = 10_000,
                       adjustment::AbstractString = "raw",
                       feed::AbstractString = "iex",
                       save_dir::Union{AbstractString,Nothing} = nothing,
                       chunk_months::Union{Integer,Nothing} = nothing,
                       verbose::Bool = false)

    if chunk_months === nothing
        verbose && println("[download_bars] ", _symbols_desc(symbols),
                           " ", timeframe, " ", start, " → ", finish)
        result = get_bars(client, symbols, timeframe;
                          start = start, finish = finish, limit = limit,
                          adjustment = adjustment, feed = feed)
    else
        finish === nothing &&
            throw(ArgumentError("chunk_months requires an explicit `finish`"))
        result = Dict{String,Vector{Bar}}()
        chunks = _month_chunks(start, finish, chunk_months)
        total  = length(chunks)
        for (i, (cs, ce)) in enumerate(chunks)
            verbose && println("[download_bars $(i)/$(total)] ",
                               _symbols_desc(symbols), " ", timeframe, " ",
                               cs, " → ", ce)
            part = get_bars(client, symbols, timeframe;
                            start = cs, finish = ce, limit = limit,
                            adjustment = adjustment, feed = feed)
            for (sym, rows) in part
                bucket = get!(result, String(sym), Bar[])
                append!(bucket, rows)
            end
        end
    end

    if verbose
        total = sum(length(v) for v in values(result); init = 0)
        println("[download_bars] done: ", total, " bars across ",
                length(result), " symbol(s)")
    end

    if save_dir !== nothing
        mkpath(save_dir)
        tf_tag = replace(timeframe, " " => "")
        for (sym, rows) in result
            path = joinpath(save_dir, "$(sym)_$(tf_tag).csv")
            write_bars_csv(path, rows)
            verbose && println("[download_bars] wrote ", length(rows), " rows → ", path)
        end
    end

    return result
end

_symbols_desc(s::AbstractString) = s
_symbols_desc(s::AbstractVector) = "[" * join(s, ",") * "]"
