# Tests for the v0.5 news, screener, corporate actions, logo, and fixed income models -
using DataFrames: DataFrame, nrow
using Dates: Date, DateTime

@testset "v0.5 market: URLs" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyNewsEndpointModel(symbols = ["AAPL"])) ==
          "https://data.alpaca.markets/v1beta1/news?symbols=AAPL&sort=desc&limit=50&include_content=false&exclude_contentless=false"
    @test url("http://h", MyNewsEndpointModel(symbols = ["AAPL", "MSFT"], start = Date(2026, 11, 2), finish = "2026-11-06",
              sort = "asc", limit = 10, include_content = true, exclude_contentless = true, page_token = "tok")) ==
          "http://h/news?symbols=AAPL%2CMSFT&start=2026-11-02&end=2026-11-06&sort=asc&limit=10&include_content=true&exclude_contentless=true&page_token=tok"
    @test url(c, MyMostActivesEndpointModel()) ==
          "https://data.alpaca.markets/v1beta1/screener/stocks/most-actives?by=volume&top=10"
    @test url("http://h", MyMostActivesEndpointModel(by = "trades", top = 5)) ==
          "http://h/screener/stocks/most-actives?by=trades&top=5"
    @test url(c, MyMoversEndpointModel()) ==
          "https://data.alpaca.markets/v1beta1/screener/stocks/movers?top=10"
    @test url("http://h", MyMoversEndpointModel(market_type = "crypto", top = 3)) == "http://h/screener/crypto/movers?top=3"
    @test url(c, MyCorporateActionsEndpointModel(symbols = ["AAPL"])) ==
          "https://data.alpaca.markets/v1/corporate-actions?symbols=AAPL&limit=100"
    @test url("http://h", MyCorporateActionsEndpointModel(symbols = "AAPL", cusips = ["037833100"], types = ["cash_dividend", "forward_split"],
              start = Date(2026, 1, 1), finish = Date(2026, 6, 30), ids = ["a", "b"], limit = 20, sort = "asc", region = "all", data_quality = "all")) ==
          "http://h/corporate-actions?symbols=AAPL&cusips=037833100&types=cash_dividend%2Cforward_split&start=2026-01-01&end=2026-06-30&ids=a%2Cb&limit=20&sort=asc&region=all&data_quality=all"
    @test url(c, MyLogoEndpointModel(symbol = "AAPL")) == "https://data.alpaca.markets/v1beta1/logos/AAPL?placeholder=true"
    @test url("http://h", MyLogoEndpointModel(symbol = "AAPL", placeholder = false)) == "http://h/logos/AAPL?placeholder=false"
    @test url("http://h", MyLogoEndpointModel(symbol = "BTC/USD")) == "http://h/logos/BTC%2FUSD?placeholder=true"
    @test url(c, MyFixedIncomeLatestPricesEndpointModel(isins = ["US912828ZT58"])) ==
          "https://data.alpaca.markets/v1beta1/fixed_income/latest/prices?isins=US912828ZT58"
    @test url("http://h", MyFixedIncomeLatestQuotesEndpointModel(isins = ["A", "B"], trade_size = 1000)) ==
          "http://h/fixed_income/latest/quotes?isins=A%2CB&trade_size=1000"
    @test url("http://h", MyFixedIncomeLatestQuotesEndpointModel(isins = "A")) == "http://h/fixed_income/latest/quotes?isins=A"
end

@testset "v0.5 market: argument errors, types, and pagination" begin
    @test_throws ArgumentError MyMostActivesEndpointModel(by = "price")
    @test_throws ArgumentError MyMoversEndpointModel(market_type = "options")
    @test_throws ArgumentError MyFixedIncomeLatestPricesEndpointModel(isins = String[])
    @test_throws ArgumentError MyFixedIncomeLatestQuotesEndpointModel(isins = String[])
    @test_throws UndefKeywordError MyFixedIncomeLatestPricesEndpointModel()
    @test_throws UndefKeywordError MyFixedIncomeLatestQuotesEndpointModel()
    @test_throws UndefKeywordError MyLogoEndpointModel()
    for model in (MyNewsEndpointModel(), MyMostActivesEndpointModel(), MyMoversEndpointModel(), MyCorporateActionsEndpointModel(),
                  MyLogoEndpointModel(symbol = "A"), MyFixedIncomeLatestPricesEndpointModel(isins = "A"),
                  MyFixedIncomeLatestQuotesEndpointModel(isins = "A"))
        @test model isa Alpaca.AbstractAlpacaMarketDataEndpointModel
    end
    @test Alpaca._is_paginated(MyNewsEndpointModel()) == false
    @test Alpaca._is_paginated(MyMostActivesEndpointModel()) == false
    @test Alpaca._is_paginated(MyMoversEndpointModel()) == false
    @test Alpaca._is_paginated(MyCorporateActionsEndpointModel()) == true
    @test Alpaca._is_paginated(MyLogoEndpointModel(symbol = "A")) == false
    @test Alpaca._is_paginated(MyFixedIncomeLatestPricesEndpointModel(isins = "A")) == false
