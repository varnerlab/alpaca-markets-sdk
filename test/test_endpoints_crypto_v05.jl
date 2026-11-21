# Tests for the v0.5 option code models and the crypto market data models -
using DataFrames: DataFrame, nrow
using Dates: Date, DateTime

@testset "v0.5 crypto: URLs" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyCryptoBarsEndpointModel(symbols = ["BTC/USD"], timeframe = "1Hour")) ==
          "https://data.alpaca.markets/v1beta3/crypto/us/bars?symbols=BTC%2FUSD&timeframe=1Hour&limit=1000"
    @test url("http://h", MyCryptoBarsEndpointModel(symbols = ["BTC/USD", "ETH/USD"], timeframe = "1Day",
              start = Date(2026, 11, 2), finish = Date(2026, 11, 6), limit = 50, sort = "desc", loc = "us-1")) ==
          "http://h/crypto/us-1/bars?symbols=BTC%2FUSD%2CETH%2FUSD&timeframe=1Day&start=2026-11-02&end=2026-11-06&limit=50&sort=desc"
    @test url("http://h", MyCryptoQuotesEndpointModel(symbols = "BTC/USD", loc = "eu-1")) ==
          "http://h/crypto/eu-1/quotes?symbols=BTC%2FUSD&limit=1000"
    @test url("http://h", MyCryptoTradesEndpointModel(symbols = "BTC/USD", start = "2026-11-02", sort = "asc")) ==
          "http://h/crypto/us/trades?symbols=BTC%2FUSD&start=2026-11-02&limit=1000&sort=asc"
    @test url("http://h", MyCryptoLatestBarsEndpointModel(symbols = "BTC/USD")) ==
          "http://h/crypto/us/latest/bars?symbols=BTC%2FUSD"
    @test url("http://h", MyCryptoLatestQuotesEndpointModel(symbols = ["BTC/USD"], loc = "us-2")) ==
          "http://h/crypto/us-2/latest/quotes?symbols=BTC%2FUSD"
    @test url("http://h", MyCryptoLatestTradesEndpointModel(symbols = ["BTC/USD", "ETH/USD"])) ==
          "http://h/crypto/us/latest/trades?symbols=BTC%2FUSD%2CETH%2FUSD"
    @test url("http://h", MyCryptoLatestOrderbooksEndpointModel(symbols = "BTC/USD", loc = "bs-1")) ==
          "http://h/crypto/bs-1/latest/orderbooks?symbols=BTC%2FUSD"
    @test url("http://h", MyCryptoSnapshotsEndpointModel(symbols = "BTC/USD")) ==
          "http://h/crypto/us/snapshots?symbols=BTC%2FUSD"
end

@testset "v0.5 option codes: URLs and handlers" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyOptionExchangesEndpointModel()) == "https://data.alpaca.markets/v1beta1/options/meta/exchanges"
    @test url(c, MyOptionConditionsEndpointModel()) == "https://data.alpaca.markets/v1beta1/options/meta/conditions/trade"
    @test url("http://h", MyOptionConditionsEndpointModel(ticktype = "quote")) == "http://h/options/meta/conditions/quote"
    @test_throws ArgumentError MyOptionConditionsEndpointModel(ticktype = "bar")
    @test MyOptionExchangesEndpointModel() isa Alpaca.AbstractAlpacaOptionDataEndpointModel
    df = Alpaca._default_handler(MyOptionExchangesEndpointModel, """{"A":"NYSE American","B":"BOX"}""")
    @test df.code == ["A", "B"]
    @test df.name == ["NYSE American", "BOX"]
    df = Alpaca._default_handler(MyOptionConditionsEndpointModel, """{"I":"Opening","J":"Rotation"}""")
    @test df.code == ["I", "J"]
end

