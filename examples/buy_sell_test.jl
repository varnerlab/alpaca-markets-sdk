# Round-trip connectivity test against the Alpaca paper trading API.
#
# Submits a small market BUY, waits for the fill, verifies the position,
# submits an offsetting market SELL, waits for that fill, and confirms
# we're flat again. When the market is closed the order will not fill —
# the script detects that, cancels the order, and exits cleanly.
#
# Run from the project root:
#
#   julia --project=. examples/buy_sell_test.jl
#
# Optional environment overrides:
#
#   ALPACA_TEST_SYMBOL=SPY  ALPACA_TEST_QTY=1  julia --project=. examples/buy_sell_test.jl

using Alpaca
using Dates

const SYMBOL       = get(ENV, "ALPACA_TEST_SYMBOL", "AAPL")
const QTY          = parse(Int, get(ENV, "ALPACA_TEST_QTY", "1"))
const POLL_TIMEOUT = parse(Int, get(ENV, "ALPACA_POLL_SECONDS", "20"))
const POLL_INTERVAL = 1.0

const TERMINAL_STATES = Set(["filled", "canceled", "rejected", "expired", "done_for_day"])

function banner(msg)
    println("\n── ", msg, " ", repeat("─", max(0, 40 - length(msg))))
end

"""
Poll `get_order` until the order reaches a terminal status, or until
`timeout` seconds have elapsed. Returns the final `Order` on success,
`nothing` on timeout.
"""
function wait_for_terminal(client, order_id; timeout = POLL_TIMEOUT)
    deadline = time() + timeout
    local latest
    while time() < deadline
        latest = get_order(client, order_id)
        println("  [poll] status=", latest.status,
                "  filled_qty=", latest.filled_qty,
                latest.filled_avg_price === nothing ? "" : "  avg=$(latest.filled_avg_price)")
        latest.status in TERMINAL_STATES && return latest
        sleep(POLL_INTERVAL)
    end
    return nothing
end

function position_qty(client, symbol)
    for p in list_positions(client)
        p.symbol == symbol && return p.qty
    end
    return 0.0
end

# ──────────────────────────────────────────────────────────────────────
client = load_client()

banner("preflight")
acct_before = get_account(client)
clk = get_clock(client)
println("  account:     ", acct_before.status, "  cash=", acct_before.cash,
        "  equity=", acct_before.equity)
println("  market open: ", clk.is_open, "  (server time ", clk.timestamp, ")")
if !clk.is_open
    println("  !! market is closed — next open ", clk.next_open)
    println("     a market/day order will queue and will not fill until then.")
    println("     this script will submit, then cancel, to verify connectivity.")
end

q = get_latest_quote(client, SYMBOL)
println("  quote ", SYMBOL, ":  bid=", q.bid_price, "  ask=", q.ask_price,
        "  (as of ", q.t, ")")

existing = position_qty(client, SYMBOL)
if existing != 0
    println("  !! already holding ", existing, " ", SYMBOL,
            " — refusing to run. Close the position first.")
    exit(1)
end

# ── BUY ───────────────────────────────────────────────────────────────
banner("buy")
println("  submitting BUY ", QTY, " ", SYMBOL, " market/day")
buy = submit_order(client, SYMBOL, QTY, "buy";
                   type = "market", time_in_force = "day")
println("  order id: ", buy.id)

buy_final = wait_for_terminal(client, buy.id)
if buy_final === nothing
    println("  !! buy did not reach terminal status in $(POLL_TIMEOUT)s — canceling")
    try
        cancel_order(client, buy.id)
        println("  canceled.")
    catch e
        @warn "cancel failed" exception = e
    end
    println("\nconnectivity verified up to submit + cancel.")
    println("re-run during market hours for a full round-trip.")
    exit(0)
end

if buy_final.status != "filled"
    println("  !! buy reached terminal status \"", buy_final.status, "\" — aborting")
    exit(1)
end
println("  filled: qty=", buy_final.filled_qty, "  avg=", buy_final.filled_avg_price)

# ── position check ────────────────────────────────────────────────────
banner("position")
pos = get_position(client, SYMBOL)
println("  ", pos.symbol, "  qty=", pos.qty,
        "  avg_entry=", pos.avg_entry_price,
        "  market_value=", pos.market_value,
        "  unrealized_pl=", pos.unrealized_pl)

# ── SELL ──────────────────────────────────────────────────────────────
banner("sell")
println("  submitting SELL ", QTY, " ", SYMBOL, " market/day")
sell = submit_order(client, SYMBOL, QTY, "sell";
                    type = "market", time_in_force = "day")
println("  order id: ", sell.id)

sell_final = wait_for_terminal(client, sell.id)
if sell_final === nothing
    println("  !! sell did not fill in $(POLL_TIMEOUT)s — check the Alpaca dashboard")
    exit(1)
end
if sell_final.status != "filled"
    println("  !! sell reached terminal status \"", sell_final.status, "\" — aborting")
    exit(1)
end
println("  filled: qty=", sell_final.filled_qty, "  avg=", sell_final.filled_avg_price)

# ── flat? ─────────────────────────────────────────────────────────────
banner("wrap-up")
remaining = position_qty(client, SYMBOL)
if remaining == 0
    println("  flat in ", SYMBOL, " — round trip complete")
else
    println("  !! still holding ", remaining, " ", SYMBOL)
end

acct_after = get_account(client)
Δequity = acct_after.equity - acct_before.equity
Δcash   = acct_after.cash   - acct_before.cash
println("  equity Δ = ", round(Δequity; digits = 4),
        "   cash Δ = ", round(Δcash; digits = 4))
println("\nconnectivity verified: submit → poll → fill → position → submit → fill → flat")