end

@testset "v0.5 market: news handler" begin
    body = """{"news":[{"id":127411699,"headline":"H1","author":"A1","created_at":"2026-11-20T15:00:00Z","updated_at":"2026-11-20T15:05:00Z","summary":"S1","content":"C1","url":"http://x/1","images":[],"symbols":["AAPL","MSFT"],"source":"benzinga"},
    {"id":2,"headline":"H2","author":"A2","created_at":"2026-11-19T10:00:00Z","updated_at":"2026-11-19T10:00:00Z","summary":"S2","url":"http://x/2","images":[],"symbols":[],"source":"x"}],"next_page_token":"n"}"""
    df = Alpaca._default_handler(MyNewsEndpointModel, body)
    @test names(df) == ["id", "created_at", "updated_at", "headline", "author", "source", "summary", "url", "symbols", "content"]
    @test df.id == [127411699, 2]
    @test df.created_at == [DateTime(2026, 11, 20, 15), DateTime(2026, 11, 19, 10)]
    @test df.symbols == ["AAPL,MSFT", ""]
    @test df.content[1] == "C1"
    @test ismissing(df.content[2])
    @test df.headline == ["H1", "H2"]

    # empty bodies give no rows, with the same columns -
    for empty_body in ("[]", """{"news":[],"next_page_token":null}""")
        df = Alpaca._default_handler(MyNewsEndpointModel, empty_body)
        @test nrow(df) == 0
        @test names(df) == ["id", "created_at", "updated_at", "headline", "author", "source", "summary", "url", "symbols", "content"]
    end
end

@testset "v0.5 market: screener handlers" begin
    df = Alpaca._default_handler(MyMostActivesEndpointModel,
        """{"most_actives":[{"symbol":"AAPL","volume":1000,"trade_count":50},{"symbol":"TSLA","volume":900,"trade_count":70}],"last_updated":"2026-11-20T15:00:00Z"}""")
    @test names(df) == ["symbol", "volume", "trade_count"]
    @test df.symbol == ["AAPL", "TSLA"]
    @test df.volume == [1000, 900]
    @test df.trade_count == [50, 70]
    df = Alpaca._default_handler(MyMostActivesEndpointModel, """{"most_actives":[],"last_updated":"x"}""")
    @test nrow(df) == 0
    @test names(df) == ["symbol", "volume", "trade_count"]

    # gainers come first, then losers -
    df = Alpaca._default_handler(MyMoversEndpointModel,
        """{"gainers":[{"symbol":"A","price":10.5,"change":1.5,"percent_change":16.6},{"symbol":"B","price":5,"change":0.5,"percent_change":11}],
        "losers":[{"symbol":"C","price":3,"change":-1,"percent_change":-25}],"market_type":"stocks","last_updated":"x"}""")
    @test names(df) == ["direction", "symbol", "price", "change", "percent_change"]
    @test df.direction == ["gainer", "gainer", "loser"]
    @test df.symbol == ["A", "B", "C"]
    @test df.price == [10.5, 5.0, 3.0]
    @test df.change == [1.5, 0.5, -1.0]
    @test df.percent_change == [16.6, 11.0, -25.0]
    df = Alpaca._default_handler(MyMoversEndpointModel, """{"gainers":[],"losers":[],"market_type":"stocks","last_updated":"x"}""")
    @test nrow(df) == 0
    @test names(df) == ["direction", "symbol", "price", "change", "percent_change"]
end

@testset "v0.5 market: corporate actions handler" begin
    body = """{"corporate_actions":{"cash_dividends":[{"id":"d1","symbol":"AAPL","rate":0.25,"ex_date":"2026-11-07","process_date":"2026-11-14"}],
    "forward_splits":[{"id":"s1","symbol":"NVDA","new_rate":10,"old_rate":1,"ex_date":"2026-06-10"}]},"next_page_token":null}"""
    df = Alpaca._default_handler(MyCorporateActionsEndpointModel, body)
    @test df.type == ["cash_dividends", "forward_splits"]
    @test names(df)[1] == "type"
    @test df.symbol == ["AAPL", "NVDA"]
    @test df.id == ["d1", "s1"]
    @test df[1, :rate] == 0.25
    @test ismissing(df[2, :rate])
    @test df[2, :new_rate] == 10.0
    @test ismissing(df[1, :new_rate])

    # a body with no matches gives no rows, with at least the type column -
    df = Alpaca._default_handler(MyCorporateActionsEndpointModel, """{"corporate_actions":{},"next_page_token":null}""")
    @test nrow(df) == 0
    @test "type" in names(df)
end

