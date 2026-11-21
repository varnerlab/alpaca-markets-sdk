using DataFrames

# payloads shared by the market data handler tests -
const _N_BAR_A = Dict{String,Any}("t" => "2026-11-17T14:30:00Z", "o" => 200.5, "h" => 201.0, "l" => 199.5,
    "c" => 200.75, "v" => 1200, "n" => 42, "vw" => 200.6)
const _N_BAR_B = Dict{String,Any}("t" => "2026-11-17T14:31:00Z", "o" => 200.75, "h" => 201.5, "l" => 200.5,
    "c" => 201.25, "v" => 900)
const _N_QUOTE = Dict{String,Any}("t" => "2026-11-17T14:30:00.5Z", "bp" => 200.1, "bs" => 3, "ap" => 200.2,
    "as" => 5, "bx" => "V", "ax" => "Q")
const _N_TRADE = Dict{String,Any}("t" => "2026-11-17T14:30:01Z", "p" => 200.15, "s" => 100, "x" => "V", "i" => 777)
const _N_SNAP_WITH_GREEKS = Dict{String,Any}("latestQuote" => _N_QUOTE, "latestTrade" => _N_TRADE,
    "impliedVolatility" => 0.31,
    "greeks" => Dict{String,Any}("delta" => -0.42, "gamma" => 0.03, "theta" => -0.05, "vega" => 0.11, "rho" => -0.02))
const _N_SNAP_NO_GREEKS = Dict{String,Any}("latestQuote" => _N_QUOTE)

# the column names of each table -
const _N_BAR_COLUMNS = ["timestamp", "symbol", "open", "high", "low", "close", "volume", "trade_count", "vwap"]
const _N_QUOTE_COLUMNS = ["timestamp", "symbol", "bid_price", "bid_size", "ask_price", "ask_size", "bid_exchange",
    "ask_exchange"]
const _N_TRADE_COLUMNS = ["timestamp", "symbol", "price", "size", "exchange", "id"]

@testset "handler: stock bars" begin
    body = JSON3.write(Dict("bars" => Dict("AAPL" => [_N_BAR_A, _N_BAR_B]), "next_page_token" => nothing))
    df = Alpaca._default_handler(MyStockBarsEndpointModel, body)
    @test names(df) == _N_BAR_COLUMNS
    @test df.symbol == ["AAPL", "AAPL"]
    @test df[1, :timestamp] == DateTime(2026, 11, 17, 14, 30)
    @test df[1, :close] == 200.75
    @test df[1, :trade_count] == 42
    @test ismissing(df[2, :trade_count])          # _N_BAR_B has no "n"
    @test ismissing(df[2, :vwap])
end

@testset "handler: bars rows follow the response order" begin
    body = """{"bars":{"MSFT":[{"t":"2026-11-17T14:30:00Z","c":1.0}],"AAPL":[{"t":"2026-11-17T14:30:00Z","c":2.0},{"t":"2026-11-17T14:31:00Z","c":3.0}]}}"""
    df = Alpaca._default_handler(MyStockBarsEndpointModel, body)
    @test df.symbol == ["MSFT", "AAPL", "AAPL"]
    @test df.close == [1.0, 2.0, 3.0]
end

@testset "handler: empty bars response keeps every column" begin
    df = Alpaca._default_handler(MyStockBarsEndpointModel, JSON3.write(Dict("bars" => Dict(), "next_page_token" => nothing)))
    @test size(df) == (0, 9)
    df2 = Alpaca._default_handler(MyStockBarsEndpointModel, JSON3.write(Dict("bars" => nothing)))
    @test size(df2) == (0, 9)
    df3 = Alpaca._default_handler(MyOptionBarsEndpointModel, JSON3.write(Dict("bars" => nothing)))
    @test size(df3) == (0, 9)
end

@testset "handler: stock quotes and trades" begin
    dfq = Alpaca._default_handler(MyStockQuotesEndpointModel, JSON3.write(Dict("quotes" => Dict("AAPL" => [_N_QUOTE]))))
    @test names(dfq) == _N_QUOTE_COLUMNS
    @test dfq[1, :bid_price] == 200.1
    @test dfq[1, :ask_size] == 5
    @test dfq[1, :bid_exchange] == "V"
    @test dfq[1, :timestamp] == DateTime(2026, 11, 17, 14, 30, 0, 500)
    dft = Alpaca._default_handler(MyStockTradesEndpointModel, JSON3.write(Dict("trades" => Dict("AAPL" => [_N_TRADE]))))
    @test names(dft) == _N_TRADE_COLUMNS
    @test dft[1, :price] == 200.15
    @test dft[1, :size] == 100
    @test dft[1, :id] == 777
