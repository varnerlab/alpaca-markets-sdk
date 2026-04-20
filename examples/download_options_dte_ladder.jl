# Capture a point-in-time options snapshot (bid/ask + greeks + IV)
# across a ladder of target DTE values, joined with the underlying's
# most recent session OHLCV + VWAP.
#
# Designed to be run once per evening to accumulate a rolling dataset:
# the output filename embeds the UTC capture timestamp down to the
# second, so repeated runs never overwrite each other.
#
# For each contract we find the target DTE bucket it's closest to
# (within `DTE_TOLERANCE` days). Contracts outside every bucket are
# dropped. A contract is assigned to exactly one bucket — whichever
# target DTE is nearest.
#
# Run from the project root:
#
#   julia --project=. examples/download_options_dte_ladder.jl
#
# Overrides:
#   ALPACA_UNDERLYING=AAPL
#   ALPACA_DTE_LADDER="2,7,14,30,45,60,90"      # comma-separated ints
#   ALPACA_DTE_TOLERANCE=3
#   ALPACA_STRIKE_MIN=100                        # optional
#   ALPACA_STRIKE_MAX=400                        # optional
#   ALPACA_OPTION_TYPE=call                      # "call" | "put" | unset
#   ALPACA_OUT_DIR=data/options-mm-dd-yy  (default: today, e.g. data/options-04-20-26)

using Alpaca
using Dates

# ── configuration ─────────────────────────────────────────────────────
const UNDERLYING     = get(ENV, "ALPACA_UNDERLYING", "AAPL")
const DTE_LADDER_STR = get(ENV, "ALPACA_DTE_LADDER", "2,7,14,30,45,60,90")
const DTE_LADDER     = sort(unique([parse(Int, strip(s)) for s in split(DTE_LADDER_STR, ",")]))
const DTE_TOLERANCE  = parse(Int, get(ENV, "ALPACA_DTE_TOLERANCE", "3"))
const STRIKE_MIN     = haskey(ENV, "ALPACA_STRIKE_MIN") ? parse(Float64, ENV["ALPACA_STRIKE_MIN"]) : nothing
const STRIKE_MAX     = haskey(ENV, "ALPACA_STRIKE_MAX") ? parse(Float64, ENV["ALPACA_STRIKE_MAX"]) : nothing
const OPTION_TYPE    = get(ENV, "ALPACA_OPTION_TYPE", "")
const OUT_DIR        = get(ENV, "ALPACA_OUT_DIR",
                            "data/options-" * Dates.format(today(), dateformat"mm-dd-yy"))

const BATCH_SIZE = 50

# ── preflight ─────────────────────────────────────────────────────────
today_date = today()
min_target = minimum(DTE_LADDER)
max_target = maximum(DTE_LADDER)
exp_lo     = today_date + Day(max(0, min_target - DTE_TOLERANCE))
exp_hi     = today_date + Day(max_target + DTE_TOLERANCE)

println("── config ───────────────────────────────")
println("  underlying:        ", UNDERLYING)
println("  today:             ", today_date)
println("  DTE ladder:        ", DTE_LADDER)
println("  tolerance:         ±", DTE_TOLERANCE, " days")
println("  expiration window: ", exp_lo, " → ", exp_hi)
STRIKE_MIN === nothing || println("  strike ≥           ", STRIKE_MIN)
STRIKE_MAX === nothing || println("  strike ≤           ", STRIKE_MAX)
isempty(OPTION_TYPE)   || println("  type filter:       ", OPTION_TYPE)
println("  output dir:        ", OUT_DIR)

client = load_client()

# ── 1. Account + underlying session bar (for spot & VWAP) ────────────
println("\n── preflight ────────────────────────────")
acct = get_account(client)
println("  account: ", acct.status, "  cash=", acct.cash)

# Grab the last full daily bar for the underlying. Going back a week
# is enough to survive a Monday morning run or a market holiday.
under_bars_map = get_bars(client, UNDERLYING, "1Day";
                          start = today_date - Day(7), finish = today_date)
under_list = get(under_bars_map, UNDERLYING, Alpaca.Bar[])
if isempty(under_list)
    println("  !! no recent daily bars for ", UNDERLYING, " — aborting")
    exit(1)
