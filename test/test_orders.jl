const _ORDER_PAYLOAD = Dict(
    "id"                => "f00dcafe-0000-0000-0000-000000000001",
    "client_order_id"   => "client-1",
    "symbol"            => "AAPL",
    "asset_class"       => "us_equity",
    "side"              => "buy",
    "type"              => "limit",
    "time_in_force"     => "day",
    "qty"               => "10",
    "filled_qty"        => "0",
    "limit_price"       => "150.00",
    "stop_price"        => nothing,
    "filled_avg_price"  => nothing,
    "status"            => "accepted",
    "created_at"        => "2026-04-11T14:30:00Z",
    "submitted_at"      => "2026-04-11T14:30:00Z",
    "filled_at"         => nothing,
)

@testset "orders: submit market order body" begin
    handler, log = recording_handler() do _req
        return json_response(200, _ORDER_PAYLOAD)
    end

    with_mock(handler) do client
        o = submit_order(client, "AAPL", 10, "buy";
                         type = "market", time_in_force = "day",
                         client_order_id = "client-1")
        @test o isa Order
        @test o.id == _ORDER_PAYLOAD["id"]
        @test o.symbol == "AAPL"
        @test o.status == "accepted"
        @test o.qty == 10.0
        @test o.limit_price == 150.00  # from payload, not request
    end

    req = log[1]
    @test req.method == "POST"
    @test req.path == "/orders"
    body = JSON3.read(req.body)
    @test body.symbol == "AAPL"
    @test body.side == "buy"
    @test body.type == "market"
    @test body.time_in_force == "day"
    @test body.qty == "10"
    @test body.client_order_id == "client-1"
    @test !haskey(body, :notional)
    @test !haskey(body, :limit_price)
end

@testset "orders: limit order includes limit_price" begin
    handler, log = recording_handler() do _req
        return json_response(200, _ORDER_PAYLOAD)
    end

    with_mock(handler) do client
        submit_order(client, "AAPL", 5, "sell";
                     type = "limit", limit_price = 175.25)
    end

    body = JSON3.read(log[1].body)
    @test body.type == "limit"
    @test body.limit_price == "175.25"
    @test body.qty == "5"
end

@testset "orders: notional order omits qty" begin
    handler, log = recording_handler() do _req
        return json_response(200, _ORDER_PAYLOAD)
    end

    with_mock(handler) do client
        submit_order(client, "AAPL", nothing, "buy"; notional = 500)
    end

    body = JSON3.read(log[1].body)
    @test body.notional == "500"
    @test !haskey(body, :qty)
end

@testset "orders: validation" begin
    handler = function(_req)
        return json_response(200, _ORDER_PAYLOAD)
    end

    with_mock(handler) do client
        @test_throws ArgumentError submit_order(client, "AAPL", nothing, "buy")
        @test_throws ArgumentError submit_order(client, "AAPL", 10, "buy"; notional = 100)
    end
end

@testset "orders: list + get + cancel" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if req.method == "GET" && uri.path == "/orders"
            return json_response(200, [_ORDER_PAYLOAD])
        elseif req.method == "GET" && startswith(uri.path, "/orders/")
            return json_response(200, _ORDER_PAYLOAD)
        elseif req.method == "DELETE" && startswith(uri.path, "/orders/")
            return HTTP.Response(204)
        end
        return plain_response(404, "not mocked")
    end

    with_mock(handler) do client
        orders = list_orders(client; status = "open")
        @test length(orders) == 1
        @test orders[1].symbol == "AAPL"

        o = get_order(client, _ORDER_PAYLOAD["id"])
        @test o.id == _ORDER_PAYLOAD["id"]

        cancel_order(client, _ORDER_PAYLOAD["id"])
    end

    @test log[1].path == "/orders"
    @test occursin("status=open", log[1].query)
    @test log[2].path == "/orders/$(_ORDER_PAYLOAD["id"])"
    @test log[3].method == "DELETE"
end

