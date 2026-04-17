# Capture a point-in-time options snapshot (bid/ask + greeks + IV) for a
# single underlying. Complements `download_options_historical.jl`:
#
#   historical script → fixed past date, OHLCV at that day's close
#   snapshot script   → right-now quote + greeks, timestamped for rolling logs
#
# The output filename embeds the capture timestamp so running this on a
# schedule (cron, launchd, a Julia loop) builds up a time-series dataset
# without overwriting previous captures.
#
# Run from the project root:
#
#   julia --project=. examples/download_options_snapshot.jl
#
# Overrides via environment variables (same as the historical script):
#
#   ALPACA_UNDERLYING=SPY
#   ALPACA_DTE=30
#   ALPACA_DTE_TOLERANCE=7
#   ALPACA_STRIKE_MIN=100
#   ALPACA_STRIKE_MAX=300
#   ALPACA_OPTION_TYPE=call          # "call" | "put" | unset
#   ALPACA_OUT_DIR=data/options

using Alpaca
using Dates

# ── configuration ─────────────────────────────────────────────────────
const UNDERLYING    = get(ENV, "ALPACA_UNDERLYING", "AAPL")
const TARGET_DTE    = parse(Int, get(ENV, "ALPACA_DTE", "30"))
const DTE_TOLERANCE = parse(Int, get(ENV, "ALPACA_DTE_TOLERANCE", "7"))
const STRIKE_MIN    = haskey(ENV, "ALPACA_STRIKE_MIN") ? parse(Float64, ENV["ALPACA_STRIKE_MIN"]) : nothing
const STRIKE_MAX    = haskey(ENV, "ALPACA_STRIKE_MAX") ? parse(Float64, ENV["ALPACA_STRIKE_MAX"]) : nothing
const OPTION_TYPE   = get(ENV, "ALPACA_OPTION_TYPE", "")
const OUT_DIR       = get(ENV, "ALPACA_OUT_DIR", "data/options")

const BATCH_SIZE = 50

# ── preflight ─────────────────────────────────────────────────────────
today_date = today()
target_exp = today_date + Day(TARGET_DTE)
exp_lo     = target_exp  - Day(DTE_TOLERANCE)
exp_hi     = target_exp  + Day(DTE_TOLERANCE)

println("── config ───────────────────────────────")
println("  underlying:          ", UNDERLYING)
println("  today:               ", today_date)
println("  target expiration:   ", target_exp, "  (", TARGET_DTE, " DTE)")
println("  expiration window:   ", exp_lo, " → ", exp_hi)
STRIKE_MIN === nothing || println("  strike ≥             ", STRIKE_MIN)
STRIKE_MAX === nothing || println("  strike ≤             ", STRIKE_MAX)
isempty(OPTION_TYPE)   || println("  type filter:         ", OPTION_TYPE)
println("  output dir:          ", OUT_DIR)

client = load_client()

println("\n── preflight ────────────────────────────")
acct = get_account(client)
println("  account: ", acct.status, "  cash=", acct.cash)
spot_quote = get_latest_quote(client, UNDERLYING)
spot = (spot_quote.bid_price + spot_quote.ask_price) / 2
println("  ", UNDERLYING, " bid=", spot_quote.bid_price,
        "  ask=", spot_quote.ask_price, "  mid≈", round(spot; digits = 2))

# Fetch the underlying's most recent daily bar (close price for moneyness)
under_bars_map = get_bars(client, UNDERLYING, "1Day";
                          start = today_date - Day(7), finish = today_date)
under_list = get(under_bars_map, UNDERLYING, Alpaca.Bar[])
if isempty(under_list)
    println("  !! no recent daily bars for ", UNDERLYING, " — aborting")
    exit(1)
end
under_bar = last(under_list)
underlying_close = under_bar.c
println("  ", UNDERLYING, " close (", Date(under_bar.t), "): ", underlying_close)

# ── 1. Discover contracts in the expiration window ──────────────────
println("\n── discovering contracts ────────────────")
contracts = list_option_contracts(client;
                                  underlying_symbols   = UNDERLYING,
                                  expiration_date_gte  = exp_lo,
                                  expiration_date_lte  = exp_hi,
                                  strike_price_gte     = STRIKE_MIN,
                                  strike_price_lte     = STRIKE_MAX,
                                  type                 = isempty(OPTION_TYPE) ? nothing : OPTION_TYPE)

if isempty(contracts)
    println("  !! no contracts found in window — check dates / filters")
    exit(1)
end

expirations = sort(unique(c.expiration_date for c in contracts))
println("  found ", length(contracts), " contracts across ",
        length(expirations), " expiration(s): ", join(string.(expirations), ", "))

