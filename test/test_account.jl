@testset "account: parse" begin
    payload = Dict(
        "id"                 => "db69e757-1522-4501-87a3-e6ec3248a6b2",
        "account_number"     => "PA123456",
        "status"             => "ACTIVE",
        "currency"           => "USD",
        "cash"               => "10000.00",
        "buying_power"       => "20000.00",
        "portfolio_value"    => "10500.50",
        "equity"             => "10500.50",
        "last_equity"        => "10000.00",
        "pattern_day_trader" => false,
        "trading_blocked"    => false,
        "transfers_blocked"  => false,
        "account_blocked"    => false,
    )

    handler = function(_req)
        return json_response(200, payload)
    end

    with_mock(handler) do client
        acct = get_account(client)
        @test acct isa Account
        @test acct.id == payload["id"]
        @test acct.status == "ACTIVE"
        @test acct.currency == "USD"
        @test acct.cash == 10000.00
        @test acct.buying_power == 20000.00
        @test acct.portfolio_value == 10500.50
        @test acct.equity == 10500.50
        @test acct.last_equity == 10000.00
        @test acct.pattern_day_trader == false
        @test acct.trading_blocked == false
    end
end