const _MLEG_PAYLOAD = Dict(
    "id"              => "f00dcafe-0000-0000-0000-cafe0000cafe",
    "client_order_id" => "client-mleg-1",
    "asset_class"     => "us_option",
    "type"            => "limit",
    "time_in_force"   => "day",
    "order_class"     => "mleg",
    "qty"             => "1",
    "filled_qty"      => "0",
    "limit_price"     => "-2.00",
    "stop_price"      => nothing,
    "filled_avg_price"=> nothing,
    "status"          => "accepted",
    "created_at"      => "2026-04-11T14:30:00Z",
    "submitted_at"    => "2026-04-11T14:30:00Z",
    "filled_at"       => nothing,
    # NB: top-level `symbol` and `side` deliberately absent — that is the wire
    # shape Alpaca returns for an mleg parent.
    "legs" => [
        Dict(
            "id"              => "leg-short-put",
            "client_order_id" => "client-mleg-1-leg-1",
            "symbol"          => "SPY250620P00420000",
            "asset_class"     => "us_option",
            "side"            => "sell",
            "type"            => "limit",
            "time_in_force"   => "day",
            "order_class"     => "",
            "position_intent" => "sell_to_open",
            "qty"             => "1",
            "filled_qty"      => "0",
            "limit_price"     => nothing,
            "stop_price"      => nothing,
            "filled_avg_price"=> nothing,
            "status"          => "accepted",
            "created_at"      => "2026-04-11T14:30:00Z",
            "submitted_at"    => "2026-04-11T14:30:00Z",
            "filled_at"       => nothing,
        ),
        Dict(
            "id"              => "leg-long-put",
            "client_order_id" => "client-mleg-1-leg-2",
            "symbol"          => "SPY250620P00415000",
            "asset_class"     => "us_option",
            "side"            => "buy",
            "type"            => "limit",
            "time_in_force"   => "day",
            "order_class"     => "",
            "position_intent" => "buy_to_open",
            "qty"             => "1",
            "filled_qty"      => "0",
            "limit_price"     => nothing,
            "stop_price"      => nothing,
            "filled_avg_price"=> nothing,
            "status"          => "accepted",
            "created_at"      => "2026-04-11T14:30:00Z",
            "submitted_at"    => "2026-04-11T14:30:00Z",
            "filled_at"       => nothing,
        ),
    ],
)

@testset "orders: parse mleg parent with two child legs" begin
    with_mock(_ -> json_response(200, _MLEG_PAYLOAD)) do client
        o = get_order(client, _MLEG_PAYLOAD["id"])
        @test o isa Order
        @test o.order_class == "mleg"
        @test o.symbol === nothing
        @test o.side === nothing
        @test o.position_intent === nothing
        @test o.legs !== nothing
        @test length(o.legs) == 2

        short_leg = o.legs[1]
        @test short_leg.symbol == "SPY250620P00420000"
        @test short_leg.side == "sell"
        @test short_leg.position_intent == "sell_to_open"
        @test short_leg.order_class == ""
        @test short_leg.legs === nothing
        @test short_leg.qty == 1.0

        long_leg = o.legs[2]
        @test long_leg.symbol == "SPY250620P00415000"
        @test long_leg.side == "buy"
        @test long_leg.position_intent == "buy_to_open"
    end
end

@testset "orders: simple equity parsing regression" begin
    with_mock(_ -> json_response(200, _ORDER_PAYLOAD)) do client
        o = get_order(client, _ORDER_PAYLOAD["id"])
        @test o.symbol == "AAPL"
        @test o.side == "buy"
        @test o.order_class == ""
        @test o.position_intent === nothing
        @test o.legs === nothing
    end
end

@testset "orders: OrderLeg construction" begin
    leg = OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open")
    @test leg.symbol == "SPY250620P00420000"
    @test leg.ratio_qty == 1
    @test leg.side == "sell"
    @test leg.position_intent == "sell_to_open"
end

@testset "orders: submit_multileg_order body shape" begin
    handler, log = recording_handler() do _req
        return json_response(200, _MLEG_PAYLOAD)
    end

    legs = [
        OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
        OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
    ]

    with_mock(handler) do client
        o = submit_multileg_order(client, legs;
                                  type = "limit",
                                  limit_price = -2.00,
                                  qty = 1,
                                  client_order_id = "client-mleg-1")
        @test o isa Order
        @test o.order_class == "mleg"
        @test length(o.legs) == 2
    end

    req = log[1]
    @test req.method == "POST"
    @test req.path == "/orders"

    body = JSON3.read(req.body)
    @test body.order_class == "mleg"
    @test body.qty == "1"
    @test body.type == "limit"
    @test body.time_in_force == "day"
    @test body.limit_price == "-2.0"
    @test body.client_order_id == "client-mleg-1"
    @test length(body.legs) == 2

    leg1 = body.legs[1]
    @test leg1.symbol          == "SPY250620P00420000"
    @test leg1.ratio_qty       == "1"
    @test leg1.side            == "sell"
    @test leg1.position_intent == "sell_to_open"

    leg2 = body.legs[2]
    @test leg2.symbol          == "SPY250620P00415000"
    @test leg2.ratio_qty       == "1"
    @test leg2.side            == "buy"
    @test leg2.position_intent == "buy_to_open"
