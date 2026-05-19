# Live tests against the real Alpaca paper API. Skipped by default so the
# suite can run offline and in CI without credentials. Enable with:
#
#   ALPACA_LIVE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()'
#
# Requires conf/apidata.toml (or a path supplied via ALPACA_CREDS).

const _LIVE = get(ENV, "ALPACA_LIVE_TESTS", "0") == "1"

if _LIVE
    @testset "integration (live paper API)" begin
        creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apidata.toml"))
        @test isfile(creds_path)

        client = load_client(creds_path)
        acct = get_account(client)
        @test acct.status == "ACTIVE"
        @test acct.currency == "USD"
        @test acct.cash >= 0

        clk = get_clock(client)
        @test clk isa MarketClock

        q = get_latest_quote(client, "AAPL")
        @test q.symbol == "AAPL"
        @test q.bid_price > 0 || q.ask_price > 0
    end

    @testset "integration: multi-leg options (live paper API)" begin
        creds_path = get(ENV, "ALPACA_CREDS",
                         joinpath(dirname(@__DIR__), "conf", "apidata.toml"))
        client = load_client(creds_path)

        # Find the nearest monthly expiry 30-45 DTE out.
        today  = Date(get_clock(client).timestamp)
        window_start = today + Day(30)
        window_end   = today + Day(45)

        chain = get_option_chain_snapshot(client, "SPY";
                                          type = "put",
                                          expiration_date_gte = window_start,
                                          expiration_date_lte = window_end,
                                          limit = 1000)

        @test !isempty(chain)  # expected at least one SPY put in the 30-45 DTE window

        # Group snapshots by expiry date parsed out of the OCC symbol
        # (positions 5:10 of an OCC symbol are YYMMDD after the root).
        function _occ_expiry(sym::AbstractString, root::AbstractString = "SPY")
            yymmdd = sym[length(root)+1 : length(root)+6]
            return Date("20" * yymmdd, dateformat"yyyymmdd")
        end

        by_exp = Dict{Date,Vector{OptionSnapshot}}()
        for (sym, snap) in chain
            d = _occ_expiry(sym)
            push!(get!(by_exp, d, OptionSnapshot[]), snap)
        end
        nearest_exp = minimum(keys(by_exp))
        puts_on_exp = by_exp[nearest_exp]

        # Short leg: closest |delta| to 0.30. The guard filters out snapshots
        # without delta, so `snap.greeks.delta` is non-nothing inside `abs(...)`.
        scored = [(snap, abs(snap.greeks.delta + 0.30))
                  for snap in puts_on_exp if snap.greeks !== nothing && snap.greeks.delta !== nothing]
        @test !isempty(scored)  # expected at least one put with delta available
        sort!(scored, by = x -> x[2])
        short_snap = scored[1][1]
        # Long leg: $5 OTM further (lower strike for a put).
        # Look up short strike from its OCC symbol (last 8 digits / 1000).
        function _occ_strike(sym::AbstractString)
            return parse(Int, sym[end-7:end]) / 1000
        end
        short_strike = _occ_strike(short_snap.symbol)
        long_target  = short_strike - 5.0
        long_snap = argmin(s -> abs(_occ_strike(s.symbol) - long_target), puts_on_exp)

        @info "smoke test selections" short = short_snap.symbol long = long_snap.symbol

        # --- Smoke 1: open & cancel a far-from-market spread ---
        legs = [
            OrderLeg(short_snap.symbol, 1, "sell", "sell_to_open"),
            OrderLeg(long_snap.symbol,  1, "buy",  "buy_to_open"),
        ]
        # Wildly-low credit so it won't fill.
        parent = submit_multileg_order(client, legs;
                                       type = "limit",
                                       limit_price = -0.01,
                                       qty = 1)
        @test parent.order_class == "mleg"
        @test parent.legs !== nothing
        @test length(parent.legs) == 2

        cancel_order(client, parent.id)
        sleep(5)
        after = get_order(client, parent.id)
        @test after.legs !== nothing
        @test all(l -> l.status in ("canceled", "pending_cancel"),
                  after.legs)  # cancel must have at least started for both legs
    end
else
    @info "skipping live integration tests (set ALPACA_LIVE_TESTS=1 to enable)"
end
