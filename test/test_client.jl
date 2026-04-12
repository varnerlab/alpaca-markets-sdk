@testset "client: auth + errors" begin
    handler, log = recording_handler() do req
        return json_response(200, Dict("id" => "x", "account_number" => "A",
                                       "status" => "ACTIVE", "currency" => "USD"))
    end

    with_mock(handler) do client
        get_account(client)
    end

    @test length(log) == 1
    req = log[1]
    @test req.method == "GET"
    @test req.path == "/account"
    @test req.headers["APCA-API-KEY-ID"] == "TEST_KEY_ID"
    @test req.headers["APCA-API-SECRET-KEY"] == "TEST_SECRET_KEY"
    @test req.headers["Accept"] == "application/json"
end

@testset "client: query string encoding" begin
    handler, log = recording_handler() do req
        return json_response(200, [])
    end

    with_mock(handler) do client
        list_orders(client; status = "closed", limit = 25,
                    symbols = ["AAPL", "MSFT"], direction = "asc")
    end

    q = log[1].query
    @test occursin("status=closed", q)
    @test occursin("limit=25", q)
    @test occursin("direction=asc", q)
    @test occursin("symbols=AAPL%2CMSFT", q)  # comma escaped
end

@testset "client: JSON error body raises AlpacaError" begin
    handler = function(_req)
        return json_response(422, Dict("code" => 40010001,
                                       "message" => "qty must be positive"))
    end

    err = try
        with_mock(handler) do client
            submit_order(client, "AAPL", 10, "buy")
        end
        nothing
    catch e
        e
    end
    @test err isa AlpacaError
    @test err.status == 422
    @test err.code == 40010001
    @test occursin("qty must be positive", err.message)
end

@testset "client: non-JSON error body still surfaces" begin
    handler = function(_req)
        return plain_response(502, "upstream gateway timeout")
    end

    err = try
        with_mock(handler) do client
            get_account(client)
        end
        nothing
    catch e
        e
    end
    @test err isa AlpacaError
    @test err.status == 502
    @test err.code === nothing
    @test occursin("upstream", err.body)
end

@testset "client: load_client reads TOML" begin
    path, io = mktemp()
    try
        write(io, """
        [Credentials]
        endpoint = "https://paper-api.alpaca.markets/v2"
        key = "ABC"
        secret = "XYZ"
        """)
        close(io)
        c = load_client(path)
        @test c.trading_url == "https://paper-api.alpaca.markets/v2"
        @test c.data_url == Alpaca.DEFAULT_DATA_URL
        @test c.key_id == "ABC"
        @test c.secret_key == "XYZ"
    finally
        rm(path; force = true)
    end

    @test_throws ArgumentError load_client("/does/not/exist/apiidata.toml")
end