end

@testset "orders: submit_multileg_order market order omits limit_price" begin
    handler, log = recording_handler() do _req
        return json_response(200, _MLEG_PAYLOAD)
    end

    legs = [
        OrderLeg("SPY250620P00420000", 1, "buy",  "buy_to_close"),
        OrderLeg("SPY250620P00415000", 1, "sell", "sell_to_close"),
    ]

    with_mock(handler) do client
        o = submit_multileg_order(client, legs; type = "market", qty = 2)
        @test o isa Order
    end

    body = JSON3.read(log[1].body)
    @test body.type == "market"
    @test body.qty  == "2"
    @test !haskey(body, :limit_price)
    @test !haskey(body, :client_order_id)
end

@testset "orders: submit_multileg_order rejects bad input before HTTP" begin
    # Handler intentionally returns 500 so any HTTP call would fail loudly;
    # validation should short-circuit before we get there.
    handler = _ -> plain_response(500, "should not reach server")

    with_mock(handler) do client
        @test_throws ArgumentError submit_multileg_order(
            client,
            [OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open")];
            type = "limit", limit_price = -2.0,
        )

        legs = [
            OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
            OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
        ]
        @test_throws ArgumentError submit_multileg_order(client, legs; type = "limit")
    end
end

@testset "orders: _validate_mleg" begin
    good = [
        OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
        OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
    ]

    # Happy path: 2 legs, type=limit, limit_price set
    @test Alpaca._validate_mleg(good, "limit", -2.0) === nothing

    # Happy path: 2 legs, type=market, no limit_price
    @test Alpaca._validate_mleg(good, "market", nothing) === nothing

    # Leg count: 1 leg
    @test_throws ArgumentError Alpaca._validate_mleg(good[1:1], "limit", -2.0)

    # Leg count: 4 legs is the upper bound (iron condor) — must accept
    iron_condor = vcat(good, good)
    @test length(iron_condor) == 4
    @test Alpaca._validate_mleg(iron_condor, "limit", -2.0) === nothing

    # Leg count: 5 legs (build by duplication)
    too_many = vcat(good, good, good[1:1])
    @test length(too_many) == 5
    @test_throws ArgumentError Alpaca._validate_mleg(too_many, "limit", -2.0)

    # Limit without price
    @test_throws ArgumentError Alpaca._validate_mleg(good, "limit", nothing)

    # Bad type
    @test_throws ArgumentError Alpaca._validate_mleg(good, "stop", nothing)

    # Bad side
    bad_side = [
        OrderLeg("SPY250620P00420000", 1, "shrt", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_side, "limit", -2.0)

    # Bad position_intent
    bad_intent = [
        OrderLeg("SPY250620P00420000", 1, "sell", "open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_intent, "limit", -2.0)

    # ratio_qty < 1
    bad_ratio = [
        OrderLeg("SPY250620P00420000", 0, "sell", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_ratio, "limit", -2.0)

    # Empty symbol
    empty_sym = [
        OrderLeg("", 1, "sell", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(empty_sym, "limit", -2.0)
end

@testset "orders: list_orders returns mleg parent with child legs" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if req.method == "GET" && uri.path == "/orders"
            return json_response(200, [_ORDER_PAYLOAD, _MLEG_PAYLOAD])
        end
        return plain_response(404, "not mocked")
    end

    with_mock(handler) do client
        orders = list_orders(client; status = "open")
        @test length(orders) == 2

        simple = orders[1]
        @test simple.symbol == "AAPL"
        @test simple.order_class == ""
        @test simple.legs === nothing

        mleg = orders[2]
        @test mleg.order_class == "mleg"
        @test mleg.symbol === nothing
        @test mleg.legs !== nothing
        @test length(mleg.legs) == 2
        @test mleg.legs[1].symbol == "SPY250620P00420000"
    end

    @test occursin("status=open", log[1].query)
end
