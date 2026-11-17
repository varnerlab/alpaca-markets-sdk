using DataFrames

@testset "api: auth headers and custom handler" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict("id" => "x"))
    end
    seen = Any[]
    with_mock(handler) do client
        r = api(client, MyAccountEndpointModel(); handler = (T, body) -> (push!(seen, T); body))
        @test r isa String
    end
    @test seen == [MyAccountEndpointModel]
    @test log[1].headers["APCA-API-KEY-ID"] == "TEST_KEY_ID"
    @test log[1].headers["APCA-API-SECRET-KEY"] == "TEST_SECRET_KEY"
end

@testset "api: follows pages and stops on empty tokens" begin
    for last_token in (nothing, "")
        handler, log = recording_handler() do req
            if occursin("page_token=p2", req.target)
                return json_response(200, Dict("bars" => Dict(), "next_page_token" => last_token))
            end
            return json_response(200, Dict("bars" => Dict(), "next_page_token" => "p2"))
        end
        with_mock(handler) do client
            pages = api(client, MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Day", start = "2025-01-01");
                        handler = (T, body) -> [body])
            @test length(pages) == 2
        end
        @test length(log) == 2
    end
end

@testset "api: no page loop for a single-record endpoint" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict("next_page_token" => "p2"))
    end
    with_mock(handler) do client
        api(client, MyClockEndpointModel(); handler = (T, body) -> body)
    end
    @test length(log) == 1
end

@testset "api: error status raises AlpacaError" begin
    handler = _req -> json_response(403, Dict("code" => 40310000, "message" => "forbidden"))
    err = try
        with_mock(handler) do client
            api(client, MyAccountEndpointModel(); handler = (T, body) -> body)
        end
        nothing
    catch e
        e
    end
    @test err isa AlpacaError
    @test err.status == 403
    @test err.code == 40310000
end

@testset "api: _next_page_token" begin
    @test Alpaca._next_page_token("{\"a\":1}") === nothing
    @test Alpaca._next_page_token("{\"next_page_token\":null}") === nothing
    @test Alpaca._next_page_token("{\"next_page_token\":\"\"}") === nothing
    @test Alpaca._next_page_token("{\"next_page_token\":\"abc\"}") == "abc"
end

@testset "api: _merge" begin
    a = DataFrame(x = [1], y = [2])
    b = DataFrame(x = [3], z = [4])
    m = Alpaca._merge(a, b)
    @test nrow(m) == 2
    @test Set(names(m)) == Set(["x", "y", "z"])

    d = Alpaca._merge(Dict("A" => [1, 2], "B" => [3]), Dict("A" => [4], "C" => [5]))
    @test d == Dict("A" => [1, 2, 4], "B" => [3], "C" => [5])

    s = Alpaca._merge(Dict("A" => 1, "B" => 2), Dict("A" => 9))
    @test s == Dict("A" => 9, "B" => 2)

    @test Alpaca._merge([1, 2], [3]) == [1, 2, 3]
end
