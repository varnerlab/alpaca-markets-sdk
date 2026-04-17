# Download options end-of-day data for a specific observation date.
#
# Example:  AAPL, observe 2026-04-07, 30 DTE (±7 days) contracts, at market close.
#
# Run from the project root:
#
#   julia --project=. examples/download_options_historical.jl
#
# Overrides via environment variables:
#
#   ALPACA_UNDERLYING=SPY                 # underlying ticker
#   ALPACA_OBSERVATION=2026-04-07         # date to capture (must be a past session)
#   ALPACA_DTE=30                         # target days-to-expiration
#   ALPACA_DTE_TOLERANCE=7                # ± days around the target expiration
#   ALPACA_STRIKE_MIN=100                 # optional strike floor
#   ALPACA_STRIKE_MAX=300                 # optional strike ceiling
#   ALPACA_OPTION_TYPE=call               # "call" | "put" | (unset = both)
#   ALPACA_OUT_DIR=data/options           # output directory
#
# What you get: a CSV at
#   <out_dir>/<underlying>_<observation>_<dte>DTE.csv
# with one row per contract that printed on the observation date, plus
# contract metadata (strike, expiration, call/put, actual DTE).

using Alpaca
using Dates

# ── configuration ─────────────────────────────────────────────────────
const UNDERLYING    = get(ENV, "ALPACA_UNDERLYING", "AAPL")
const OBSERVATION   = Date(get(ENV, "ALPACA_OBSERVATION", "2026-04-07"))
const TARGET_DTE    = parse(Int, get(ENV, "ALPACA_DTE", "30"))
const DTE_TOLERANCE = parse(Int, get(ENV, "ALPACA_DTE_TOLERANCE", "7"))
const STRIKE_MIN    = haskey(ENV, "ALPACA_STRIKE_MIN") ? parse(Float64, ENV["ALPACA_STRIKE_MIN"]) : nothing
const STRIKE_MAX    = haskey(ENV, "ALPACA_STRIKE_MAX") ? parse(Float64, ENV["ALPACA_STRIKE_MAX"]) : nothing
const OPTION_TYPE   = get(ENV, "ALPACA_OPTION_TYPE", "")      # "", "call", "put"
const OUT_DIR       = get(ENV, "ALPACA_OUT_DIR", "data/options")

const BATCH_SIZE = 50    # max option symbols per /options/bars request

# ── preflight ─────────────────────────────────────────────────────────
target_exp = OBSERVATION + Day(TARGET_DTE)
exp_lo     = target_exp  - Day(DTE_TOLERANCE)
exp_hi     = target_exp  + Day(DTE_TOLERANCE)

println("── config ───────────────────────────────")
println("  underlying:          ", UNDERLYING)
println("  observation date:    ", OBSERVATION)
println("  target expiration:   ", target_exp, "  (", TARGET_DTE, " DTE)")
println("  expiration window:   ", exp_lo, " → ", exp_hi)
STRIKE_MIN === nothing || println("  strike ≥             ", STRIKE_MIN)
STRIKE_MAX === nothing || println("  strike ≤             ", STRIKE_MAX)
isempty(OPTION_TYPE)   || println("  type filter:         ", OPTION_TYPE)
println("  output dir:          ", OUT_DIR)

client = load_client()

# Sanity: is the underlying quote available? (fast auth/endpoint check)
println("\n── preflight ────────────────────────────")
acct = get_account(client)
println("  account: ", acct.status, "  cash=", acct.cash)
underlying_quote = get_latest_quote(client, UNDERLYING)
println("  ", UNDERLYING, " latest quote: bid=", underlying_quote.bid_price,
        "  ask=", underlying_quote.ask_price)

# Fetch the underlying's daily bar on the observation date (close price)
under_bars_map = get_bars(client, UNDERLYING, "1Day";
                          start = OBSERVATION, finish = OBSERVATION)