@testset "v0.5 market: fixed income handlers" begin
    df = Alpaca._default_handler(MyFixedIncomeLatestPricesEndpointModel,
        """{"prices":{"US1":{"t":"2026-11-20T15:00:00Z","p":99.5,"ytm":4.1,"ytw":4.0},"US2":{"t":"2026-11-20T16:00:00Z","p":101,"ytm":3.9,"ytw":3.8}}}""")
    @test names(df) == ["isin", "t", "p", "ytm", "ytw"]
    @test df.isin == ["US1", "US2"]
    @test df.t == [DateTime(2026, 11, 20, 15), DateTime(2026, 11, 20, 16)]
    @test df.p == [99.5, 101.0]
    df = Alpaca._default_handler(MyFixedIncomeLatestQuotesEndpointModel,
        """{"quotes":{"US1":{"t":"2026-11-20T15:00:00Z","bp":99,"bs":10,"ap":100,"as":20,"bytm":4.2,"aytm":4.0,"bytw":4.1,"aytw":3.9,"bms":"x","ams":"y"}}}""")
    @test df.isin == ["US1"]
    @test df.bp == [99.0]
    @test df.as == [20.0]
    @test df.t == [DateTime(2026, 11, 20, 15)]
    @test df.bms == ["x"]
    @test names(df)[1] == "isin"
    for (model, body) in ((MyFixedIncomeLatestPricesEndpointModel, """{"prices":{}}"""), (MyFixedIncomeLatestQuotesEndpointModel, """{"quotes":null}"""))
        df = Alpaca._default_handler(model, body)
        @test nrow(df) == 0
        @test names(df) == ["isin"]
    end
end

@testset "v0.5 market: api through the mock server" begin
    # corporate actions that span two pages -
    handler, log = recording_handler() do req
        if occursin("page_token=p2", req.target)
            return json_response(200, Dict("corporate_actions" => Dict("forward_splits" => Any[Dict("id" => "s1", "symbol" => "NVDA", "new_rate" => 10)]),
                "next_page_token" => nothing))
        end
        return json_response(200, Dict("corporate_actions" => Dict("cash_dividends" => Any[Dict("id" => "d1", "symbol" => "AAPL", "rate" => 0.25)]),
            "next_page_token" => "p2"))
    end
    with_mock(handler) do client
        df = api(client, MyCorporateActionsEndpointModel(symbols = ["AAPL", "NVDA"]))
        @test nrow(df) == 2
        @test df.type == ["cash_dividends", "forward_splits"]
        @test df.symbol == ["AAPL", "NVDA"]
        @test df.id == ["d1", "s1"]
        @test ismissing(df[2, :rate])
        @test ismissing(df[1, :new_rate])
    end
    @test length(log) == 2
    @test startswith(log[1].path, "/corporate-actions")
    @test occursin("symbols=AAPL%2CNVDA", log[1].query)

    # the logo bytes come back unchanged -
    png = UInt8[0x89, 0x50, 0x4e, 0x47]
    handler2, log2 = recording_handler(req -> HTTP.Response(200, ["Content-Type" => "image/png"], png))
    with_mock(handler2) do client
        bytes = api(client, MyLogoEndpointModel(symbol = "AAPL"))
        @test bytes isa Vector{UInt8}
        @test bytes == png
    end
    @test length(log2) == 1
    @test log2[1].path == "/logos/AAPL"

    # news is one request, even when the response holds a page token -
    handler3, log3 = recording_handler(req -> json_response(200, Dict("news" => Any[Dict("id" => 1, "headline" => "H", "author" => "A",
        "created_at" => "2026-11-20T15:00:00Z", "updated_at" => "2026-11-20T15:00:00Z", "summary" => "S", "url" => "u",
        "images" => Any[], "symbols" => Any["AAPL"], "source" => "s")], "next_page_token" => "more")))
    with_mock(handler3) do client
        df = api(client, MyNewsEndpointModel(symbols = "AAPL"))
        @test df.symbols == ["AAPL"]
    end
    @test length(log3) == 1
    @test log3[1].path == "/news"

    # screener and fixed income requests -
    handler4, log4 = recording_handler(req -> json_response(200, Dict("gainers" => Any[Dict("symbol" => "A", "price" => 1, "change" => 0.1, "percent_change" => 10)],
        "losers" => Any[], "market_type" => "stocks", "last_updated" => "x")))
    with_mock(handler4) do client
        df = api(client, MyMoversEndpointModel())
        @test df.direction == ["gainer"]
    end
    @test log4[1].path == "/screener/stocks/movers"
    handler5, log5 = recording_handler(req -> json_response(200, Dict("prices" => Dict("US1" => Dict("t" => "2026-11-20T15:00:00Z", "p" => 99.5, "ytm" => 4.1, "ytw" => 4.0)))))
    with_mock(handler5) do client
        df = api(client, MyFixedIncomeLatestPricesEndpointModel(isins = "US1"))
        @test df.isin == ["US1"]
    end
    @test log5[1].path == "/fixed_income/latest/prices"
end