end
under_bar = last(under_list)
spot = under_bar.c
println("  ", UNDERLYING, " session ", Date(under_bar.t),
        ":  O=", under_bar.o, " H=", under_bar.h, " L=", under_bar.l,
        " C=", under_bar.c)
println("    volume=", under_bar.v,
        "  vwap=", under_bar.vw === nothing ? "—" : under_bar.vw)

# Also grab a live quote for sanity + mid used in ATM sorting
spot_quote = get_latest_quote(client, UNDERLYING)
live_mid = (spot_quote.bid_price + spot_quote.ask_price) / 2
println("  live quote:  bid=", spot_quote.bid_price,
        "  ask=", spot_quote.ask_price,
        "  mid≈", round(live_mid; digits = 2))

# ── 2. Discover contracts across the full expiration window ─────────
println("\n── discovering contracts ────────────────")
contracts = list_option_contracts(client;
                                  underlying_symbols  = UNDERLYING,
                                  expiration_date_gte = exp_lo,
                                  expiration_date_lte = exp_hi,
                                  strike_price_gte    = STRIKE_MIN,
                                  strike_price_lte    = STRIKE_MAX,
                                  type                = isempty(OPTION_TYPE) ? nothing : OPTION_TYPE)

if isempty(contracts)
    println("  !! no contracts in window; widen ladder/tolerance")
    exit(1)
end
println("  ", length(contracts), " total contracts in window")

# ── 3. Assign each contract to its nearest DTE bucket ───────────────
function nearest_bucket(actual_dte::Integer, targets::Vector{Int}, tolerance::Int)
    best_target = nothing
    best_dist   = tolerance + 1
    for t in targets
        d = abs(actual_dte - t)
        if d <= tolerance && d < best_dist
            best_dist   = d
            best_target = t
        end
    end
    return best_target
end

bucketed = Tuple{Int,Alpaca.OptionContract}[]
for c in contracts
    dte = Dates.value(c.expiration_date - today_date)
    b   = nearest_bucket(dte, DTE_LADDER, DTE_TOLERANCE)
    b === nothing && continue
    push!(bucketed, (b, c))
end

println("\n  bucket occupancy (target DTE → contracts matched):")
bucket_counts = Dict{Int,Int}()
for (b, _) in bucketed
    bucket_counts[b] = get(bucket_counts, b, 0) + 1
end
for t in DTE_LADDER
    n = get(bucket_counts, t, 0)
    marker = n == 0 ? "   <empty>" : ""
    println("    DTE ", lpad(t, 3), ": ", lpad(n, 4), " contracts", marker)
end

if isempty(bucketed)
    println("  !! no contracts matched any bucket; try widening --tolerance")
    exit(1)
end

# ── 4. Batch-fetch snapshots ─────────────────────────────────────────
println("\n── fetching snapshots ───────────────────")
capture_ts = now(UTC)
symbols = unique!([c.symbol for (_, c) in bucketed])
nbatch  = cld(length(symbols), BATCH_SIZE)
all_snaps = Dict{String,Alpaca.OptionSnapshot}()

for i in 1:BATCH_SIZE:length(symbols)
    chunk = symbols[i:min(i + BATCH_SIZE - 1, length(symbols))]
    idx   = (i - 1) ÷ BATCH_SIZE + 1
    print("  [batch ", idx, "/", nbatch, "] ", length(chunk), " symbols ... ")
    got   = get_option_snapshots(client, chunk)
    merge!(all_snaps, got)
    with_greeks = count(s -> s.greeks !== nothing, values(got))
    println(length(got), " returned  (", with_greeks, " with greeks)")
end

# ── 5. Write CSV (flattened: one row per contract) ───────────────────
mkpath(OUT_DIR)
tag = Dates.format(capture_ts, dateformat"yyyymmdd_HHMMSS")
out_path = joinpath(OUT_DIR, "$(UNDERLYING)_dte_ladder_$(tag).csv")

_fmt(x::Nothing) = ""
_fmt(x)          = string(x)

rows_written = Ref(0)
missing_snap = Ref(0)

