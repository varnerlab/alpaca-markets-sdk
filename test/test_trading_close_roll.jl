const _N_SPREAD = [MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell"),
                   MyOptionLegModel(symbol = "SPY261218P00530000", side = "buy")]

# a filled order, parsed the way submit returns it -
function _n_filled_order(payload::Dict{String,Any}, filled_qty::String)::Order
    filled = merge(payload, Dict("status" => "filled", "filled_qty" => filled_qty))
    return Alpaca._parse_order(JSON3.read(JSON3.write(filled)))
end

@testset "close: spread reverses every leg in one order" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    with_mock(handler) do client
        close(client, _N_SPREAD; limit_price = 0.40)
    end
    body = JSON3.read(log[1].body)
    @test [l.side for l in body.legs] == ["buy", "sell"]
    @test [l.position_intent for l in body.legs] == ["buy_to_close", "sell_to_close"]
end

@testset "close: an unfilled or partly filled order must be canceled" begin
    for status in ("accepted", "partially_filled")
        payload = merge(_N_EQUITY_ORDER, Dict("status" => status))
        order = Alpaca._parse_order(JSON3.read(JSON3.write(payload)))
        handler, log = recording_handler() do _req
            return json_response(200, _N_EQUITY_ORDER)
        end
        with_mock(handler) do client
            err = try close(client, order); nothing catch e; e end
            @test err isa ArgumentError
            @test occursin("cancel", err.msg)
        end
        @test length(log) == 0
    end
end

@testset "close: a filled equity order is reversed with the filled quantity" begin
    payload = merge(_N_EQUITY_ORDER, Dict("status" => "filled", "filled_qty" => "7"))
    order = Alpaca._parse_order(JSON3.read(JSON3.write(payload)))
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        close(client, order)
    end
    body = JSON3.read(log[1].body)
    @test body.side == "sell"
    @test body.qty == "7"
end

@testset "close: one holding and all holdings" begin
    handler, log = recording_handler() do req
        if req.target == "/positions?cancel_orders=true"
            return json_response(207, [Dict("symbol" => "AAPL", "status" => 200)])
        end
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        @test close(client, "AAPL"; qty = 5) isa Order
        @test close(client; all = true, cancel_orders = true).symbol == ["AAPL"]
        @test_throws ArgumentError close(client)
    end
    @test log[1].method == "DELETE"
    @test log[1].target == "/positions/AAPL?qty=5"
    @test length(log) == 2
end

@testset "close: the private legacy helpers return the raw response body" begin
    handler, log = recording_handler() do req
        return HTTP.Response(200, "[{\"raw\":1}]")
    end
    with_mock(handler) do client
        @test Alpaca._cancel_all_orders(client) == "[{\"raw\":1}]"
        @test Alpaca._close_position(client, "AAPL") == "[{\"raw\":1}]"
        @test Alpaca._close_position(client, "AAPL"; percentage = 50) == "[{\"raw\":1}]"
        @test Alpaca._close_all_positions(client) == "[{\"raw\":1}]"
        @test Alpaca._close_all_positions(client; cancel_orders = true) == "[{\"raw\":1}]"
    end
    @test all(log[i].method == "DELETE" for i in 1:5)
    @test log[1].target == "/orders"
    @test log[2].target == "/positions/AAPL"
    @test log[3].target == "/positions/AAPL?percentage=50"
    @test log[4].target == "/positions?cancel_orders=false"
    @test log[5].target == "/positions?cancel_orders=true"
end

@testset "close: invalid orders raise before any request" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    with_mock(handler) do client
        one_leg = [MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell")]
        @test_throws ArgumentError close(client, one_leg)
        @test_throws ArgumentError close(client, _N_SPREAD)
        @test_throws ArgumentError close(client, one_leg[1]; type = "limit")
        eq = MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 1)
        @test_throws ArgumentError close(client, eq; type = "limit")
        bad = MyOptionLegModel(symbol = "X", side = "buy")
        bad.side = "long"
        @test_throws ArgumentError close(client, bad)
        @test_throws ArgumentError close(client, [bad, bad]; limit_price = 1.0)
    end
    @test length(log) == 0
end

