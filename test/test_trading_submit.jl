const _N_EQUITY_ORDER = Dict{String,Any}(
    "id" => "eq-0", "symbol" => "AAPL", "asset_class" => "us_equity", "side" => "buy",
    "type" => "market", "time_in_force" => "day", "qty" => "10", "filled_qty" => "0",
    "status" => "accepted",
    "created_at" => "2026-11-17T14:30:00.123456Z", "submitted_at" => "2026-11-17T14:30:00.234567Z")

@testset "models: invalid order models" begin
    @test_throws ArgumentError MyOptionLegModel(symbol = "X", side = "long")
    @test_throws ArgumentError MyOptionLegModel(symbol = "X", side = "buy", ratio = 0)
    @test_throws ArgumentError MyEquityOrderModel(symbol = "AAPL", side = "buy")
    @test_throws ArgumentError MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 1, notional = 100)
end

@testset "submit: vertical spread is one mleg order with open intents" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    legs = [MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell"),
            MyOptionLegModel(symbol = "SPY261218P00530000", side = "buy")]
    with_mock(handler) do client
        o = submit(client, legs; qty = 2, limit_price = -1.25)
        @test o isa Order
    end
    @test length(log) == 1
    body = JSON3.read(log[1].body)
    @test body.order_class == "mleg"
    @test body.qty == "2"
    @test body.limit_price == "-1.25"
    @test [l.position_intent for l in body.legs] == ["sell_to_open", "buy_to_open"]
    @test [l.side for l in body.legs] == ["sell", "buy"]
end

@testset "submit: more than 4 legs sends nothing" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    legs = [MyOptionLegModel(symbol = "S$(i)", side = "buy") for i in 1:5]
    with_mock(handler) do client
        @test_throws ArgumentError submit(client, legs; limit_price = 1.0)
    end
    @test length(log) == 0
end

@testset "submit: single option leg and equity" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        submit(client, MyOptionLegModel(symbol = "SPY261218C00600000", side = "buy", ratio = 2); qty = 3)
        submit(client, MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10); type = "limit", limit_price = 150.25)
    end
    b1 = JSON3.read(log[1].body)
    @test b1.qty == "6"
    @test b1.position_intent == "buy_to_open"
    b2 = JSON3.read(log[2].body)
    @test b2.qty == "10"
    @test b2.limit_price == "150.25"
    @test !haskey(b2, :position_intent)
end

@testset "cancel" begin
    handler, log = recording_handler() do req
        if req.target == "/orders"
            return json_response(207, [Dict("id" => "o1", "status" => 200)])
        end
        return HTTP.Response(204)
    end
    with_mock(handler) do client
        @test cancel(client, "ord-1") === nothing
        df = cancel(client; all = true)
        @test df.id == ["o1"]
        @test_throws ArgumentError cancel(client)
    end
    @test log[1].method == "DELETE"
    @test log[1].path == "/orders/ord-1"
end
