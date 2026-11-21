# Tests for the v0.5 stock data models for non-US exchanges (Alpaca "Stock v3") -
using DataFrames: DataFrame, nrow
using Dates: Date, DateTime

@testset "v0.5 global stocks: URLs" begin
    @test url("http://h", MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = ["SAP:XETR", "BMW:XETR"],
              timeframe = "1Day", start = Date(2026, 11, 2))) ==
          "http://h/stocks/xetr/bars?symbols=SAP%3AXETR%2CBMW%3AXETR&timeframe=1Day&start=2026-11-02&page_size=1000"
    @test url("http://h", MyGlobalStockBarsEndpointModel(feed = "xlon", symbols = "VOD:XLON", timeframe = "1Hour",
              start = Date(2026, 11, 2), finish = Date(2026, 11, 6), page_size = 50, sort = "desc")) ==
          "http://h/stocks/xlon/bars?symbols=VOD%3AXLON&timeframe=1Hour&start=2026-11-02&end=2026-11-06&page_size=50&sort=desc"
    @test url("http://h", MyGlobalStockQuotesEndpointModel(feed = "xhkg", symbols = "0700:XHKG", start = Date(2026, 11, 2))) ==
          "http://h/stocks/xhkg/quotes?symbols=0700%3AXHKG&start=2026-11-02&page_size=1000"
    @test url("http://h", MyGlobalStockTradesEndpointModel(feed = "euroctp", symbols = "ASML:XAMS", start = Date(2026, 11, 2),
              finish = Date(2026, 11, 3), sort = "asc")) ==
          "http://h/stocks/euroctp/trades?symbols=ASML%3AXAMS&start=2026-11-02&end=2026-11-03&page_size=1000&sort=asc"
    @test url("http://h", MyGlobalStockLatestBarsEndpointModel(feed = "xsau", symbols = "2222:XSAU")) ==
          "http://h/stocks/xsau/latest/bars?symbols=2222%3AXSAU"
    @test url("http://h", MyGlobalStockLatestQuotesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"])) ==
          "http://h/stocks/xetr/latest/quotes?symbols=SAP%3AXETR"
    @test url("http://h", MyGlobalStockLatestTradesEndpointModel(feed = "xetr", symbols = ["SAP:XETR", "BMW:XETR"])) ==
          "http://h/stocks/xetr/latest/trades?symbols=SAP%3AXETR%2CBMW%3AXETR"
    @test url("http://h", MyGlobalStockSnapshotsEndpointModel(feed = "xetr", symbols = "SAP:XETR")) ==
          "http://h/stocks/xetr/snapshots?symbols=SAP%3AXETR"
end

@testset "v0.5 global stocks: base URL of a real client" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    model = MyGlobalStockLatestQuotesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"])
    @test url(c, model) ==
          "https://data.alpaca.markets/v3/stocks/xetr/latest/quotes?symbols=SAP%3AXETR"
end

@testset "v0.5 global stocks: argument errors and pagination" begin
    @test_throws ArgumentError MyGlobalStockBarsEndpointModel(feed = "xnys", symbols = "A", timeframe = "1Day", start = "2026-11-02")
    @test_throws ArgumentError MyGlobalStockQuotesEndpointModel(feed = "", symbols = "A", start = "2026-11-02")
    @test_throws ArgumentError MyGlobalStockTradesEndpointModel(feed = "XETR", symbols = "A", start = "2026-11-02")
    @test_throws ArgumentError MyGlobalStockLatestBarsEndpointModel(feed = "iex", symbols = "A")
    @test_throws ArgumentError MyGlobalStockLatestQuotesEndpointModel(feed = "iex", symbols = "A")
    @test_throws ArgumentError MyGlobalStockLatestTradesEndpointModel(feed = "iex", symbols = "A")
    @test_throws ArgumentError MyGlobalStockSnapshotsEndpointModel(feed = "iex", symbols = "A")
    for feed in ("euroctp", "xetr", "xhkg", "xlon", "xsau")
        @test MyGlobalStockSnapshotsEndpointModel(feed = feed, symbols = "A").feed == feed
    end
    @test MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = "A", timeframe = "1Day", start = "2026-11-02") isa
          Alpaca.AbstractAlpacaGlobalStockDataEndpointModel
    @test_throws UndefKeywordError MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = "A", timeframe = "1Day")
    @test Alpaca._is_paginated(MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = "A", timeframe = "1Day", start = "2026-11-02")) == true
    @test Alpaca._is_paginated(MyGlobalStockQuotesEndpointModel(feed = "xetr", symbols = "A", start = "2026-11-02")) == true
    @test Alpaca._is_paginated(MyGlobalStockTradesEndpointModel(feed = "xetr", symbols = "A", start = "2026-11-02")) == true
    @test Alpaca._is_paginated(MyGlobalStockLatestBarsEndpointModel(feed = "xetr", symbols = "A")) == false
    @test Alpaca._is_paginated(MyGlobalStockSnapshotsEndpointModel(feed = "xetr", symbols = "A")) == false
end

