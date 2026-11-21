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

    # max_pages below 1 throws before any request -
    handler, log = recording_handler(_two_page_handler)
    with_mock(handler) do client
        @test_throws ArgumentError api(client, model; max_pages = 0)
    end
    @test length(log) == 0
end
