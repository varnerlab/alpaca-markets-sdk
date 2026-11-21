# Tests for the v0.5 stock data models: latest for many symbols, auctions, and condition and exchange codes -
using DataFrames: DataFrame
using Dates: Date, DateTime

@testset "v0.5 stocks: URLs" begin
    @test url("http://h", MyStockLatestBarsEndpointModel(symbols = ["AAPL", "MSFT"])) ==
          "http://h/stocks/bars/latest?symbols=AAPL%2CMSFT&feed=iex"
    @test url("http://h", MyStockLatestQuotesEndpointModel(symbols = "AAPL", feed = "sip", currency = "USD")) ==
          "http://h/stocks/quotes/latest?symbols=AAPL&feed=sip&currency=USD"
    @test url("http://h", MyStockLatestTradesEndpointModel(symbols = ["AAPL", "MSFT"])) ==
          "http://h/stocks/trades/latest?symbols=AAPL%2CMSFT&feed=iex"
    @test url("http://h", MyStockAuctionsEndpointModel(symbols = "AAPL")) ==
          "http://h/stocks/auctions?symbols=AAPL&limit=1000&feed=sip"
    @test url("http://h", MyStockAuctionsEndpointModel(symbols = ["AAPL", "MSFT"], start = Date(2026, 11, 2),
              finish = Date(2026, 11, 6), limit = 50, sort = "desc")) ==
          "http://h/stocks/auctions?symbols=AAPL%2CMSFT&start=2026-11-02&end=2026-11-06&limit=50&feed=sip&sort=desc"
    @test url("http://h", MyStockConditionsEndpointModel()) == "http://h/stocks/meta/conditions/trade?tape=A"
    @test url("http://h", MyStockConditionsEndpointModel(ticktype = "quote", tape = "C")) ==
          "http://h/stocks/meta/conditions/quote?tape=C"
    @test url("http://h", MyStockExchangesEndpointModel()) == "http://h/stocks/meta/exchanges"
end

@testset "v0.5 stocks: argument errors and pagination" begin
    @test_throws ArgumentError MyStockConditionsEndpointModel(ticktype = "bar")
    @test_throws ArgumentError MyStockConditionsEndpointModel(tape = "D")
    @test Alpaca._is_paginated(MyStockAuctionsEndpointModel(symbols = "AAPL")) == true
    @test Alpaca._is_paginated(MyStockLatestQuotesEndpointModel(symbols = "AAPL")) == false
    @test Alpaca._is_paginated(MyStockConditionsEndpointModel()) == false
    @test Alpaca._is_paginated(MyStockExchangesEndpointModel()) == false
end

@testset "v0.5 stocks: latest handlers" begin
    df = Alpaca._default_handler(MyStockLatestQuotesEndpointModel,
        """{"quotes":{"AAPL":{"t":"2026-11-20T15:00:00Z","bp":1.5,"bs":2,"ap":1.6,"as":3},"MSFT":{"t":"2026-11-20T15:00:01Z","bp":4.5,"bs":5,"ap":4.6,"as":6}}}""")
    @test df.symbol == ["AAPL", "MSFT"]
    @test df.bid_price == [1.5, 4.5]
    df = Alpaca._default_handler(MyStockLatestBarsEndpointModel,
        """{"bars":{"AAPL":{"t":"2026-11-20T15:00:00Z","o":1,"h":2,"l":0.5,"c":1.5,"v":10,"n":3,"vw":1.2}}}""")
    @test df.symbol == ["AAPL"]
    @test df.close == [1.5]
    df = Alpaca._default_handler(MyStockLatestTradesEndpointModel,
        """{"trades":{"AAPL":{"t":"2026-11-20T15:00:00Z","p":1.5,"s":10}}}""")
    @test df.symbol == ["AAPL"]
    @test nrow(Alpaca._default_handler(MyStockLatestTradesEndpointModel, """{"trades":null}""")) == 0
end

@testset "v0.5 stocks: auctions handler" begin
    body = """{"auctions":{"AAPL":[{"d":"2026-11-20","o":[{"t":"2026-11-20T14:30:00.123Z","p":100.5,"s":200,"x":"Q","c":"O"}],
        "c":[{"t":"2026-11-20T21:00:00Z","p":101.25,"s":300,"x":"Q","c":"M"},{"t":"2026-11-20T21:00:01Z","p":101.5,"s":400,"x":"P","c":"6"}]}]}}"""
    df = Alpaca._default_handler(MyStockAuctionsEndpointModel, body)
    @test nrow(df) == 3
    @test df.auction == ["open", "close", "close"]
    @test df.symbol == ["AAPL", "AAPL", "AAPL"]
    @test df.date == fill(Date(2026, 11, 20), 3)
    @test df.price == [100.5, 101.25, 101.5]
    @test df.size == [200, 300, 400]
    @test df.exchange == ["Q", "Q", "P"]
    @test df.condition == ["O", "M", "6"]
    @test df.timestamp[2] == DateTime(2026, 11, 20, 21)
    @test names(df) == ["timestamp", "symbol", "date", "auction", "price", "size", "exchange", "condition"]
    for body_empty in ("""{"auctions":null}""", """{"auctions":{}}""")
        empty_df = Alpaca._default_handler(MyStockAuctionsEndpointModel, body_empty)
        @test nrow(empty_df) == 0
        @test names(empty_df) == names(df)
    end
end

@testset "v0.5 stocks: codes table" begin
    df = Alpaca._codes_table("""{"A":"NYSE American","N":"NYSE"}""")
    @test df.code == ["A", "N"]
    @test df.name == ["NYSE American", "NYSE"]
    @test Alpaca._default_handler(MyStockExchangesEndpointModel, """{"A":"NYSE American"}""").code == ["A"]
    @test Alpaca._default_handler(MyStockConditionsEndpointModel, """{"@":"Regular Sale"}""").name == ["Regular Sale"]
    @test nrow(Alpaca._codes_table("{}")) == 0
end

@testset "v0.5 stocks: api through the mock server" begin
    handler, log = recording_handler() do req
        if occursin("page_token=p2", req.target)
            return json_response(200, Dict("auctions" => Dict("AAPL" => Any[Dict("d" => "2026-11-21",
                "o" => Any[], "c" => Any[Dict("t" => "2026-11-21T21:00:00Z", "p" => 2.5, "s" => 7, "x" => "Q", "c" => "M")])]),
                "next_page_token" => nothing))
        end
        return json_response(200, Dict("auctions" => Dict("AAPL" => Any[Dict("d" => "2026-11-20",
            "o" => Any[Dict("t" => "2026-11-20T14:30:00Z", "p" => 1.5, "s" => 5, "x" => "Q", "c" => "O")], "c" => Any[])]),
            "next_page_token" => "p2"))
    end
    with_mock(handler) do client
        df = api(client, MyStockAuctionsEndpointModel(symbols = "AAPL"))
        @test df.auction == ["open", "close"]
        @test df.date == [Date(2026, 11, 20), Date(2026, 11, 21)]
        @test df.price == [1.5, 2.5]
    end
    @test length(log) == 2
    @test startswith(log[1].path, "/stocks/auctions")

    handler2, log2 = recording_handler(req -> json_response(200, Dict("N" => "NYSE")))
    with_mock(handler2) do client
        df = api(client, MyStockExchangesEndpointModel())
        @test df.code == ["N"]
    end
end
