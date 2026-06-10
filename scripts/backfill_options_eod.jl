# Backfill missing EOD options-ladder days from Alpaca HISTORICAL data.
#
# Written for the 2026-06-05 → 2026-06-10 gap: cron julia crashes (macOS TCC,
# see pull_options_eod.sh preflight comment) dropped four sessions; 06-10 was
# recovered same-evening by rerunning the live pull, the rest must come from
# historical endpoints.
#
# What CAN be reconstructed (and is):
#   - the contract universe as of day D (active ∪ inactive contracts,
#     ladder expiration window, same DTE bucketing as the live pull)
#   - last_price        = the contract's 1Day bar close (== last trade of D)
#   - und_* columns     = the underlying's 1Day bar for D
# What CANNOT (Alpaca serves no historical options quotes or greeks — the
# /options/quotes historical endpoint 404s by design; snapshots are live-only):
#   - bid/bid_size/ask/ask_size/mid, implied_vol, delta/gamma/theta/vega/rho,
#     last_size → left EMPTY
# Contracts that never traded on D have no daily bar and are SKIPPED (the
# live pull keeps quoted-but-untraded contracts; a backfilled file is
# therefore a liquid-only subset — see the README this script drops in each
# output dir).
#
# Output mirrors the live layout so downstream loaders find it:
#   data/options-MM-DD-YY/<TICKER>_dte_ladder_backfill_<D>T200000.csv
#
# Run from the repo root (defaults to the three lost sessions):
#   julia --project=. scripts/backfill_options_eod.jl [YYYY-MM-DD ...]

using Alpaca
using Dates

const DATES = isempty(ARGS) ? [Date(2026, 6, 5), Date(2026, 6, 8), Date(2026, 6, 9)] :
                              [Date(a) for a in ARGS]

# Mirror pull_options_eod.sh / download_options_dte_ladder.jl defaults.
const TICKERS = [
    "AAPL", "AMD", "AVGO", "GOOG", "INTC", "META", "MSFT", "MU", "NVDA", "QCOM",
    "ABBV", "AMGN", "BMY", "JNJ", "LLY", "MRNA", "PFE", "UNH",
    "BAC", "GS", "JPM", "WFC",
    "CVX", "OXY", "XOM",
    "TGT", "UPS", "WMT",
    "IWM", "QQQ", "SPY",
]
const DTE_LADDER    = [2, 7, 14, 30, 45, 60, 90]
const DTE_TOLERANCE = 3
const BATCH_SIZE    = 50

# Same assignment rule as the live ladder script.
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

_fmt(x::Nothing) = ""
_fmt(x)          = string(x)

const README = """
# BACKFILLED DATA — read before using

Files matching `*_dte_ladder_backfill_*.csv` in this directory were
reconstructed from Alpaca HISTORICAL endpoints after the live 16:30 pull was
lost to a cron crash (2026-06-05..06-09; see pull_options_eod.sh preflight).

Differences from live captures:
- bid/bid_size/ask/ask_size/mid, implied_vol, and all greeks are EMPTY —
  Alpaca has no historical options quotes or greeks.
- last_price is the contract's daily-bar close (last trade of the session);
  last_size is empty.
- Only contracts that TRADED that day appear (no daily bar ⇒ skipped), so
  the file is a liquid-only subset of what the live ladder would have caught.
- capture_ts is set to the session close (20:00:00Z), not a real capture time.
"""

client = load_client()

