# Quick connectivity check for the Alpaca paper-trading client.
#
# Run from the project root:
#   julia --project=. examples/smoke_test.jl

using Alpaca
using Dates

client = load_client()  # reads conf/apidata.toml

println("── account ─────────────────────────────")
acct = get_account(client)
println("  id:             ", acct.id)
println("  status:         ", acct.status)
println("  cash:           ", acct.cash, " ", acct.currency)
println("  equity:         ", acct.equity)
println("  buying power:   ", acct.buying_power)

println("\n── clock ───────────────────────────────")
clk = get_clock(client)
println("  server time:    ", clk.timestamp)
println("  market open?    ", clk.is_open)
println("  next open:      ", clk.next_open)
println("  next close:     ", clk.next_close)

println("\n── latest AAPL quote ───────────────────")
q = get_latest_quote(client, "AAPL")
println("  bid/ask: ", q.bid_price, " / ", q.ask_price, "  at ", q.t)

println("\n── AAPL daily bars, last 5 sessions ────")
bars = get_bars(client, "AAPL", "1Day";
                start = today() - Day(10),
                finish = today())
for b in last(bars["AAPL"], 5)
    println("  ", Date(b.t), "  O=", b.o, " H=", b.h, " L=", b.l, " C=", b.c, " V=", b.v)
end

println("\n── positions ───────────────────────────")
pos = list_positions(client)
isempty(pos) && println("  (none)")
for p in pos
    println("  ", p.symbol, "  qty=", p.qty, "  P/L=", p.unrealized_pl)
end
