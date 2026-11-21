@testset "url: stock bars" begin
    m = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = Date(2025, 1, 2), finish = Date(2025, 1, 3))
    @test url("http://h", m) == "http://h/stocks/bars?symbols=AAPL%2CMSFT&timeframe=1Day&start=2025-01-02&end=2025-01-03&limit=1000&adjustment=raw&feed=iex"
    m2 = MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Min", start = DateTime(2025, 1, 2, 14, 30))
    @test url("http://h", m2) == "http://h/stocks/bars?symbols=AAPL&timeframe=1Min&start=2025-01-02T14%3A30%3A00Z&limit=1000&adjustment=raw&feed=iex"
end

@testset "url: trading endpoints" begin
    @test url("http://h", MyAccountEndpointModel()) == "http://h/account"
    @test url("http://h", MyCalendarEndpointModel()) == "http://h/calendar"
    @test url("http://h", MyCalendarEndpointModel(start = Date(2026, 11, 16), finish = Date(2026, 11, 17))) ==
          "http://h/calendar?start=2026-11-16&end=2026-11-17"
    @test url("http://h", MyOrdersEndpointModel(symbols = ["AAPL", "MSFT"])) ==
          "http://h/orders?status=open&limit=50&direction=desc&symbols=AAPL%2CMSFT"
    @test url("http://h", MyOrderEndpointModel(id = "ord-1")) == "http://h/orders/ord-1"
    @test url("http://h", MyOrderEndpointModel(client_order_id = "cid-1")) ==
          "http://h/orders:by_client_order_id?client_order_id=cid-1"
    @test_throws ArgumentError MyOrderEndpointModel()
    @test_throws ArgumentError MyOrderEndpointModel(id = "a", client_order_id = "b")
end

@testset "url: options endpoints" begin
    m = MyOptionChainEndpointModel(underlying = "SPY", type = "call", strike_price_gte = 140,
                                   expiration_date = Date(2026, 12, 18))
    @test url("http://h", m) == "http://h/options/snapshots/SPY?type=call&strike_price_gte=140&expiration_date=2026-12-18&limit=1000"
    @test url("http://h", MyOptionLatestQuoteEndpointModel(symbols = ["A1", "B2"])) ==
          "http://h/options/quotes/latest?symbols=A1%2CB2"
    @test url("http://h", MyStockLatestBarEndpointModel(symbol = "AAPL")) == "http://h/stocks/AAPL/bars/latest?feed=iex"
end

@testset "url: client picks the base URL" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyClockEndpointModel()) == "https://paper-api.alpaca.markets/v2/clock"
    @test startswith(url(c, MyStockSnapshotsEndpointModel(symbols = "AAPL")), "https://data.alpaca.markets/v2/stocks/snapshots")
    @test startswith(url(c, MyOptionSnapshotsEndpointModel(symbols = "X")), "https://data.alpaca.markets/v1beta1/options/snapshots")
    @test Alpaca._is_paginated(MyStockBarsEndpointModel(symbols = "A", timeframe = "1Day", start = "2025-01-01")) == true
    @test Alpaca._is_paginated(MyAccountEndpointModel()) == false
end

@testset "url: remaining trading models" begin
    @test url("http://h", MyClockEndpointModel()) == "http://h/clock"
    @test url("http://h", MyPositionsEndpointModel()) == "http://h/positions"
    @test url("http://h", MyPositionEndpointModel(symbol = "AAPL")) == "http://h/positions/AAPL"
    @test url("http://h", MyAssetsEndpointModel()) == "http://h/assets?status=active&asset_class=us_equity"
    @test url("http://h", MyAssetEndpointModel(symbol = "AAPL")) == "http://h/assets/AAPL"
    @test url("http://h", MyOptionContractEndpointModel(symbol = "AAPL251219C00200000")) ==
          "http://h/options/contracts/AAPL251219C00200000"
    m = MyOptionContractsEndpointModel(underlying_symbols = "AAPL", expiration_date_gte = Date(2026, 12, 1),
                                       strike_price_lte = 150.5, type = "put", style = "american")
    @test url("http://h", m) == "http://h/options/contracts?underlying_symbols=AAPL&status=active&expiration_date_gte=2026-12-01&strike_price_lte=150.5&type=put&style=american&limit=1000"
    o = MyOrdersEndpointModel(after = "2026-11-01", until = DateTime(2026, 11, 2), limit = 10, symbols = "AAPL,MSFT")
    @test url("http://h", o) == "http://h/orders?status=open&limit=10&after=2026-11-01&until=2026-11-02T00%3A00%3A00&direction=desc&symbols=AAPL%2CMSFT"
end

