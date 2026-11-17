# the mock for the mixed sequence: POST /orders routes on the body, GET /orders/<id> reports `status` for the order named in the path -
function run_mixed(f::Function; status::String, reject_options::Bool = false)::RequestLog
    equity = merge(_N_EQUITY_ORDER, Dict("id" => "eq-1", "symbol" => "F", "qty" => "100"))
    option = merge(_N_MLEG_ORDER, Dict("id" => "op-1"))
    log = RequestLog()
    handler = function (req::HTTP.Request)
        # copy the body once, record the request, and route on the copy -
        body = String(copy(req.body))
        uri = HTTP.URI(req.target)
        headers = Dict{String,String}(String(k) => String(v) for (k, v) in req.headers)
        push!(log.entries, RecordedRequest(String(req.method), String(req.target), String(uri.path), String(uri.query), headers, body))
        if (req.method == "POST")
            if (get(JSON3.read(body), :symbol, "") == "F")
                return json_response(200, equity)
            end
            if (reject_options)
                return json_response(422, Dict("code" => 42210000, "message" => "rejected"))
            end
            return json_response(200, option)
        end
        if (req.method == "GET")
            payload = equity
            if (endswith(uri.path, "/op-1"))
                payload = option
            end
            return json_response(200, merge(payload, Dict("status" => status)))
        end
        return HTTP.Response(204)
    end
    with_mock(handler) do client
        f(client)
    end
    return log
end

const _N_COVERED_CALL = MyMixedOrderModel(
    equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
    options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])

@testset "mixed: coverage check" begin
    short_shares = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 50),
                                     options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(short_shares, 1)
    @test_throws ArgumentError Alpaca._check_coverage(_N_COVERED_CALL, 2)
    by_notional = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", notional = 1200),
                                    options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(by_notional, 1)
    selling = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "sell", qty = 100),
                                options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(selling, 1)
    married_put = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
                                    options = [MyOptionLegModel(symbol = "F261218P00010000", side = "buy")])
    @test Alpaca._check_coverage(married_put, 1) === nothing
end

@testset "mixed: submit sends shares, waits, then the call" begin
    # status Ref returns "filled" for eq-1
    log = run_mixed(status = "filled") do client
        orders = submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 1.0, poll_interval = 0.01)
        @test [o.id for o in orders] == ["eq-1", "op-1"]
    end
    posts = [r for r in log.entries if r.method == "POST"]
    @test JSON3.read(posts[1].body).symbol == "F"
    @test JSON3.read(posts[2].body).position_intent == "sell_to_open"
end

@testset "mixed: unfilled shares are canceled and no call is sold" begin
    log = run_mixed(status = "new") do client
        err = try submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 0.05, poll_interval = 0.01); nothing catch e; e end
        @test err isa AlpacaSequenceError
        @test err.orders[1].id == "eq-1"
    end
    @test count(r -> r.method == "POST", log.entries) == 1
    @test any(r -> r.method == "DELETE" && r.path == "/orders/eq-1", log.entries)
end

@testset "mixed: a rejected call keeps the filled shares in the error" begin
    log = run_mixed(status = "filled", reject_options = true) do client
        err = try submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 1.0, poll_interval = 0.01); nothing catch e; e end
        @test err isa AlpacaSequenceError
        @test err.orders[1].id == "eq-1"
        @test err.cause isa AlpacaError
    end
end

@testset "mixed: close buys back the call before selling the shares" begin
    log = run_mixed(status = "filled") do client
        orders = close(client, _N_COVERED_CALL; limit_price = 0.10, fill_timeout = 1.0, poll_interval = 0.01)
        @test [o.id for o in orders] == ["op-1", "eq-1"]
    end
    posts = [r for r in log.entries if r.method == "POST"]
    @test JSON3.read(posts[1].body).position_intent == "buy_to_close"
    @test JSON3.read(posts[2].body).side == "sell"
end

@testset "mixed: an invalid option order sends nothing, not even the shares" begin
    log = run_mixed(status = "filled") do client
        @test_throws ArgumentError submit(client, _N_COVERED_CALL; fill_timeout = 1.0, poll_interval = 0.01)
    end
    @test isempty(log.entries)
end

@testset "mixed: the sequence error prints each order" begin
    order = Alpaca._parse_order(JSON3.read(JSON3.write(merge(_N_EQUITY_ORDER, Dict("id" => "eq-1")))))
    text = sprint(showerror, AlpacaSequenceError("stopped", [order], nothing))
    @test occursin("eq-1", text) && occursin("accepted", text)
end
