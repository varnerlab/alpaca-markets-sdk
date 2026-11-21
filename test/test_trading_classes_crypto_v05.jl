# Tests for the v0.5 order classes (bracket, OCO, OTO) and crypto orders -
const _N_CLASS_ORDER = Dict{String,Any}(
    "id" => "eq-1", "symbol" => "AAPL", "asset_class" => "us_equity", "side" => "buy",
    "type" => "limit", "time_in_force" => "day", "qty" => "10", "filled_qty" => "0",
    "status" => "accepted",
    "created_at" => "2026-11-17T14:30:00.123456Z", "submitted_at" => "2026-11-17T14:30:00.234567Z")

# run one submit call against the mock server and return the recorded requests -
function _class_call(f)
    handler, log = recording_handler() do _req
        return json_response(200, _N_CLASS_ORDER)
    end
    with_mock(handler) do client
        f(client)
    end
    return log
end

@testset "classes: plain equity order sends the 0.4.0 body" begin
    log = _class_call(c -> submit(c, MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10); type = "limit", limit_price = 150))
    body = JSON3.read(log[1].body)
    @test sort(String.(collect(keys(body)))) == sort(["symbol", "side", "type", "time_in_force", "extended_hours", "qty", "limit_price"])
    log = _class_call(c -> submit(c, MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10); order_class = "simple"))
    @test JSON3.read(log[1].body).order_class == "simple"
end

@testset "classes: bracket body" begin
    m = MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10)
    log = _class_call(c -> submit(c, m; type = "limit", limit_price = 100, order_class = "bracket",
        take_profit_limit_price = 110, stop_loss_stop_price = 90, stop_loss_limit_price = 89))
    body = JSON3.read(log[1].body)
    @test body.order_class == "bracket"
    @test body.take_profit.limit_price == "110"
    @test body.stop_loss.stop_price == "90"
    @test body.stop_loss.limit_price == "89"
    log = _class_call(c -> submit(c, m; order_class = "bracket", take_profit_limit_price = 110, stop_loss_stop_price = 90))
    @test !haskey(JSON3.read(log[1].body).stop_loss, :limit_price)
end

@testset "classes: oco and oto bodies" begin
    m = MyEquityOrderModel(symbol = "AAPL", side = "sell", qty = 10)
    log = _class_call(c -> submit(c, m; type = "limit", limit_price = 110, order_class = "oco",
        take_profit_limit_price = 110, stop_loss_stop_price = 90))
    body = JSON3.read(log[1].body)
    @test body.order_class == "oco"
    @test body.take_profit.limit_price == "110"
    @test body.stop_loss.stop_price == "90"
    log = _class_call(c -> submit(c, m; order_class = "oto", stop_loss_stop_price = 90))
    body = JSON3.read(log[1].body)
    @test body.order_class == "oto"
    @test !haskey(body, :take_profit)
    log = _class_call(c -> submit(c, m; order_class = "oto", take_profit_limit_price = 120))
    body = JSON3.read(log[1].body)
    @test body.take_profit.limit_price == "120"
    @test !haskey(body, :stop_loss)
end

@testset "classes: invalid combinations send nothing" begin
    m = MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10)
    cases = [
        (; order_class = "mleg"),
        (; order_class = "bracket", stop_loss_stop_price = 90),
        (; order_class = "bracket", take_profit_limit_price = 110),
        (; order_class = "oco", type = "limit", limit_price = 110, take_profit_limit_price = 110),
        (; order_class = "oco", type = "market", take_profit_limit_price = 110, stop_loss_stop_price = 90),
        (; order_class = "oto"),
        (; order_class = "oto", take_profit_limit_price = 110, stop_loss_stop_price = 90),
        (; take_profit_limit_price = 110),
        (; order_class = "simple", stop_loss_stop_price = 90),
        (; stop_loss_limit_price = 89),
        (; order_class = "bracket", take_profit_limit_price = 110, stop_loss_limit_price = 89),
    ]
    for kw in cases
        log = _class_call(c -> @test_throws ArgumentError submit(c, m; kw...))
        @test length(log) == 0
    end
end

@testset "crypto: model checks" begin
    @test_throws ArgumentError MyCryptoOrderModel(symbol = "BTC/USD", side = "long", qty = 1)
    @test_throws ArgumentError MyCryptoOrderModel(symbol = "BTC/USD", side = "buy")
    @test_throws ArgumentError MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", qty = 1, notional = 25)
end

@testset "crypto: notional buy and limit order" begin
    log = _class_call(c -> submit(c, MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", notional = 25)))
    body = JSON3.read(log[1].body)
    @test body.symbol == "BTC/USD"
    @test body.notional == "25"
    @test body.time_in_force == "gtc"
    @test body.type == "market"
    log = _class_call(c -> submit(c, MyCryptoOrderModel(symbol = "BTC/USD", side = "sell", qty = 2);
        type = "limit", limit_price = 100000, time_in_force = "ioc", client_order_id = "c1"))
    body = JSON3.read(log[1].body)
    @test body.qty == "2"
    @test body.limit_price == "100000"
    @test body.time_in_force == "ioc"
    @test body.client_order_id == "c1"
end

@testset "crypto: invalid input sends nothing" begin
    m = MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", qty = 0.001)
    log = _class_call() do c
        @test_throws ArgumentError submit(c, m; time_in_force = "day")
        @test_throws ArgumentError submit(c, m; type = "stop")
        @test_throws ArgumentError submit(c, m; type = "trailing_stop")
        @test_throws ArgumentError submit(c, m; type = "limit")
        @test_throws ArgumentError submit(c, m; type = "stop_limit", limit_price = 1)
        m.side = "hold"
        @test_throws ArgumentError submit(c, m)
    end
    @test length(log) == 0
end