contract_by_symbol = Dict(c.symbol => c for c in contracts)

# ── 2. Fetch snapshots (greeks + IV + latest quote) in batches ──────
capture_ts = now(UTC)
println("\n── fetching snapshots @ ", capture_ts, " UTC ──")
symbols  = collect(keys(contract_by_symbol))
nbatch   = cld(length(symbols), BATCH_SIZE)
all_snaps = Dict{String,Alpaca.OptionSnapshot}()

for i in 1:BATCH_SIZE:length(symbols)
    chunk = symbols[i:min(i + BATCH_SIZE - 1, length(symbols))]
    batch_idx = (i - 1) ÷ BATCH_SIZE + 1
    print("  [batch ", batch_idx, "/", nbatch, "] ", length(chunk), " symbols ... ")
    got = get_option_snapshots(client, chunk)
    merge!(all_snaps, got)
    got_greeks = count(s -> s.greeks !== nothing, values(got))
    println(length(got), " returned  (", got_greeks, " with greeks)")
end

# ── 3. Join + write CSV ─────────────────────────────────────────────
mkpath(OUT_DIR)
tag = Dates.format(capture_ts, dateformat"yyyymmdd_HHMMSS")
out_path = joinpath(OUT_DIR, "$(UNDERLYING)_snapshot_$(tag).csv")

_fmt(x::Nothing) = ""
_fmt(x)          = string(x)

rows_written = Ref(0)

open(out_path, "w") do io
    println(io, "capture_ts,symbol,underlying,expiration,type,strike,dte,",
                "bid,bid_size,ask,ask_size,mid,last_price,last_size,",
                "implied_vol,delta,gamma,theta,vega,rho,underlying_close")

    for (sym, c) in contract_by_symbol
        snap = get(all_snaps, sym, nothing)
        snap === nothing && continue

        lq = snap.latest_quote
        lt = snap.latest_trade
        gr = snap.greeks
        dte = Dates.value(c.expiration_date - today_date)

        bid      = lq === nothing ? nothing : lq.bid_price
        bid_size = lq === nothing ? nothing : lq.bid_size
        ask      = lq === nothing ? nothing : lq.ask_price
        ask_size = lq === nothing ? nothing : lq.ask_size
        mid      = (bid === nothing || ask === nothing) ? nothing : (bid + ask) / 2

        last_px   = lt === nothing ? nothing : lt.price
        last_size = lt === nothing ? nothing : lt.size

        println(io,
            capture_ts, ",",
            sym, ",",
            c.underlying_symbol, ",",
            c.expiration_date, ",",
            c.type, ",",
            c.strike_price, ",",
            dte, ",",
            _fmt(bid),      ",", _fmt(bid_size), ",",
            _fmt(ask),      ",", _fmt(ask_size), ",",
            _fmt(mid),      ",",
            _fmt(last_px),  ",", _fmt(last_size), ",",
            _fmt(snap.implied_volatility), ",",
            _fmt(gr === nothing ? nothing : gr.delta), ",",
            _fmt(gr === nothing ? nothing : gr.gamma), ",",
            _fmt(gr === nothing ? nothing : gr.theta), ",",
            _fmt(gr === nothing ? nothing : gr.vega),  ",",
            _fmt(gr === nothing ? nothing : gr.rho),   ",",
            underlying_close)
        rows_written[] += 1
    end
end

# ── summary ──────────────────────────────────────────────────────────
println("\n── summary ──────────────────────────────")
println("  contracts in window:  ", length(contracts))
println("  rows written:         ", rows_written[])
println("  wrote: ", out_path)

# Sample ATM rows
traded = [c for c in contracts if haskey(all_snaps, c.symbol)]
sort!(traded; by = c -> abs(c.strike_price - spot))
if !isempty(traded)
    println("\n  sample (closest-to-spot first; spot ≈ ", round(spot; digits = 2), "):")
    println("  ",
            rpad("symbol", 24),
            rpad("exp", 12),
            rpad("type", 6),
            rpad("strike", 10),
            rpad("bid", 10),
            rpad("ask", 10),
            rpad("iv", 9),
            rpad("delta", 9),
            rpad("theta", 9))
    for c in Iterators.take(traded, 12)
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
        println("  ",
                rpad(c.symbol, 24),
                rpad(string(c.expiration_date), 12),
                rpad(c.type, 6),
                rpad(c.strike_price, 10),
                rpad(bid, 10),
                rpad(ask, 10),
                rpad(iv, 9),
                rpad(dlt, 9),
                rpad(tht, 9))
    end
end
