const _POSITION_PAYLOAD = Dict(
    "asset_id"         => "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415",
    "symbol"           => "AAPL",
    "exchange"         => "NASDAQ",
    "asset_class"      => "us_equity",
    "qty"              => "10",
    "side"             => "long",
    "avg_entry_price"  => "150.00",
    "market_value"     => "1600.00",
    "cost_basis"       => "1500.00",
    "unrealized_pl"    => "100.00",
    "unrealized_plpc"  => "0.0666",
    "current_price"    => "160.00",
    "lastday_price"    => "155.00",
    "change_today"     => "0.0322",
)

@testset "positions: list + get" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if uri.path == "/positions"
            return json_response(200, [_POSITION_PAYLOAD])
        elseif uri.path == "/positions/AAPL"
            return json_response(200, _POSITION_PAYLOAD)
        end
        return plain_response(404, "nope")
    end

    with_mock(handler) do client
        positions = list_positions(client)
        @test length(positions) == 1
        @test positions[1] isa Position
        @test positions[1].symbol == "AAPL"
        @test positions[1].qty == 10.0
        @test positions[1].unrealized_pl == 100.0
        @test positions[1].avg_entry_price == 150.0

        p = get_position(client, "AAPL")
        @test p.current_price == 160.0
    end
end

@testset "positions: close with qty / percentage" begin
    handler, log = recording_handler() do _req
        return json_response(200, _POSITION_PAYLOAD)
    end

    with_mock(handler) do client
        close_position(client, "AAPL"; qty = 5)
        close_position(client, "AAPL"; percentage = 50)
        close_position(client, "AAPL")
    end

    @test log[1].method == "DELETE"
    @test occursin("qty=5", log[1].query)
    @test occursin("percentage=50", log[2].query)
    @test log[3].query == ""  # full close carries no query
end
