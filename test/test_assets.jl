const _AAPL_ASSET = Dict(
    "id"             => "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415",
    "class"          => "us_equity",
    "exchange"       => "NASDAQ",
    "symbol"         => "AAPL",
    "name"           => "Apple Inc. Common Stock",
    "status"         => "active",
    "tradable"       => true,
    "marginable"     => true,
    "shortable"      => true,
    "easy_to_borrow" => true,
    "fractionable"   => true,
)

const _DEAD_ASSET = Dict(
    "id"             => "11111111-1111-1111-1111-111111111111",
    "class"          => "us_equity",
    "exchange"       => "NYSE",
    "symbol"         => "XYZQ",
    "name"           => "Delisted Co",
    "status"         => "inactive",
    "tradable"       => false,
    "marginable"     => false,
    "shortable"      => false,
    "easy_to_borrow" => false,
    "fractionable"   => false,
)

@testset "assets: list + query filters" begin
    handler, log = recording_handler() do _req
        return json_response(200, [_AAPL_ASSET, _DEAD_ASSET])
    end

    with_mock(handler) do client
        assets = list_assets(client)  # tradable_only=true by default
        @test length(assets) == 1
        @test assets[1] isa Asset
        @test assets[1].symbol == "AAPL"
        @test assets[1].tradable

        all_assets = list_assets(client; tradable_only = false)
        @test length(all_assets) == 2
    end

    @test occursin("status=active", log[1].query)
    @test occursin("asset_class=us_equity", log[1].query)
end

@testset "assets: get by symbol" begin
    handler, log = recording_handler() do _req
        return json_response(200, _AAPL_ASSET)
    end

    with_mock(handler) do client
        a = get_asset(client, "AAPL")
        @test a.symbol == "AAPL"
        @test a.class == "us_equity"
        @test a.exchange == "NASDAQ"
    end

    @test log[1].path == "/assets/AAPL"
end
