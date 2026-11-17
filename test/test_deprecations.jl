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
