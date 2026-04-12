# Live tests against the real Alpaca paper API. Skipped by default so the
# suite can run offline and in CI without credentials. Enable with:
#
#   ALPACA_LIVE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()'
#
# Requires conf/apiidata.toml (or a path supplied via ALPACA_CREDS).

const _LIVE = get(ENV, "ALPACA_LIVE_TESTS", "0") == "1"

if _LIVE
    @testset "integration (live paper API)" begin
        creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apiidata.toml"))
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
else
    @info "skipping live integration tests (set ALPACA_LIVE_TESTS=1 to enable)"
end