@testset "v0.5 crypto: argument errors and pagination" begin
    @test_throws ArgumentError MyCryptoBarsEndpointModel(symbols = "A", timeframe = "1Day", loc = "xx")
    @test_throws ArgumentError MyCryptoQuotesEndpointModel(symbols = "A", loc = "US")
    @test_throws ArgumentError MyCryptoTradesEndpointModel(symbols = "A", loc = "")
    @test_throws ArgumentError MyCryptoLatestBarsEndpointModel(symbols = "A", loc = "us1")
    @test_throws ArgumentError MyCryptoLatestQuotesEndpointModel(symbols = "A", loc = "x")
    @test_throws ArgumentError MyCryptoLatestTradesEndpointModel(symbols = "A", loc = "x")
    @test_throws ArgumentError MyCryptoLatestOrderbooksEndpointModel(symbols = "A", loc = "x")
    @test_throws ArgumentError MyCryptoSnapshotsEndpointModel(symbols = "A", loc = "x")
    for loc in ("us", "us-1", "us-2", "eu-1", "bs-1")
        @test MyCryptoSnapshotsEndpointModel(symbols = "A", loc = loc).loc == loc
    end
    @test MyCryptoBarsEndpointModel(symbols = "A", timeframe = "1Day") isa Alpaca.AbstractAlpacaCryptoDataEndpointModel
    @test_throws UndefKeywordError MyCryptoBarsEndpointModel(symbols = "A")
    @test Alpaca._is_paginated(MyCryptoBarsEndpointModel(symbols = "A", timeframe = "1Day")) == true
    @test Alpaca._is_paginated(MyCryptoQuotesEndpointModel(symbols = "A")) == true
    @test Alpaca._is_paginated(MyCryptoTradesEndpointModel(symbols = "A")) == true
    @test Alpaca._is_paginated(MyCryptoLatestBarsEndpointModel(symbols = "A")) == false
    @test Alpaca._is_paginated(MyCryptoLatestOrderbooksEndpointModel(symbols = "A")) == false
    @test Alpaca._is_paginated(MyCryptoSnapshotsEndpointModel(symbols = "A")) == false
end

@testset "v0.5 crypto: handlers" begin
    # the order book: bids first, then asks, each in response order -
    df = Alpaca._default_handler(MyCryptoLatestOrderbooksEndpointModel,
        """{"orderbooks":{"BTC/USD":{"t":"2026-11-20T15:00:00Z","b":[{"p":100.5,"s":0.25},{"p":100.4,"s":1}],"a":[{"p":100.6,"s":0.5}]}}}""")
    @test df.side == ["bid", "bid", "ask"]
    @test df.price == [100.5, 100.4, 100.6]
    @test df.size == [0.25, 1.0, 0.5]
    @test df.symbol == ["BTC/USD", "BTC/USD", "BTC/USD"]
    @test df.timestamp == fill(DateTime(2026, 11, 20, 15), 3)
    @test names(df) == ["timestamp", "symbol", "side", "price", "size"]

    # two symbols keep their own bids and asks together -
    df = Alpaca._default_handler(MyCryptoLatestOrderbooksEndpointModel,
        """{"orderbooks":{"BTC/USD":{"t":"2026-11-20T15:00:00Z","b":[{"p":1,"s":1}],"a":[{"p":2,"s":1}]},"ETH/USD":{"t":"2026-11-20T15:00:01Z","b":[{"p":3,"s":1}],"a":[]}}}""")
    @test df.symbol == ["BTC/USD", "BTC/USD", "ETH/USD"]
    @test df.side == ["bid", "ask", "bid"]

    # no order books gives no rows, with the five columns -
    for body in ("""{"orderbooks":null}""", """{"orderbooks":{}}""")
        df = Alpaca._default_handler(MyCryptoLatestOrderbooksEndpointModel, body)
        @test nrow(df) == 0
        @test names(df) == ["timestamp", "symbol", "side", "price", "size"]
    end

    # a historical trade carries the taker side, which the table ignores -
    df = Alpaca._default_handler(MyCryptoTradesEndpointModel,
        """{"trades":{"BTC/USD":[{"t":"2026-11-20T15:00:00Z","p":100.5,"s":0.01,"i":9,"tks":"B"}]},"next_page_token":null}""")
    @test df.symbol == ["BTC/USD"]
    @test df.price == [100.5]
    @test df.id == [9]

    df = Alpaca._default_handler(MyCryptoLatestQuotesEndpointModel,
        """{"quotes":{"BTC/USD":{"ap":100.6,"as":0.5,"bp":100.5,"bs":0.25,"t":"2026-11-20T15:00:00Z"}}}""")
    @test df[1, :bid_price] == 100.5
    @test df[1, :ask_size] == 0.5

    df = Alpaca._default_handler(MyCryptoLatestBarsEndpointModel,
        """{"bars":{"BTC/USD":{"t":"2026-11-20T15:00:00Z","o":1,"h":2,"l":0.5,"c":1.5,"v":10,"n":3,"vw":1.2}}}""")
    @test df.close == [1.5]
    @test nrow(Alpaca._default_handler(MyCryptoLatestBarsEndpointModel, """{"bars":null}""")) == 0

    df = Alpaca._default_handler(MyCryptoLatestTradesEndpointModel,
        """{"trades":{"BTC/USD":{"t":"2026-11-20T15:00:00Z","p":100.5,"s":0.01,"i":9,"tks":"S"}}}""")
    @test df.price == [100.5]

    # snapshots use camelCase keys -
    df = Alpaca._default_handler(MyCryptoSnapshotsEndpointModel,
        """{"snapshots":{"BTC/USD":{"dailyBar":{"t":"2026-11-20T00:00:00Z","o":1,"h":2,"l":0.5,"c":1.75,"v":10,"n":3,"vw":1.2},
        "latestQuote":{"ap":100.6,"as":0.5,"bp":100.5,"bs":0.25,"t":"2026-11-20T15:00:00Z"},
        "latestTrade":{"t":"2026-11-20T15:00:00Z","p":100.55,"s":0.01,"i":9,"tks":"B"},
        "minuteBar":{"t":"2026-11-20T15:00:00Z","o":1,"h":2,"l":0.5,"c":1.25,"v":10,"n":3,"vw":1.2},
        "prevDailyBar":{"t":"2026-11-19T00:00:00Z","o":1,"h":2,"l":0.5,"c":1.1,"v":10,"n":3,"vw":1.2}}}}""")
    @test df.symbol == ["BTC/USD"]
    @test df[1, :daily_bar_close] == 1.75
    @test df[1, :latest_quote_bid_price] == 100.5
    @test df[1, :latest_trade_price] == 100.55
    @test df[1, :prev_daily_bar_close] == 1.1
