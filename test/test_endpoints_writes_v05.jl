# Tests for the v0.5 account settings, order replacement, and option exercise models -
using DataFrames: DataFrame

@testset "v0.5 writes: URLs and methods" begin
    settings = MyUpdateAccountConfigurationsEndpointModel(no_shorting = true)
    @test url("http://h", settings) == "http://h/account/configurations"
    @test Alpaca._http_method(settings) == "PATCH"

    replace_model = MyReplaceOrderEndpointModel(id = "o1", qty = 2)
    @test url("http://h", replace_model) == "http://h/orders/o1"
    @test url("http://h", MyReplaceOrderEndpointModel(id = "a/b", qty = 2)) == "http://h/orders/a%2Fb"
    @test Alpaca._http_method(replace_model) == "PATCH"

    exercise = MyExerciseOptionEndpointModel(symbol = "AAPL261218C00200000")
    @test url("http://h", exercise) == "http://h/positions/AAPL261218C00200000/exercise"
    @test Alpaca._http_method(exercise) == "POST"
    @test Alpaca._request_body(exercise) === nothing

    skip = MyDoNotExerciseOptionEndpointModel(symbol = "AAPL261218C00200000")
    @test url("http://h", skip) == "http://h/positions/AAPL261218C00200000/do-not-exercise"
    @test Alpaca._http_method(skip) == "POST"
    @test Alpaca._request_body(skip) === nothing
    @test url("http://h", MyExerciseOptionEndpointModel(symbol = "a/b")) == "http://h/positions/a%2Fb/exercise"
end

@testset "v0.5 writes: bodies" begin
    @test Alpaca._request_body(MyUpdateAccountConfigurationsEndpointModel(no_shorting = true)) == Dict("no_shorting" => true)
    full = MyUpdateAccountConfigurationsEndpointModel(disable_overnight_trading = false, fractional_trading = true,
        max_margin_multiplier = 2, max_options_trading_level = 2, no_shorting = false, ptp_no_exception_entry = true,
        suspend_trade = false, trade_confirm_email = "all")
    @test Alpaca._request_body(full) == Dict("disable_overnight_trading" => false, "fractional_trading" => true,
        "max_margin_multiplier" => "2", "max_options_trading_level" => 2, "no_shorting" => false,
        "ptp_no_exception_entry" => true, "suspend_trade" => false, "trade_confirm_email" => "all")
    @test Alpaca._request_body(MyUpdateAccountConfigurationsEndpointModel(max_margin_multiplier = "4"))["max_margin_multiplier"] == "4"
    @test Alpaca._request_body(MyUpdateAccountConfigurationsEndpointModel(max_options_trading_level = 0)) == Dict("max_options_trading_level" => 0)

    @test Alpaca._request_body(MyReplaceOrderEndpointModel(id = "o1", limit_price = 101.5)) == Dict("limit_price" => "101.5")
    all_fields = MyReplaceOrderEndpointModel(id = "o1", qty = 3, time_in_force = "gtc", limit_price = 101.5, stop_price = 99,
        trail = 1.25, client_order_id = "c1")
    @test Alpaca._request_body(all_fields) == Dict("qty" => "3", "time_in_force" => "gtc", "limit_price" => "101.5",
        "stop_price" => "99", "trail" => "1.25", "client_order_id" => "c1")
end

@testset "v0.5 writes: argument errors" begin
    @test_throws ArgumentError MyUpdateAccountConfigurationsEndpointModel()
    @test_throws ArgumentError MyUpdateAccountConfigurationsEndpointModel(max_options_trading_level = 4)
    @test_throws ArgumentError MyUpdateAccountConfigurationsEndpointModel(max_options_trading_level = -1)
    @test_throws ArgumentError MyReplaceOrderEndpointModel(id = "o1")
end

@testset "v0.5 writes: tables" begin
    cfg = """{"dtbp_check":"entry","trade_confirm_email":"all","suspend_trade":false,"no_shorting":true,"fractional_trading":true,"max_margin_multiplier":"4","max_options_trading_level":2,"pdt_check":"entry","ptp_no_exception_entry":false}"""
    df = Alpaca._default_handler(MyUpdateAccountConfigurationsEndpointModel, cfg)
    @test size(df, 1) == 1
    @test df[1, :no_shorting] == true && df[1, :max_margin_multiplier] == "4"

    order = """{"id":"o1","client_order_id":"c1","symbol":"AAPL","qty":"1","limit_price":"101.5","status":"accepted","side":"buy","type":"limit","time_in_force":"day"}"""
    odf = Alpaca._default_handler(MyReplaceOrderEndpointModel, order)
    @test size(odf, 1) == 1 && odf[1, :id] == "o1"

    @test Alpaca._default_handler(MyExerciseOptionEndpointModel, "") == DataFrame()
    @test Alpaca._default_handler(MyDoNotExerciseOptionEndpointModel, "") == DataFrame()
end

@testset "v0.5 writes: mock round trips" begin
    order = """{"id":"o1","client_order_id":"c1","symbol":"AAPL","qty":"1","limit_price":"101.5","status":"accepted","side":"buy","type":"limit","time_in_force":"day"}"""
    handler, log = recording_handler(req -> HTTP.Response(200, ["Content-Type" => "application/json"], order))
    with_mock(handler) do client
        df = api(client, MyReplaceOrderEndpointModel(id = "o1", limit_price = 101.5))
        @test df[1, :id] == "o1"
        @test length(log.entries) == 1
        @test log.entries[1].method == "PATCH"
        @test log.entries[1].target == "/orders/o1"
        @test JSON3.read(log.entries[1].body).limit_price == "101.5"
    end

    cfg = """{"no_shorting":true,"suspend_trade":false}"""
    handler, log = recording_handler(req -> HTTP.Response(200, ["Content-Type" => "application/json"], cfg))
    with_mock(handler) do client
        df = api(client, MyUpdateAccountConfigurationsEndpointModel(no_shorting = true))
        @test size(df, 1) == 1 && df[1, :no_shorting] == true
        @test log.entries[1].method == "PATCH"
        @test log.entries[1].target == "/account/configurations"
        @test JSON3.read(log.entries[1].body).no_shorting == true
    end

    handler, log = recording_handler(req -> HTTP.Response(200))
    with_mock(handler) do client
        df = api(client, MyExerciseOptionEndpointModel(symbol = "AAPL261218C00200000"))
        @test size(df) == (0, 0)
        @test log.entries[1].method == "POST"
        @test log.entries[1].target == "/positions/AAPL261218C00200000/exercise"
        df = api(client, MyDoNotExerciseOptionEndpointModel(symbol = "AAPL261218C00200000"))
        @test size(df) == (0, 0)
        @test log.entries[2].target == "/positions/AAPL261218C00200000/do-not-exercise"
    end
end
