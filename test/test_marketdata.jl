const _BAR_1 = Dict("t" => "2026-04-06T00:00:00Z", "o" => 256.5, "h" => 262.1,
                    "l" => 256.5, "c" => 258.9, "v" => 4.8e5, "n" => 12345, "vw" => 259.1)
const _BAR_2 = Dict("t" => "2026-04-07T00:00:00Z", "o" => 256.1, "h" => 256.2,
                    "l" => 245.7, "c" => 253.6, "v" => 1.3e6, "n" => 54321, "vw" => 251.2)

@testset "marketdata: bars auto-paginate" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if occursin("page_token=PAGE2", uri.query)
            return json_response(200, Dict(
                "bars"            => Dict("AAPL" => [_BAR_2]),
                "next_page_token" => nothing,
            ))
        end
        return json_response(200, Dict(
            "bars"            => Dict("AAPL" => [_BAR_1]),
            "next_page_token" => "PAGE2",
        ))
    end

    with_mock(handler) do client
        result = get_bars(client, "AAPL", "1Day";
                          start = Date(2026, 4, 6), finish = Date(2026, 4, 7))
        @test haskey(result, "AAPL")
        @test length(result["AAPL"]) == 2
        @test result["AAPL"][1].t == DateTime("2026-04-06T00:00:00")
        @test result["AAPL"][2].t == DateTime("2026-04-07T00:00:00")
        @test result["AAPL"][1].vw == 259.1
        @test result["AAPL"][1].n == 12345
    end

    @test length(log) == 2
    @test occursin("symbols=AAPL", log[1].query)
    @test occursin("timeframe=1Day", log[1].query)
    @test occursin("feed=iex", log[1].query)
    @test occursin("page_token=PAGE2", log[2].query)
end

@testset "marketdata: bars with multi-symbol vector" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict(
            "bars"            => Dict("AAPL" => [_BAR_1], "MSFT" => [_BAR_2]),
            "next_page_token" => nothing,
        ))
    end

    with_mock(handler) do client
        result = get_bars(client, ["AAPL", "MSFT"], "1Day"; start = Date(2026, 4, 6))
        @test sort(collect(keys(result))) == ["AAPL", "MSFT"]
        @test length(result["AAPL"]) == 1
        @test length(result["MSFT"]) == 1
    end

    @test occursin("symbols=AAPL%2CMSFT", log[1].query)
end

@testset "marketdata: latest quote / trade / bar" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if endswith(uri.path, "/quotes/latest")
            return json_response(200, Dict("quote" => Dict(
                "t" => "2026-04-11T20:00:00Z",
                "bp" => 246.87, "bs" => 1, "ap" => 247.01, "as" => 2,
                "bx" => "V", "ax" => "V",
            )))
        elseif endswith(uri.path, "/trades/latest")
            return json_response(200, Dict("trade" => Dict(
                "t" => "2026-04-11T20:00:00Z",
                "p" => 246.95, "s" => 100, "x" => "V", "i" => 42,
            )))
        elseif endswith(uri.path, "/bars/latest")
            return json_response(200, Dict("bar" => _BAR_1))
        end
        return plain_response(404, "nope")
    end

    with_mock(handler) do client
        q = get_latest_quote(client, "AAPL")
        @test q isa Quote
        @test q.bid_price == 246.87
        @test q.ask_price == 247.01
        @test q.symbol == "AAPL"

        t = get_latest_trade(client, "AAPL")
        @test t isa Trade
        @test t.price == 246.95
        @test t.id == 42

        b = get_latest_bar(client, "AAPL")
        @test b isa Bar
        @test b.symbol == "AAPL"
        @test b.c == 258.9
    end

    @test log[1].path == "/stocks/AAPL/quotes/latest"
    @test log[2].path == "/stocks/AAPL/trades/latest"
    @test log[3].path == "/stocks/AAPL/bars/latest"
    @test occursin("feed=iex", log[1].query)
end

@testset "marketdata: snapshot" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict("AAPL" => Dict(
            "latestTrade" => Dict("t" => "2026-04-11T20:00:00Z", "p" => 246.95, "s" => 100),
        )))
    end

    with_mock(handler) do client
        snap = get_snapshot(client, ["AAPL", "MSFT"])
        @test haskey(snap, :AAPL)
    end

    @test occursin("symbols=AAPL%2CMSFT", log[1].query)
    @test log[1].path == "/stocks/snapshots"
end
