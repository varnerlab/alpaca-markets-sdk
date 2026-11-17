@testset "deprecations: trading reads" begin
    with_mock(golden_handler) do c
        @test_deprecated get_account(c)
        @test_deprecated get_clock(c)
        @test_deprecated get_calendar(c)
        @test_deprecated list_assets(c)
        @test_deprecated get_asset(c, "AAPL")
        @test_deprecated list_positions(c)
        @test_deprecated get_position(c, "AAPL")
        @test_deprecated list_orders(c)
        @test_deprecated get_order(c, "ord-1")
        @test_deprecated list_option_contracts(c; underlying_symbols = "SPY")
        @test_deprecated get_option_contract(c, "SPY261218P00500000")
    end
end

@testset "deprecations: market data" begin
    opt_p = "SPY261218P00500000"
    opt_c = "SPY261218C00600000"
    with_mock(golden_handler) do c
        @test_deprecated get_bars(c, ["AAPL", "MSFT"], "1Day"; start = Date(2025, 1, 2), finish = Date(2025, 1, 3))
        @test_deprecated get_quotes(c, "AAPL"; start = DateTime(2025, 1, 2, 14, 30))
        @test_deprecated get_trades(c, "AAPL"; start = DateTime(2025, 1, 2, 14, 30), limit = 5)
        @test_deprecated get_latest_bar(c, "AAPL")
        @test_deprecated get_latest_quote(c, "AAPL")
        @test_deprecated get_latest_trade(c, "AAPL"; feed = "sip")
        @test_deprecated get_snapshot(c, ["AAPL", "MSFT"])
        @test_deprecated download_bars(c, "AAPL", "1Day"; start = Date(2025, 1, 1), finish = Date(2025, 3, 31), chunk_months = 1)
        @test_deprecated get_option_bars(c, [opt_p], "1Day"; start = Date(2026, 11, 2))
        @test_deprecated get_option_quotes(c, opt_p; start = Date(2026, 11, 2))
        @test_deprecated get_option_trades(c, opt_p; start = Date(2026, 11, 2), finish = Date(2026, 11, 3))
        @test_deprecated get_latest_option_bar(c, [opt_p, opt_c])
        @test_deprecated get_latest_option_quote(c, [opt_p, opt_c])
        @test_deprecated get_latest_option_trade(c, [opt_p, opt_c])
        @test_deprecated get_option_snapshots(c, [opt_p, opt_c])
        @test_deprecated get_option_chain_snapshot(c, "SPY"; type = "call", strike_price_gte = 140, expiration_date = Date(2026, 12, 18), limit = 2)

        # read_bars_csv reads a file that the private writer wrote -
        bars = Bar[Bar("AAPL", DateTime(2025, 1, 2), 1.0, 2.0, 0.5, 1.5, 100.0, 10, 1.2)]
        path = tempname() * ".csv"
        @test_deprecated write_bars_csv(path, bars)
        Alpaca._write_bars_csv(path, bars)
        @test_deprecated read_bars_csv(path)
        rm(path; force = true)
    end
end

@testset "legacy: a null contract list is an empty result" begin
    null_handler = req -> json_response(200, Dict("option_contracts" => nothing, "next_page_token" => nothing))
    with_mock(null_handler) do c
        result = @test_deprecated list_option_contracts(c; underlying_symbols = "SPY")
        @test result isa Vector{OptionContract}
        @test isempty(result)
    end
end