@testset "v0.5 global stocks: handlers" begin
    # latest quotes send their numbers as text -
    df = Alpaca._default_handler(MyGlobalStockLatestQuotesEndpointModel,
        """{"quotes":{"SAP:XETR":{"ap":"201.6","as":"5","bp":"201.5","bs":"10","t":"2026-11-20T15:00:00Z"}}}""")
    @test df.symbol == ["SAP:XETR"]
    @test df[1, :bid_price] == 201.5
    @test df[1, :bid_size] == 10
    @test df[1, :ask_price] == 201.6
    @test df[1, :ask_size] == 5

    df = Alpaca._default_handler(MyGlobalStockLatestTradesEndpointModel,
        """{"trades":{"SAP:XETR":{"i":7,"m":"X","p":201.55,"s":3,"t":"2026-11-20T15:00:00Z"}}}""")
    @test df.symbol == ["SAP:XETR"]
    @test df.price == [201.55]
    @test df.id == [7]
    @test ismissing(df[1, :exchange])

    df = Alpaca._default_handler(MyGlobalStockLatestBarsEndpointModel,
        """{"bars":{"SAP:XETR":{"t":"2026-11-20T15:00:00Z","o":1,"h":2,"l":0.5,"c":1.5,"v":10,"n":3,"vw":1.2}}}""")
    @test df.close == [1.5]
    @test nrow(Alpaca._default_handler(MyGlobalStockLatestBarsEndpointModel, """{"bars":null}""")) == 0

    # snapshots use snake_case keys -
    df = Alpaca._default_handler(MyGlobalStockSnapshotsEndpointModel,
        """{"snapshots":{"SAP:XETR":{"daily_bar":{"t":"2026-11-20T00:00:00Z","o":1,"h":2,"l":0.5,"c":1.75,"v":10,"n":3,"vw":1.2},
        "latest_quote":{"ap":"201.6","as":"5","bp":"201.5","bs":"10","t":"2026-11-20T15:00:00Z"},
        "latest_trade":{"i":7,"p":201.55,"s":3,"t":"2026-11-20T15:00:00Z"},
        "minute_bar":{"t":"2026-11-20T15:00:00Z","o":1,"h":2,"l":0.5,"c":1.25,"v":10,"n":3,"vw":1.2},
        "prev_daily_bar":{"t":"2026-11-19T00:00:00Z","o":1,"h":2,"l":0.5,"c":1.1,"v":10,"n":3,"vw":1.2}}}}""")
    @test df.symbol == ["SAP:XETR"]
    @test df[1, :daily_bar_close] == 1.75
    @test df[1, :minute_bar_close] == 1.25
    @test df[1, :prev_daily_bar_close] == 1.1
    @test df[1, :latest_quote_bid_price] == 201.5
    @test df[1, :latest_trade_price] == 201.55
    @test names(df) == names(Alpaca._snapshots_table(Union{Missing,String}["A"], Any[Dict{Symbol,Any}()], false))

    # the camelCase default of _snapshots_table is unchanged -
    df = Alpaca._default_handler(MyStockSnapshotsEndpointModel,
        """{"AAPL":{"dailyBar":{"t":"2026-11-20T00:00:00Z","o":1,"h":2,"l":0.5,"c":1.75,"v":10,"n":3,"vw":1.2}}}""")
    @test df[1, :daily_bar_close] == 1.75
end

@testset "v0.5 global stocks: api through the mock server" begin
    # a historical request that spans two pages -
    handler, log = recording_handler() do req
        if occursin("page_token=p2", req.target)
            return json_response(200, Dict("bars" => Dict("SAP:XETR" => Any[Dict("t" => "2026-11-03T00:00:00Z",
                "o" => 2, "h" => 3, "l" => 1, "c" => 2.5, "v" => 20, "n" => 4, "vw" => 2.1)]),
                "next_page_token" => nothing))
        end
        return json_response(200, Dict("bars" => Dict("SAP:XETR" => Any[Dict("t" => "2026-11-02T00:00:00Z",
            "o" => 1, "h" => 2, "l" => 0.5, "c" => 1.5, "v" => 10, "n" => 3, "vw" => 1.2)]),
            "next_page_token" => "p2"))
    end
    with_mock(handler) do client
        df = api(client, MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = "SAP:XETR", timeframe = "1Day",
            start = Date(2026, 11, 2)))
        @test nrow(df) == 2
        @test df.close == [1.5, 2.5]
        @test df.symbol == ["SAP:XETR", "SAP:XETR"]
    end
    @test length(log) == 2
    @test startswith(log[1].path, "/stocks/xetr/bars")

    # the latest quotes request, with numbers as text -
    handler2, log2 = recording_handler(req -> json_response(200, Dict("quotes" => Dict("SAP:XETR" =>
        Dict("ap" => "201.6", "as" => "5", "bp" => "201.5", "bs" => "10", "t" => "2026-11-20T15:00:00Z")))))
    with_mock(handler2) do client
        df = api(client, MyGlobalStockLatestQuotesEndpointModel(feed = "xetr", symbols = "SAP:XETR"))
        @test df[1, :bid_price] == 201.5
    end
    @test length(log2) == 1
end
