@testset "v0.5 foundation: versioned base URLs" begin
    @test Alpaca._versioned_url("https://data.alpaca.markets/v2", "v1beta3") == "https://data.alpaca.markets/v1beta3"
    @test Alpaca._versioned_url("https://paper-api.alpaca.markets/v2", "v3") == "https://paper-api.alpaca.markets/v3"
    @test Alpaca._versioned_url("http://127.0.0.1:8080", "v1") == "http://127.0.0.1:8080"
    @test Alpaca._derive_options_url("https://data.alpaca.markets/v2") == "https://data.alpaca.markets/v1beta1"
end

@testset "v0.5 foundation: symbols in paths are escaped" begin
    @test url("http://h", MyAssetEndpointModel(symbol = "BTC/USD")) == "http://h/assets/BTC%2FUSD"
    @test url("http://h", MyPositionEndpointModel(symbol = "BTC/USD")) == "http://h/positions/BTCUSD"
    @test url("http://h", MyPositionEndpointModel(symbol = "AAPL")) == "http://h/positions/AAPL"
    @test Alpaca._position_symbol("BTC/USD") == "BTCUSD"
    @test Alpaca._position_symbol("AAPL251219C00200000") == "AAPL251219C00200000"
    @test Alpaca._position_symbol("276e2673-764b-4ab6-a611-caf665ca6340") == "276e2673-764b-4ab6-a611-caf665ca6340"
    @test url("http://h", MyAssetEndpointModel(symbol = "AAPL")) == "http://h/assets/AAPL"
    @test url("http://h", MyOptionContractEndpointModel(symbol = "AAPL251219C00200000")) == "http://h/options/contracts/AAPL251219C00200000"
    @test url("http://h", MyOptionContractEndpointModel(symbol = "A/B")) == "http://h/options/contracts/A%2FB"
    @test startswith(url("http://h", MyOptionChainEndpointModel(underlying = "A/B")), "http://h/options/snapshots/A%2FB")
    @test startswith(url("http://h", MyOptionChainEndpointModel(underlying = "AAPL")), "http://h/options/snapshots/AAPL")
end

@testset "v0.5 foundation: generic records table" begin
    records = Any[JSON3.read("""{"id":"a","qty":"5","transaction_time":"2026-11-20T15:00:00Z","market":{"acronym":"NYSE"}}"""),
                  JSON3.read("""{"id":"b","price":1.5,"symbols":["X","Y"],"flag":true,"note":null}""")]
    df = Alpaca._records_table(records)
    @test names(df) == ["id", "qty", "transaction_time", "market_acronym", "price", "symbols", "flag", "note"]
    @test df[1, :transaction_time] == DateTime(2026, 11, 20, 15)
    @test df[1, :qty] == "5"
    @test ismissing(df[1, :price]) && df[2, :price] == 1.5
    @test df[2, :symbols] == "[\"X\",\"Y\"]"
    @test df[2, :flag] == true && ismissing(df[2, :note])
    @test size(Alpaca._records_table(Any[])) == (0, 0)
    @test size(Alpaca._empty_table("")) == (0, 0)
end

mutable struct _TestPatchModel <: Alpaca.AbstractAlpacaTradingEndpointModel end
Alpaca.url(base::String, m::_TestPatchModel) = base * "/thing"
Alpaca._http_method(m::_TestPatchModel) = "PATCH"
Alpaca._request_body(m::_TestPatchModel) = Dict("a" => 1)
Alpaca._is_paginated(m::_TestPatchModel) = true
Alpaca._default_handler(::Type{_TestPatchModel}, body::String) = Alpaca._records_table(Any[JSON3.read(body)])

@testset "v0.5 foundation: api sends the model's method and body once" begin
    handler, log = recording_handler(req -> json_response(200, Dict("a" => 1, "next_page_token" => "more")))
    with_mock(handler) do client
        df = api(client, _TestPatchModel())
        @test length(log) == 1
        @test log[1].method == "PATCH" && log[1].path == "/thing"
        @test JSON3.read(log[1].body)[:a] == 1
        @test df[1, :a] == 1.0
    end
end
