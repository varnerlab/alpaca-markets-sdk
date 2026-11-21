@testset "v0.5 trading reads: URLs" begin
    @test url("http://h", MyAccountConfigurationsEndpointModel()) == "http://h/account/configurations"

    @test url("http://h", MyAccountActivitiesEndpointModel(activity_type = "FILL", date = Date(2026, 11, 20))) ==
          "http://h/account/activities/FILL?date=2026-11-20&direction=desc&page_size=100"
    @test url("http://h", MyAccountActivitiesEndpointModel(activity_types = ["DIV", "FILL"], category = "trade_activity",
              after = Date(2026, 11, 1), until = Date(2026, 11, 20), direction = "asc", page_size = 50,
              page_token = "tok", order_id = "o1")) ==
          "http://h/account/activities?activity_types=DIV%2CFILL&category=trade_activity&after=2026-11-01&until=2026-11-20&direction=asc&page_size=50&page_token=tok&order_id=o1"
    # category is sent only on the second path -
    @test url("http://h", MyAccountActivitiesEndpointModel(activity_type = "DIV", category = "trade_activity")) ==
          "http://h/account/activities/DIV?direction=desc&page_size=100"
    @test url("http://h", MyAccountActivitiesEndpointModel(activity_types = "DIV")) ==
          "http://h/account/activities?activity_types=DIV&direction=desc&page_size=100"
    @test_throws ArgumentError MyAccountActivitiesEndpointModel(activity_type = "FILL", activity_types = ["DIV"])

    @test url("http://h", MyPortfolioHistoryEndpointModel(period = "1M", timeframe = "1D", intraday_reporting = "continuous",
              start = Date(2026, 11, 1), finish = Date(2026, 11, 20), pnl_reset = "no_reset", extended_hours = true,
              cashflow_types = "ALL")) ==
          "http://h/account/portfolio/history?period=1M&timeframe=1D&intraday_reporting=continuous&start=2026-11-01&end=2026-11-20&pnl_reset=no_reset&extended_hours=true&cashflow_types=ALL"
    @test url("http://h", MyPortfolioHistoryEndpointModel()) == "http://h/account/portfolio/history"

    @test url("http://h", MyMarketCalendarEndpointModel(market = "XNAS", start = Date(2026, 11, 1), finish = Date(2026, 11, 30), timezone = "UTC")) ==
          "http://h/calendar/XNAS?start=2026-11-01&end=2026-11-30&timezone=UTC"
    @test url("http://h", MyMarketCalendarEndpointModel()) == "http://h/calendar/NYSE"

    @test url("http://h", MyMarketClocksEndpointModel(markets = "NYSE", time = DateTime(2026, 11, 20, 15))) ==
          "http://h/clock?markets=NYSE&time=2026-11-20T15%3A00%3A00Z"
    @test url("http://h", MyMarketClocksEndpointModel()) == "http://h/clock"
end

@testset "v0.5 trading reads: base URLs" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyMarketClocksEndpointModel(markets = ["NYSE", "XNAS"])) == "https://paper-api.alpaca.markets/v3/clock?markets=NYSE%2CXNAS"
    @test url(c, MyMarketCalendarEndpointModel(market = "XLON")) == "https://paper-api.alpaca.markets/v3/calendar/XLON"
    @test url(c, MyAccountConfigurationsEndpointModel()) == "https://paper-api.alpaca.markets/v2/account/configurations"
    @test url(c, MyPortfolioHistoryEndpointModel()) == "https://paper-api.alpaca.markets/v2/account/portfolio/history"
end

@testset "v0.5 trading reads: handlers" begin
    # configurations: one flat object, one row -
    df = Alpaca._default_handler(MyAccountConfigurationsEndpointModel,
        """{"dtbp_check":"entry","fractional_trading":true,"max_margin_multiplier":"4","no_shorting":false}""")
    @test size(df) == (1, 4)
    @test df[1, :dtbp_check] == "entry" && df[1, :fractional_trading] == true

    # activities: records differ by type -
    df = Alpaca._default_handler(MyAccountActivitiesEndpointModel,
        """[{"id":"a","activity_type":"FILL","transaction_time":"2026-11-20T15:00:00Z","qty":"5"},{"id":"b","activity_type":"DIV","net_amount":"1.5"}]""")
    @test size(df, 1) == 2
    @test df[1, :transaction_time] == DateTime(2026, 11, 20, 15)
    @test ismissing(df[2, :qty]) && df[2, :net_amount] == "1.5"

    # portfolio history -
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel,
        """{"timestamp":[1763650800],"equity":[100000],"profit_loss":[12.5],"profit_loss_pct":[0.0001],"base_value":100000,"base_value_asof":"2025-11-19","timeframe":"1D","cashflow":{}}""")
    @test names(df) == ["timestamp", "equity", "profit_loss", "profit_loss_pct", "base_value"]
    @test df[1, :timestamp] == DateTime(2025, 11, 20, 15)
    @test df.equity == [100000.0] && df.base_value == [100000.0]
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel,
        """{"timestamp":[],"equity":[],"profit_loss":[],"profit_loss_pct":[],"base_value":0}""")
    @test size(df) == (0, 5)
    df = Alpaca._default_handler(MyPortfolioHistoryEndpointModel,
        """{"timestamp":null,"equity":null,"profit_loss":null,"profit_loss_pct":null,"base_value":0}""")
    @test size(df) == (0, 5)

    # calendar -
    df = Alpaca._default_handler(MyMarketCalendarEndpointModel,
        """{"calendar":[{"date":"2026-11-20","settlement_date":"2026-11-23","core_start":"2026-11-20T14:30:00Z"}],"market":{"acronym":"NYSE","bic":"XNYS","mic":"XNYS","name":"NYSE","timezone":"America/New_York"}}""")
    @test names(df)[1] == "market" && df.market == ["NYSE"]
    @test df[1, :date] == "2026-11-20"

    # an empty or absent calendar keeps the market column -
    df = Alpaca._default_handler(MyMarketCalendarEndpointModel, """{"calendar":[],"market":{"acronym":"NYSE"}}""")
    @test size(df) == (0, 1) && names(df)[1] == "market"
    df = Alpaca._default_handler(MyMarketCalendarEndpointModel, """{"market":{"acronym":"NYSE"}}""")
    @test size(df, 1) == 0 && names(df)[1] == "market"

    # clocks -
    df = Alpaca._default_handler(MyMarketClocksEndpointModel,
        """{"clocks":[{"market":{"acronym":"NYSE","name":"NYSE"},"timestamp":"2026-11-20T15:00:00Z","is_market_day":true,"phase":"core","next_market_open":"2026-11-23T14:30:00Z"}]}""")
    @test df[1, :market_acronym] == "NYSE"
    @test df[1, :is_market_day] == true
    @test df[1, :timestamp] == DateTime(2026, 11, 20, 15)
end

@testset "v0.5 trading reads: api through the mock server" begin
    handler, log = recording_handler(req -> json_response(200, Dict("calendar" => Any[Dict("date" => "2026-11-20")], "market" => Dict("acronym" => "NYSE"))))
    with_mock(handler) do client
        df = api(client, MyMarketCalendarEndpointModel(market = "NYSE"))
        @test log[1].path == "/calendar/NYSE"
        @test df.market == ["NYSE"]
    end
end