for D in DATES
    # Holiday guard: skip dates with no trading session.
    cal = get_calendar(client; start = D, finish = D)
    if isempty(cal) || cal[1].date != D
        println("== $D is not a trading day — skipping")
        continue
    end

    out_dir = "data/options-" * Dates.format(D, dateformat"mm-dd-yy")
    mkpath(out_dir)
    write(joinpath(out_dir, "README-BACKFILL.md"), README)

    exp_lo = D + Day(max(0, minimum(DTE_LADDER) - DTE_TOLERANCE))
    exp_hi = D + Day(maximum(DTE_LADDER) + DTE_TOLERANCE)
    capture_ts = DateTime(D, Time(20, 0, 0))   # session close, UTC (16:00 ET)
    tag = Dates.format(capture_ts, dateformat"yyyymmdd_HHMMSS")

    println("== backfilling $D  (expirations $exp_lo → $exp_hi) ==")

    for T in TICKERS
        # Underlying session bar for D — without it the row tail is meaningless.
        und_map  = get_bars(client, T, "1Day"; start = D, finish = D + Day(1))
        und_list = [b for b in get(und_map, T, Alpaca.Bar[]) if Date(b.t) == D]
        if isempty(und_list)
            println("  $T: no underlying bar for $D — skipped")
            continue
        end
        und = und_list[end]

        # Contract universe as of D: expired ones have moved to "inactive".
        contracts = Alpaca.OptionContract[]
        for st in ("active", "inactive")
            append!(contracts, list_option_contracts(client;
                underlying_symbols  = T,
                status              = st,
                expiration_date_gte = exp_lo,
                expiration_date_lte = exp_hi))
        end
        unique!(c -> c.symbol, contracts)

        bucketed = Tuple{Int,Alpaca.OptionContract}[]
        for c in contracts
            dte = Dates.value(c.expiration_date - D)
            dte < 0 && continue                       # already expired on D
            b = nearest_bucket(dte, DTE_LADDER, DTE_TOLERANCE)
            b === nothing && continue
            push!(bucketed, (b, c))
        end
        if isempty(bucketed)
            println("  $T: no contracts in any DTE bucket — skipped")
            continue
        end

        # Daily bar per contract (close == last trade of D; absent ⇒ no trades).
        # Window note: without a signed OPRA agreement Alpaca 403s options
        # history whose query window touches the most recent session(s) —
        # the gate checks the requested start/end, NOT the returned bars
        # (verified 2026-06-10: start=06-08/end=06-09 returned 06-09's bar
        # while start=06-09 or end=06-10 both 403'd). Querying [D-4, D] and
        # filtering to Date(b.t)==D below keeps yesterday backfillable.
        symbols = unique!([c.symbol for (_, c) in bucketed])
        closes  = Dict{String,Alpaca.Bar}()
        for i in 1:BATCH_SIZE:length(symbols)
            chunk = symbols[i:min(i + BATCH_SIZE - 1, length(symbols))]
            bars  = get_option_bars(client, chunk, "1Day"; start = D - Day(4), finish = D)
            for (sym, arr) in bars
                day_bars = [b for b in arr if Date(b.t) == D]
                isempty(day_bars) || (closes[sym] = day_bars[end])
            end
        end

        out_path = joinpath(out_dir, "$(T)_dte_ladder_backfill_$(tag).csv")
        n_rows = 0
        open(out_path, "w") do io
            println(io,
                "capture_ts,target_dte,actual_dte,symbol,underlying,expiration,type,strike,",
                "bid,bid_size,ask,ask_size,mid,last_price,last_size,",
                "implied_vol,delta,gamma,theta,vega,rho,",
                "und_session_date,und_open,und_high,und_low,und_close,und_volume,und_vwap")
            for (bucket, c) in bucketed
                bar = get(closes, c.symbol, nothing)
                bar === nothing && continue            # never traded on D
                dte = Dates.value(c.expiration_date - D)
                println(io, join([
                    string(capture_ts), bucket, dte, c.symbol, T,
                    string(c.expiration_date), c.type, c.strike_price,
                    "", "", "", "", "",                # bid/bsz/ask/asz/mid
                    _fmt(bar.c), "",                   # last_price, last_size
                    "", "", "", "", "", "",            # IV + greeks
                    string(Date(und.t)), und.o, und.h, und.l, und.c,
                    und.v, _fmt(und.vw),
                ], ","))
                n_rows += 1
            end
        end
        println("  $T: $(length(bucketed)) bucketed, $n_rows traded rows → $out_path")
    end
end

println("\nbackfill done.")