@testset "close: equity and single option models reverse the side" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        close(client, MyEquityOrderModel(symbol = "AAPL", side = "buy", notional = 100))
        close(client, MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell", ratio = 2); qty = 3)
    end
    first_body = JSON3.read(log[1].body)
    @test first_body.side == "sell"
    @test first_body.notional == "100"
    second_body = JSON3.read(log[2].body)
    @test second_body.side == "buy"
    @test second_body.position_intent == "buy_to_close"
    @test second_body.qty == "6"
end

@testset "close: a filled multi-leg order is reversed with its units and ratios" begin
    payload = deepcopy(_N_MLEG_ORDER)
    payload["legs"][1]["ratio_qty"] = 2
    delete!(payload["legs"][2], "ratio_qty")
    payload["legs"][2]["qty"] = "3"
    payload["qty"] = "1"
    order = _n_filled_order(payload, "1.0")
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    with_mock(handler) do client
        close(client, order; type = "market")
    end
    body = JSON3.read(log[1].body)
    @test body.qty == "1"
    @test [l.ratio_qty for l in body.legs] == ["2", "3"]
    @test all(endswith(l.position_intent, "_to_close") for l in body.legs)
end

@testset "close: a filled single option order is reversed with the close intent" begin
    payload = merge(_N_EQUITY_ORDER, Dict("asset_class" => "us_option", "symbol" => "SPY261218P00540000", "side" => "sell"))
    order = _n_filled_order(payload, "2")
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        close(client, order)
    end
    body = JSON3.read(log[1].body)
    @test body.side == "buy"
    @test body.position_intent == "buy_to_close"
    @test body.qty == "2"
end

@testset "roll: vertical spread is one 4-leg order" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    far = [MyOptionLegModel(symbol = "SPY270115P00540000", side = "sell"),
           MyOptionLegModel(symbol = "SPY270115P00530000", side = "buy")]
    with_mock(handler) do client
        roll(client, _N_SPREAD, far; limit_price = -0.10)
        condor = vcat(_N_SPREAD, [MyOptionLegModel(symbol = "C1", side = "sell"), MyOptionLegModel(symbol = "C2", side = "buy")])
        @test_throws ArgumentError roll(client, condor, condor; limit_price = 0.0)
    end
    @test length(log) == 1
    body = JSON3.read(log[1].body)
    @test [l.position_intent for l in body.legs] == ["buy_to_close", "sell_to_close", "sell_to_open", "buy_to_open"]
end

@testset "roll: a single contract and a filled order" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    old = MyOptionLegModel(symbol = "SPY261218P00540000", side = "buy")
    new = MyOptionLegModel(symbol = "SPY270115P00540000", side = "buy")
    order = _n_filled_order(_N_MLEG_ORDER, "2")
    with_mock(handler) do client
        roll(client, old, new; limit_price = 0.15, client_order_id = "roll-1")
        roll(client, order, new; limit_price = 0.15)
        @test_throws ArgumentError roll(client, old, new)
    end
    @test length(log) == 2
    body = JSON3.read(log[1].body)
    @test [l.position_intent for l in body.legs] == ["sell_to_close", "buy_to_open"]
    @test body.client_order_id == "roll-1"
    @test body.qty == "1"
    body2 = JSON3.read(log[2].body)
    @test body2.qty == "2"
    @test length(body2.legs) == 3
end

@testset "roll: the legs of a filled order" begin
    order = _n_filled_order(_N_MLEG_ORDER, "1")
    legs = Alpaca._legs_from_order(order)
    @test legs isa Vector{MyOptionLegModel}
    @test length(legs) == 2
    @test legs[1].symbol == "AAPL261218C00200000"
    @test legs[1].side == "buy"
end

@testset "roll: a filled single option order closes that contract" begin
    payload = merge(_N_EQUITY_ORDER, Dict("asset_class" => "us_option", "symbol" => "SPY261218P00540000", "side" => "sell"))
    order = _n_filled_order(payload, "3")
    new = MyOptionLegModel(symbol = "SPY270115P00540000", side = "sell")
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    with_mock(handler) do client
        roll(client, order, new; limit_price = 0.10)
    end
    @test length(log) == 1
    body = JSON3.read(log[1].body)
    @test [l.position_intent for l in body.legs] == ["buy_to_close", "sell_to_open"]
    @test body.qty == "3"
end

@testset "roll: an equity order or an unfilled order is refused before any request" begin
    new = [MyOptionLegModel(symbol = "A", side = "sell"), MyOptionLegModel(symbol = "B", side = "buy")]
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    equity = _n_filled_order(_N_EQUITY_ORDER, "5")
    partial = merge(_N_MLEG_ORDER, Dict("status" => "partially_filled", "filled_qty" => "1.5"))
    partial_order = Alpaca._parse_order(JSON3.read(JSON3.write(partial)))
    with_mock(handler) do client
        @test_throws ArgumentError roll(client, equity, new; limit_price = 0.1)
        err = try roll(client, partial_order, new; limit_price = 0.1); nothing catch e; e end
        @test err isa ArgumentError
        @test occursin("cancel", err.msg)
    end
    @test length(log) == 0
end