end

@testset "handler: latest stock bar, quote, and trade" begin
    dfb = Alpaca._default_handler(MyStockLatestBarEndpointModel, JSON3.write(Dict("symbol" => "AAPL", "bar" => _N_BAR_A)))
    @test names(dfb) == _N_BAR_COLUMNS
    @test dfb.symbol == ["AAPL"]
    @test dfb[1, :open] == 200.5
    dft = Alpaca._default_handler(MyStockLatestTradeEndpointModel, JSON3.write(Dict("symbol" => "AAPL", "trade" => _N_TRADE)))
    @test names(dft) == _N_TRADE_COLUMNS
    @test dft.symbol == ["AAPL"]
end

@testset "handler: latest quote without symbol" begin
    df = Alpaca._default_handler(MyStockLatestQuoteEndpointModel, JSON3.write(Dict("quote" => _N_QUOTE)))
    @test size(df, 1) == 1
    @test ismissing(df[1, :symbol])
    @test df[1, :ask_price] == 200.2
end

@testset "handler: stock snapshots" begin
    body = JSON3.write(Dict("AAPL" => Dict("latestTrade" => _N_TRADE, "latestQuote" => _N_QUOTE,
        "minuteBar" => _N_BAR_A)))
    df = Alpaca._default_handler(MyStockSnapshotsEndpointModel, body)
    @test names(df)[1] == "symbol"
    @test names(df)[2:7] == ["latest_trade_timestamp", "latest_trade_price", "latest_trade_size",
        "latest_trade_exchange", "latest_trade_id", "latest_quote_timestamp"]
    @test size(df) == (1, 1 + 5 + 7 + 8 + 8 + 8)
    @test "prev_daily_bar_vwap" in names(df)
    @test df[1, :symbol] == "AAPL"
    @test df[1, :latest_trade_price] == 200.15
    @test df[1, :minute_bar_close] == 200.75
    @test ismissing(df[1, :daily_bar_close])      # no dailyBar in the payload
    @test ismissing(df[1, :prev_daily_bar_open])
end

@testset "handler: option bars, quotes, and trades" begin
    sym = "SPY261218P00500000"
    dfb = Alpaca._default_handler(MyOptionBarsEndpointModel, JSON3.write(Dict("bars" => Dict(sym => [_N_BAR_A, _N_BAR_B]))))
    @test names(dfb) == _N_BAR_COLUMNS
    @test dfb.symbol == [sym, sym]
    dft = Alpaca._default_handler(MyOptionTradesEndpointModel, JSON3.write(Dict("trades" => Dict(sym => [_N_TRADE]))))
    @test names(dft) == _N_TRADE_COLUMNS
    @test dft[1, :symbol] == sym
end

@testset "handler: latest option quote and trade" begin
    dfq = Alpaca._default_handler(MyOptionLatestQuoteEndpointModel, JSON3.write(Dict("quotes" => Dict("SPY261218P00500000" => _N_QUOTE))))
    @test names(dfq) == _N_QUOTE_COLUMNS
    @test dfq[1, :symbol] == "SPY261218P00500000"
    dft = Alpaca._default_handler(MyOptionLatestTradeEndpointModel, JSON3.write(Dict("trades" => Dict("SPY261218P00500000" => _N_TRADE))))
    @test names(dft) == _N_TRADE_COLUMNS
    @test dft[1, :price] == 200.15
end

@testset "handler: option snapshots accept both shapes" begin
    wrapped = JSON3.write(Dict("snapshots" => Dict("SPY261218P00500000" => _N_SNAP_WITH_GREEKS)))
    bare = JSON3.write(Dict("SPY261218P00500000" => _N_SNAP_WITH_GREEKS))
    df1 = Alpaca._default_handler(MyOptionSnapshotsEndpointModel, wrapped)
    df2 = Alpaca._default_handler(MyOptionSnapshotsEndpointModel, bare)
    @test size(df1) == (1, 1 + 5 + 7 + 8 + 8 + 8 + 6)
    @test names(df1)[end-5:end] == ["implied_volatility", "delta", "gamma", "theta", "vega", "rho"]
    @test df1[1, :implied_volatility] == 0.31
    @test df1[1, :rho] == -0.02
    @test isequal(df1, df2)
end