open(out_path, "w") do io
    println(io,
        "capture_ts,target_dte,actual_dte,symbol,underlying,expiration,type,strike,",
        "bid,bid_size,ask,ask_size,mid,last_price,last_size,",
        "implied_vol,delta,gamma,theta,vega,rho,",
        "und_session_date,und_open,und_high,und_low,und_close,und_volume,und_vwap")

    for (bucket, c) in bucketed
        snap = get(all_snaps, c.symbol, nothing)
        if snap === nothing
            missing_snap[] += 1
            continue
        end

        lq  = snap.latest_quote
        lt  = snap.latest_trade
        gr  = snap.greeks
        dte = Dates.value(c.expiration_date - today_date)

        bid = lq === nothing ? nothing : lq.bid_price
        ask = lq === nothing ? nothing : lq.ask_price
        bsz = lq === nothing ? nothing : lq.bid_size
        asz = lq === nothing ? nothing : lq.ask_size
        mid = (bid === nothing || ask === nothing) ? nothing : (bid + ask) / 2
        lp  = lt === nothing ? nothing : lt.price
        ls  = lt === nothing ? nothing : lt.size

        println(io,
            capture_ts, ",", bucket, ",", dte, ",",
            c.symbol, ",", c.underlying_symbol, ",", c.expiration_date, ",",
            c.type, ",", c.strike_price, ",",
            _fmt(bid), ",", _fmt(bsz), ",",
            _fmt(ask), ",", _fmt(asz), ",",
            _fmt(mid), ",",
            _fmt(lp),  ",", _fmt(ls), ",",
            _fmt(snap.implied_volatility), ",",
            _fmt(gr === nothing ? nothing : gr.delta), ",",
            _fmt(gr === nothing ? nothing : gr.gamma), ",",
            _fmt(gr === nothing ? nothing : gr.theta), ",",
            _fmt(gr === nothing ? nothing : gr.vega),  ",",
            _fmt(gr === nothing ? nothing : gr.rho),   ",",
            Date(under_bar.t), ",",
            under_bar.o, ",", under_bar.h, ",", under_bar.l, ",",
            under_bar.c, ",", under_bar.v, ",",
            _fmt(under_bar.vw))
        rows_written[] += 1
    end
end

# ── summary ──────────────────────────────────────────────────────────
println("\n── summary ──────────────────────────────")
println("  bucketed contracts:     ", length(bucketed))
println("  rows written:           ", rows_written[])
println("  contracts missing snap: ", missing_snap[])
println("  wrote: ", out_path)

# Sample: a couple of ATM rows per bucket
println("\n  sample (one ATM call + put per bucket):")
println("  ",
        rpad("dte", 5),
        rpad("exp", 12),
        rpad("type", 6),
        rpad("strike", 10),
        rpad("bid", 9),
        rpad("ask", 9),
        rpad("iv", 9),
        rpad("delta", 9),
        rpad("theta", 9))

for target in DTE_LADDER
    bucket_contracts = [c for (b, c) in bucketed if b == target && haskey(all_snaps, c.symbol)]
    isempty(bucket_contracts) && continue
    sort!(bucket_contracts; by = c -> abs(c.strike_price - live_mid))
    shown_call = false
    shown_put  = false
    for c in bucket_contracts
        (shown_call && shown_put) && break
        c.type == "call" && shown_call && continue
        c.type == "put"  && shown_put  && continue
        s  = all_snaps[c.symbol]
        lq = s.latest_quote
        gr = s.greeks
        bid = lq === nothing ? "—" : string(lq.bid_price)
        ask = lq === nothing ? "—" : string(lq.ask_price)
        iv  = s.implied_volatility === nothing ? "—" :
              string(round(s.implied_volatility; digits = 4))
        dlt = (gr === nothing || gr.delta === nothing) ? "—" :
              string(round(gr.delta; digits = 4))
        tht = (gr === nothing || gr.theta === nothing) ? "—" :
              string(round(gr.theta; digits = 4))
        actual_dte = Dates.value(c.expiration_date - today_date)
        println("  ",
                rpad(actual_dte, 5),
                rpad(string(c.expiration_date), 12),
                rpad(c.type, 6),
                rpad(c.strike_price, 10),
                rpad(bid, 9),
                rpad(ask, 9),
                rpad(iv, 9),
                rpad(dlt, 9),
                rpad(tht, 9))
        c.type == "call" && (shown_call = true)
        c.type == "put"  && (shown_put  = true)
    end
end
