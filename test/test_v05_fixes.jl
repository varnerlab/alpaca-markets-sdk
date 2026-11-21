# Tests of the calendar date format and of the max_pages keyword of api.

@testset "calendar: start and end are dates" begin
    m = MyMarketCalendarEndpointModel(market = "NYSE", start = DateTime(2026, 11, 2, 15, 30), finish = Date(2026, 11, 6))
    @test url("http://h", m) == "http://h/calendar/NYSE?start=2026-11-02&end=2026-11-06"
    m2 = MyMarketCalendarEndpointModel(market = "NYSE", start = "2026-11-02", finish = DateTime(2026, 11, 6, 23, 59))
    @test url("http://h", m2) == "http://h/calendar/NYSE?start=2026-11-02&end=2026-11-06"
end

# a two-page bars endpoint: each page holds one bar -
function _two_page_handler(req)
    if occursin("page_token=p2", req.target)
        return json_response(200, Dict("bars" => Dict("AAPL" => [Dict("t" => "2026-11-03T05:00:00Z", "o" => 2, "h" => 2, "l" => 2, "c" => 2, "v" => 2, "n" => 2, "vw" => 2)]), "next_page_token" => nothing))
    end
    return json_response(200, Dict("bars" => Dict("AAPL" => [Dict("t" => "2026-11-02T05:00:00Z", "o" => 1, "h" => 1, "l" => 1, "c" => 1, "v" => 1, "n" => 1, "vw" => 1)]), "next_page_token" => "p2"))
end

@testset "api: max_pages" begin
    model = MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Day", start = "2026-11-01")

    # max_pages = 1 sends one request and returns the first page -
    handler, log = recording_handler(_two_page_handler)
    with_mock(handler) do client
        result = api(client, model; max_pages = 1)
        @test size(result, 1) == 1
        @test result.close[1] == 1.0
    end
    @test length(log) == 1

    # max_pages = 2 and nothing follow both pages -
    for cap in (2, nothing)
        handler, log = recording_handler(_two_page_handler)
        with_mock(handler) do client
            result = api(client, model; max_pages = cap)
            @test size(result, 1) == 2
        end
        @test length(log) == 2
    end

    # a capped request whose first page has a token carries that token in its metadata -
    handler, log = recording_handler(_two_page_handler)
    with_mock(handler) do client
        result = api(client, model; max_pages = 1)
        @test DataFrames.metadata(result, "next_page_token", nothing) == "p2"
    end

    # a request that reaches the last page carries no token, with a cap of 2 or with no cap -
    for cap in (2, nothing)
        handler, log = recording_handler(_two_page_handler)
        with_mock(handler) do client
            result = api(client, model; max_pages = cap)
            @test DataFrames.metadata(result, "next_page_token", nothing) === nothing
            @test ("next_page_token" in DataFrames.metadatakeys(result)) == false
        end
    end

    # max_pages below 1 throws before any request -
    handler, log = recording_handler(_two_page_handler)
    with_mock(handler) do client
        @test_throws ArgumentError api(client, model; max_pages = 0)
    end
    @test length(log) == 0
end
# --- final-review fixes ---------------------------------------------------------------------------------------- #

@testset "portfolio history: null values are missing" begin
    body = """{"timestamp":[1763650800,1763737200],"equity":[100000,null],"profit_loss":[null,12.5],"profit_loss_pct":[0.0001,null],"base_value":null}"""
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel, body)
    @test size(df) == (2, 5)
    @test df[1, :equity] == 100000.0 && ismissing(df[2, :equity])
    @test ismissing(df[1, :profit_loss]) && df[2, :profit_loss] == 12.5
    @test df[1, :profit_loss_pct] == 0.0001 && ismissing(df[2, :profit_loss_pct])
    @test all(ismissing, df.base_value)
    @test df[2, :timestamp] == DateTime(2025, 11, 21, 15)

    # an absent base_value is missing too, and a present one is kept -
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel,
        """{"timestamp":[1763650800],"equity":[1],"profit_loss":[2],"profit_loss_pct":[3]}""")
    @test ismissing(df[1, :base_value])
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel,
        """{"timestamp":[1763650800],"equity":[1],"profit_loss":[2],"profit_loss_pct":[3],"base_value":100000}""")
    @test df[1, :base_value] == 100000.0
end

@testset "corporate actions: start and end are dates" begin
    m = MyCorporateActionsEndpointModel(symbols = "AAPL", start = DateTime(2026, 1, 1, 9, 30), finish = Date(2026, 2, 1))
    @test url("http://h", m) == "http://h/corporate-actions?symbols=AAPL&start=2026-01-01&end=2026-02-01&limit=100"
end

@testset "clock: time columns are UTC DateTimes" begin
    body = """{"clocks":[{"market":{"acronym":"NYSE","timezone":"America/New_York"},"timestamp":"2026-11-20T15:00:00Z","is_market_day":true,"next_market_open":"2026-11-23T14:30:00Z","next_market_close":"2026-11-20T21:00:00Z","phase":"core","phase_until":"2026-11-20T21:00:00Z"}]}"""
    df = Alpaca._default_handler(MyMarketClocksEndpointModel, body)
    @test df[1, :next_market_open] == DateTime(2026, 11, 23, 14, 30)
    @test df[1, :next_market_close] == DateTime(2026, 11, 20, 21)
    @test df[1, :phase_until] == DateTime(2026, 11, 20, 21)
    @test df[1, :timestamp] == DateTime(2026, 11, 20, 15)
end

@testset "order numbers: no exponent" begin
    @test Alpaca._decimal_text(150.25) == "150.25"
    @test Alpaca._decimal_text(10) == "10"
    @test Alpaca._decimal_text(1.0) == "1.0"
    @test Alpaca._decimal_text("0.5") == "0.5"
    @test Alpaca._decimal_text(0.00001) == "0.00001"
    @test Alpaca._decimal_text(2.5e-8) == "0.000000025"
    @test Alpaca._decimal_text(1.0e20) == "100000000000000000000"
    @test Alpaca._decimal_text(-1.5e-7) == "-0.00000015"
    body = Alpaca._single_order_body("BTC/USD", 0.00001, "buy"; type = "limit", limit_price = 2.5e-8)
    @test body["qty"] == "0.00001" && body["limit_price"] == "0.000000025"
    body = Alpaca._single_order_body("AAPL", 10, "buy"; type = "limit", limit_price = 150.25)
    @test body["qty"] == "10" && body["limit_price"] == "150.25"
    body = Dict{String,Any}()
    Alpaca._add_order_class!(body, "bracket", 2.5e-8, 1.0e-5, 1.0e-5)
    @test body["take_profit"]["limit_price"] == "0.000000025"
    @test body["stop_loss"]["stop_price"] == "0.00001" && body["stop_loss"]["limit_price"] == "0.00001"
    @test MyReplaceOrderEndpointModel(id = "x", qty = 0.00001).qty == "0.00001"
end