@testset "url: remaining stock models" begin
    @test url("http://h", MyStockQuotesEndpointModel(symbols = ["A", "B"], start = "2025-01-01")) ==
          "http://h/stocks/quotes?symbols=A%2CB&start=2025-01-01&limit=1000&feed=iex"
    @test url("http://h", MyStockTradesEndpointModel(symbols = "A", start = "2025-01-01", finish = "2025-01-02", feed = "sip")) ==
          "http://h/stocks/trades?symbols=A&start=2025-01-01&end=2025-01-02&limit=1000&feed=sip"
    @test url("http://h", MyStockLatestQuoteEndpointModel(symbol = "A")) == "http://h/stocks/A/quotes/latest?feed=iex"
    @test url("http://h", MyStockLatestTradeEndpointModel(symbol = "A", feed = "sip")) == "http://h/stocks/A/trades/latest?feed=sip"
    @test url("http://h", MyStockSnapshotsEndpointModel(symbols = ["A", "B"])) == "http://h/stocks/snapshots?symbols=A%2CB&feed=iex"
end

@testset "url: remaining option models" begin
    @test url("http://h", MyOptionBarsEndpointModel(symbols = "X", timeframe = "1Day", start = "2025-01-01")) ==
          "http://h/options/bars?symbols=X&timeframe=1Day&start=2025-01-01&limit=1000"
    @test url("http://h", MyOptionTradesEndpointModel(symbols = ["X", "Y"], start = Date(2025, 1, 1), finish = Date(2025, 1, 2))) ==
          "http://h/options/trades?symbols=X%2CY&start=2025-01-01&end=2025-01-02&limit=1000"
    @test url("http://h", MyOptionLatestTradeEndpointModel(symbols = "X")) == "http://h/options/trades/latest?symbols=X"
    @test url("http://h", MyOptionSnapshotsEndpointModel(symbols = ["X", "Y"])) == "http://h/options/snapshots?symbols=X%2CY"
end

@testset "models: symbols keyword stores a Vector{String}" begin
    @test MyStockSnapshotsEndpointModel(symbols = "AAPL,MSFT").symbols == ["AAPL,MSFT"]
    @test MyStockSnapshotsEndpointModel(symbols = SubString.(["A", "B"])).symbols isa Vector{String}
    @test MyOrdersEndpointModel().symbols === nothing
    @test MyOrdersEndpointModel(symbols = "AAPL").symbols == ["AAPL"]
    @test MyOptionContractsEndpointModel(underlying_symbols = ["A", "B"]).underlying_symbols == ["A", "B"]
    @test MyStockBarsEndpointModel(symbols = "A", timeframe = "1Day", start = "2025-01-01") isa AbstractAlpacaStockDataEndpointModel
    @test MyOptionChainEndpointModel(underlying = "SPY") isa AbstractAlpacaOptionDataEndpointModel
    @test MyAccountEndpointModel() isa AbstractAlpacaTradingEndpointModel
    @test_throws UndefKeywordError MyStockBarsEndpointModel(timeframe = "1Day", start = "2025-01-01")
end

@testset "models: every paginated URL holds a ?" begin
    ms = [MyStockBarsEndpointModel(symbols = "A", timeframe = "1Day", start = "2025-01-01"),
          MyStockQuotesEndpointModel(symbols = "A", start = "2025-01-01"),
          MyStockTradesEndpointModel(symbols = "A", start = "2025-01-01"),
          MyOptionBarsEndpointModel(symbols = "A", timeframe = "1Day", start = "2025-01-01"),
          MyOptionTradesEndpointModel(symbols = "A", start = "2025-01-01"),
          MyOptionContractsEndpointModel(underlying_symbols = "A"),
          MyOptionChainEndpointModel(underlying = "A")]
    for m in ms
        @test Alpaca._is_paginated(m)
        @test occursin('?', url("http://h", m))
    end
end

@testset "url: symbol keywords accept any string or vector" begin
    base = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day", start = "2025-01-02")
    as_any = MyStockBarsEndpointModel(symbols = Any["AAPL", "MSFT"], timeframe = "1Day", start = "2025-01-02")
    @test url("http://h", as_any) == url("http://h", base)
    sub = MyStockBarsEndpointModel(symbols = SubString("AAPL,x", 1, 4), timeframe = "1Day", start = "2025-01-02")
    single = MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Day", start = "2025-01-02")
    @test url("http://h", sub) == url("http://h", single)
    @test as_any.symbols isa Vector{String}
    orders = MyOrdersEndpointModel(symbols = ["AAPL", "MSFT"])
    @test url("http://h", MyOrdersEndpointModel(symbols = Any["AAPL", "MSFT"])) == url("http://h", orders)
    @test url("http://h", MyOrdersEndpointModel(symbols = SubString("AAPL,x", 1, 4))) ==
          url("http://h", MyOrdersEndpointModel(symbols = "AAPL"))
end