end

@testset "v0.5 crypto: api through the mock server" begin
    # a historical bars request that spans two pages -
    handler, log = recording_handler() do req
        if occursin("page_token=p2", req.target)
            return json_response(200, Dict("bars" => Dict("BTC/USD" => Any[Dict("t" => "2026-11-03T00:00:00Z",
                "o" => 2, "h" => 3, "l" => 1, "c" => 2.5, "v" => 20, "n" => 4, "vw" => 2.1)]),
                "next_page_token" => nothing))
        end
        return json_response(200, Dict("bars" => Dict("BTC/USD" => Any[Dict("t" => "2026-11-02T00:00:00Z",
            "o" => 1, "h" => 2, "l" => 0.5, "c" => 1.5, "v" => 10, "n" => 3, "vw" => 1.2)]),
            "next_page_token" => "p2"))
    end
    with_mock(handler) do client
        df = api(client, MyCryptoBarsEndpointModel(symbols = "BTC/USD", timeframe = "1Day"))
        @test nrow(df) == 2
        @test df.close == [1.5, 2.5]
        @test df.symbol == ["BTC/USD", "BTC/USD"]
    end
    @test length(log) == 2
    @test startswith(log[1].path, "/crypto/us/bars")

    # the latest order book request -
    handler2, log2 = recording_handler(req -> json_response(200, Dict("orderbooks" => Dict("BTC/USD" =>
        Dict("t" => "2026-11-20T15:00:00Z", "b" => Any[Dict("p" => 1, "s" => 2)], "a" => Any[Dict("p" => 3, "s" => 4)])))))
    with_mock(handler2) do client
        df = api(client, MyCryptoLatestOrderbooksEndpointModel(symbols = "BTC/USD"))
        @test df.side == ["bid", "ask"]
    end
    @test length(log2) == 1
    @test startswith(log2[1].path, "/crypto/us/latest/orderbooks")
end