under_list = get(under_bars_map, UNDERLYING, Alpaca.Bar[])
if isempty(under_list)
    println("  !! no daily bar for ", UNDERLYING, " on ", OBSERVATION, " — aborting")
    exit(1)
end
under_bar = under_list[1]
underlying_close = under_bar.c
println("  ", UNDERLYING, " close on ", OBSERVATION, ": ", underlying_close)

# ── 1. Discover contracts in the expiration window ───────────────────
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

# ── 2. Fetch daily bars for each contract on the observation date ────
println("\n── fetching daily bars for ", OBSERVATION, " ──")
symbols = [c.symbol for c in contracts]
all_bars = Dict{String,Vector{Alpaca.Bar}}()
nbatch   = cld(length(symbols), BATCH_SIZE)

for i in 1:BATCH_SIZE:length(symbols)
    chunk = symbols[i:min(i + BATCH_SIZE - 1, length(symbols))]
    batch_idx = (i - 1) ÷ BATCH_SIZE + 1
    print("  [batch ", batch_idx, "/", nbatch, "] ", length(chunk), " symbols ... ")
    got = get_option_bars(client, chunk, "1Day";
                          start = OBSERVATION, finish = OBSERVATION)
    merge!(all_bars, got)
    hit_count = count(k -> haskey(got, k) && !isempty(got[k]), chunk)
    println(hit_count, " traded")
end

# ── 3. Join + write CSV ──────────────────────────────────────────────
mkpath(OUT_DIR)
out_path = joinpath(OUT_DIR,
                    "$(UNDERLYING)_$(OBSERVATION)_$(TARGET_DTE)DTE.csv")

rows_written      = Ref(0)
missing_contracts = String[]

open(out_path, "w") do io
    println(io, "symbol,underlying,expiration,type,strike,dte,",
                "date,open,high,low,close,volume,trade_count,vwap,underlying_close")
    for c in contracts
        bar_list = get(all_bars, c.symbol, Alpaca.Bar[])
        if isempty(bar_list)
            push!(missing_contracts, c.symbol)
            continue
        end
        b = bar_list[1]   # only one daily bar per single-day window
        dte = Dates.value(c.expiration_date - OBSERVATION)
        println(io,
            c.symbol, ",",
            c.underlying_symbol, ",",
            c.expiration_date, ",",
            c.type, ",",
            c.strike_price, ",",
            dte, ",",
            Date(b.t), ",",
            b.o, ",", b.h, ",", b.l, ",", b.c, ",",
            b.v, ",",
            b.n === nothing ? "" : b.n, ",",
            b.vw === nothing ? "" : b.vw, ",",
            underlying_close)
        rows_written[] += 1
    end
end

# ── summary ──────────────────────────────────────────────────────────
println("\n── summary ──────────────────────────────")
println("  contracts in window:  ", length(contracts))
println("  contracts traded on ", OBSERVATION, ": ", rows_written[])
println("  contracts with no print (illiquid): ", length(missing_contracts))
println("  wrote: ", out_path)

# Pretty-print a handful of at-the-money rows so you can eyeball the data
spot = (underlying_quote.bid_price + underlying_quote.ask_price) / 2
if spot > 0
    println("\n  sample (closest-to-spot first; spot ≈ ", round(spot; digits = 2), "):")
    traded = [c for c in contracts if haskey(all_bars, c.symbol) && !isempty(all_bars[c.symbol])]
    sort!(traded; by = c -> abs(c.strike_price - spot))
    println("  ", rpad("symbol", 24), rpad("exp", 12), rpad("type", 6),
            rpad("strike", 10), rpad("dte", 6), rpad("close", 10), "volume")
    for c in Iterators.take(traded, 10)
        b = all_bars[c.symbol][1]
        dte = Dates.value(c.expiration_date - OBSERVATION)
        println("  ",
                rpad(c.symbol, 24),
                rpad(string(c.expiration_date), 12),
                rpad(c.type, 6),
                rpad(c.strike_price, 10),
                rpad(dte, 6),
                rpad(b.c, 10),
                b.v)
    end
end