@testset "handler: option chain flattens greeks" begin
    body = """{"snapshots":{"SPY261218P00500000":{"latestQuote":{"t":"2026-11-17T14:30:00Z","bp":1.0,"ap":1.2},"impliedVolatility":0.31,"greeks":{"delta":-0.42,"gamma":0.03,"theta":-0.05,"vega":0.11,"rho":-0.02}},"SPY261218C00600000":{"latestQuote":{"bp":2.0,"ap":2.2}}},"next_page_token":null}"""
    df = Alpaca._default_handler(MyOptionChainEndpointModel, body)
    @test size(df, 1) == 2
    @test df[df.symbol .== "SPY261218P00500000", :delta] == [-0.42]
    @test ismissing(df[df.symbol .== "SPY261218C00600000", :delta][1])
    @test ismissing(df[df.symbol .== "SPY261218C00600000", :implied_volatility][1])
    @test df[df.symbol .== "SPY261218C00600000", :latest_quote_bid_price] == [2.0]
    @test "latest_quote_bid_price" in names(df)
end

# the column names of the snapshot tables -
const _N_SNAP_COLUMNS = vcat(["symbol"],
    "latest_trade_" .* _N_TRADE_COLUMNS[[1; 3:end]], "latest_quote_" .* _N_QUOTE_COLUMNS[[1; 3:end]],
    "minute_bar_" .* _N_BAR_COLUMNS[[1; 3:end]], "daily_bar_" .* _N_BAR_COLUMNS[[1; 3:end]],
    "prev_daily_bar_" .* _N_BAR_COLUMNS[[1; 3:end]])
const _N_SNAP_COLUMNS_GREEKS = vcat(_N_SNAP_COLUMNS, ["implied_volatility", "delta", "gamma", "theta", "vega", "rho"])

@testset "handler: empty and null responses keep every column" begin
    # bars, quotes, and trades, stock and option -
    for (model, key, columns) in [
            (MyStockBarsEndpointModel, "bars", _N_BAR_COLUMNS), (MyOptionBarsEndpointModel, "bars", _N_BAR_COLUMNS),
            (MyStockQuotesEndpointModel, "quotes", _N_QUOTE_COLUMNS),
            (MyStockTradesEndpointModel, "trades", _N_TRADE_COLUMNS), (MyOptionTradesEndpointModel, "trades", _N_TRADE_COLUMNS),
            (MyOptionLatestQuoteEndpointModel, "quotes", _N_QUOTE_COLUMNS),
            (MyOptionLatestTradeEndpointModel, "trades", _N_TRADE_COLUMNS)]
        for body in ["{\"$key\":{}}", "{\"$key\":null}", "{}"]
            df = Alpaca._default_handler(model, body)
            @test size(df, 1) == 0
            @test names(df) == columns
        end
    end

    # latest stock bar, quote, and trade with a null or absent record -
    for (model, key, columns) in [
            (MyStockLatestBarEndpointModel, "bar", _N_BAR_COLUMNS), (MyStockLatestQuoteEndpointModel, "quote", _N_QUOTE_COLUMNS),
            (MyStockLatestTradeEndpointModel, "trade", _N_TRADE_COLUMNS)]
        for body in ["{\"symbol\":\"AAPL\",\"$key\":null}", "{\"symbol\":\"AAPL\"}"]
            df = Alpaca._default_handler(model, body)
            @test size(df, 1) == 0
            @test names(df) == columns
        end
    end

    # snapshots, stock and option -
    @test length(_N_SNAP_COLUMNS) == 37
    for body in ["{}", "{\"snapshots\":{}}", "{\"snapshots\":null}"]
        df = Alpaca._default_handler(MyStockSnapshotsEndpointModel, body)
        @test size(df, 1) == 0
        @test names(df) == _N_SNAP_COLUMNS
        for model in [MyOptionSnapshotsEndpointModel, MyOptionChainEndpointModel]
            df = Alpaca._default_handler(model, body)
            @test size(df, 1) == 0
            @test names(df) == _N_SNAP_COLUMNS_GREEKS
        end
    end
end

@testset "api: three pages of bars are stacked once, in page order" begin
    handler, log = recording_handler() do req
        if occursin("page_token=p3", req.target)
            return json_response(200, Dict("bars" => Dict("AAPL" => [merge(_N_BAR_B, Dict("c" => 3.0))]), "next_page_token" => nothing))
        end
        if occursin("page_token=p2", req.target)
            return json_response(200, Dict("bars" => Dict(), "next_page_token" => "p3"))
        end
        return json_response(200, Dict("bars" => Dict("AAPL" => [_N_BAR_A, _N_BAR_B]), "next_page_token" => "p2"))
    end
    with_mock(handler) do client
        df = api(client, MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Min", start = "2026-11-17"))
        @test names(df) == _N_BAR_COLUMNS
        @test df.close == [200.75, 201.25, 3.0]
        @test eltype(df.close) == Union{Missing,Float64}
    end
    @test length(log) == 3
end
