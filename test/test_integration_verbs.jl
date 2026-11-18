# Live paper tests of the verbs submit, close, and roll. They run only when ALPACA_LIVE_TESTS=1 (the _LIVE flag of
# test_integration.jl) and the market is open. The paper account is shared, so each testset closes only what it
# opened and has not already closed. It never calls close(client, symbol) without a qty.

using DataFrames

if _LIVE

    # _v_read: the status and the filled quantity of the order with this id, from the first row of the orders table -
    function _v_read(client::AlpacaClient, id::String)::Tuple{String,Float64}
        orders = api(client, MyOrderEndpointModel(id = id));
        return (String(orders[1, :status]), Float64(coalesce(orders[1, :filled_qty], 0.0)));
    end

    # _v_status: the status of the order with this id -
    function _v_status(client::AlpacaClient, id::String)::String
        return _v_read(client, id)[1];
    end

    # _v_wait_final: poll the order until it has a final status, or until the timeout. It returns the last status read -
    function _v_wait_final(client::AlpacaClient, id::String; timeout_s::Real = 30, poll_s::Real = 1)::String
        deadline = time() + timeout_s;
        status = _v_status(client, id);
        while (!(status in ("filled", "canceled", "expired", "rejected", "done_for_day")) && time() < deadline)
            sleep(poll_s);
            status = _v_status(client, id);
        end
        return status;
    end

    # _v_wait_filled: poll the order until it fills. On a timeout the order is cancelled, and the status is read again,
    # because the order may have filled while the cancel was sent. The function returns when the order is filled,
    # and it throws otherwise -
    function _v_wait_filled(client::AlpacaClient, id::String; timeout_s::Real = 60, poll_s::Real = 1)::Nothing
        deadline = time() + timeout_s;
        status = _v_status(client, id);
        while (status != "filled" && time() < deadline)
            if (status in ("canceled", "rejected", "expired"))
                error("order $id ended with status $status");
            end
            sleep(poll_s);
            status = _v_status(client, id);
        end
        if (status == "filled")
            return nothing;
        end
        try
            cancel(client, id);
        catch
        end
        status = _v_wait_final(client, id; timeout_s = 20);
        if (status == "filled")
            return nothing;
        end
        error("order $id did not fill within $(timeout_s) seconds, and ended with status $status");
    end

    # _v_settle: cancel the order when it is not final, wait for a final status, and return the filled quantity.
    # An empty id is an order that was never sent, so the filled quantity is 0 -
    function _v_settle(client::AlpacaClient, id::String)::Float64
        if (id == "")
            return 0.0;
        end
        (status, filled) = _v_read(client, id);
        if (!(status in ("filled", "canceled", "expired", "rejected", "done_for_day")))
            try
                cancel(client, id);
            catch
            end
            _v_wait_final(client, id);
            (status, filled) = _v_read(client, id);
        end
        return filled;
    end

    # _v_occ_strike: the strike of an OCC symbol, from its last 8 digits -
    function _v_occ_strike(symbol::AbstractString)::Float64
        return parse(Int, symbol[end-7:end]) / 1000;
    end

    # _v_occ_expiry: the expiration date of an OCC symbol with a root of this length -
    function _v_occ_expiry(symbol::AbstractString, root::AbstractString)::Date
        yymmdd = symbol[length(root)+1 : length(root)+6];
        return Date("20" * yymmdd, dateformat"yyyymmdd");
    end

    # _v_pick_put_spread: the short put (delta closest to -0.30) and the long put 5 dollars lower, on the nearest
    # expiration in the window -
    function _v_pick_put_spread(client::AlpacaClient, window_start::Date, window_end::Date)::Vector{MyOptionLegModel}
        chain = api(client, MyOptionChainEndpointModel(underlying = "SPY", type = "put",
            expiration_date_gte = window_start, expiration_date_lte = window_end));
        @test nrow(chain) > 0;

        # the nearest expiration in the window -
        nearest = minimum([_v_occ_expiry(s, "SPY") for s in chain.symbol]);
        puts = String[];
        for s in chain.symbol
            if (_v_occ_expiry(s, "SPY") == nearest)
                push!(puts, s);
            end
        end

        # the short leg: the put with a delta closest to -0.30 -
        short_symbol = "";
        best = Inf;
        for i in 1:nrow(chain)
            delta = chain[i, :delta];
            if (!ismissing(delta) && chain[i, :symbol] in puts && abs(delta + 0.30) < best)
                best = abs(delta + 0.30);
                short_symbol = chain[i, :symbol];
            end
        end
        @test short_symbol != "";

        # the long leg: the put closest to 5 dollars below the short strike -
        long_symbol = "";
        best = Inf;
        target = _v_occ_strike(short_symbol) - 5.0;
        for s in puts
            if (abs(_v_occ_strike(s) - target) < best)
                best = abs(_v_occ_strike(s) - target);
                long_symbol = s;
            end
        end
        return [MyOptionLegModel(symbol = short_symbol, side = "sell"), MyOptionLegModel(symbol = long_symbol, side = "buy")];
    end

    # _v_cleanup_spread: close the part of a spread that this testset still holds. The held quantity is the filled
    # quantity of the opening order minus the filled quantity of the reversing order, after both orders are final.
    # A failure is a loud warning that names the symbols -
    function _v_cleanup_spread(client::AlpacaClient, legs::Vector{MyOptionLegModel}, opening_id::String, reversing_id::String)::Nothing
        try
            held = _v_settle(client, opening_id) - _v_settle(client, reversing_id);
            if (held > 0)
                order = close(client, legs; type = "market", qty = Int(round(held)));
                _v_wait_filled(client, order.id);
            end
        catch e
            @warn "spread cleanup failed; check the paper account for these symbols by hand" symbols = [l.symbol for l in legs] exception = e
        end
        return nothing;
    end

    creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apidata.toml"));

    @testset "verbs: vertical spread (live paper API)" begin
        client = load_client(creds_path);
        if (api(client, MyClockEndpointModel())[1, :is_open] != true)
            @info "skipping live verb tests (market closed)"
        else
            today = Date(api(client, MyClockEndpointModel())[1, :timestamp]);
            legs = _v_pick_put_spread(client, today + Day(30), today + Day(45));
            @info "vertical spread selections" short = legs[1].symbol long = legs[2].symbol

            # opening_id and reversing_id: the orders this testset sent. The cleanup reads their filled quantities
            # from Alpaca, so a partial fill or a fill after a timeout is counted -
            opening_id = "";
            reversing_id = "";
            try
                open_order = submit(client, legs; type = "market");
                opening_id = open_order.id;
                @test open_order isa Order
                _v_wait_filled(client, opening_id);
                @test _v_status(client, opening_id) == "filled"

                close_order = close(client, legs; type = "market");
                reversing_id = close_order.id;
                @test close_order isa Order
                _v_wait_filled(client, reversing_id);
                @test _v_status(client, reversing_id) == "filled"
            finally
                _v_cleanup_spread(client, legs, opening_id, reversing_id);
            end
        end
    end

    @testset "verbs: roll (live paper API)" begin
        client = load_client(creds_path);
        if (api(client, MyClockEndpointModel())[1, :is_open] != true)
            @info "skipping live verb tests (market closed)"
        else
            today = Date(api(client, MyClockEndpointModel())[1, :timestamp]);
            near = _v_pick_put_spread(client, today + Day(30), today + Day(45));

            # the far spread: the first listed SPY expiration 25 to 35 days after the near expiration -
            near_expiry = _v_occ_expiry(near[1].symbol, "SPY");
            far = _v_pick_put_spread(client, near_expiry + Day(25), near_expiry + Day(35));
            @info "roll selections" near = [l.symbol for l in near] far = [l.symbol for l in far]

            # opening_id and roll_id: the orders this testset sent. A filled roll order closed that quantity of the
            # near spread and opened it in the far spread -
            opening_id = "";
            roll_id = "";
            try
                open_order = submit(client, near; type = "market");
                opening_id = open_order.id;
                _v_wait_filled(client, opening_id);

                roll_order = roll(client, near, far; limit_price = -0.01);
                roll_id = roll_order.id;
                @test roll_order isa Order
                @test _v_status(client, roll_id) != "rejected"

                # cancel the roll order after 5 seconds. A cancel that fails is not an error, because the roll
                # order may have filled, and the cleanup reads the final status -
                sleep(5);
                try
                    cancel(client, roll_order);
                catch
                end
            finally
                # wait until the roll order is final, so that it no longer reserves the near legs. Then close what
                # is held: the near spread less the rolled quantity, and the far spread, as the roll order filled -
                try
                    _v_settle(client, roll_id);
                catch e
                    @warn "roll order could not be settled; check the paper account and open orders for these symbols by hand" symbols = [l.symbol for l in vcat(near, far)] exception = e
                end
                _v_cleanup_spread(client, near, opening_id, roll_id);
                _v_cleanup_spread(client, far, roll_id, "");
            end
        end
    end

    @testset "verbs: covered call (live paper API)" begin
        client = load_client(creds_path);
        if (api(client, MyClockEndpointModel())[1, :is_open] != true)
            @info "skipping live verb tests (market closed)"
        else
            today = Date(api(client, MyClockEndpointModel())[1, :timestamp]);

            # the first out-of-the-money F call, 20 to 45 days out -
            price = api(client, MyStockLatestTradeEndpointModel(symbol = "F"))[1, :price];
            chain = api(client, MyOptionChainEndpointModel(underlying = "F", type = "call",
                expiration_date_gte = today + Day(20), expiration_date_lte = today + Day(45), strike_price_gte = price));
            @test nrow(chain) > 0;
            call_symbol = "";
            best_expiry = Date(9999, 1, 1);
            best_strike = Inf;
            for s in chain.symbol
                expiry = _v_occ_expiry(s, "F");
                strike = _v_occ_strike(s);
                if (strike > price && (expiry < best_expiry || (expiry == best_expiry && strike < best_strike)))
                    best_expiry = expiry;
                    best_strike = strike;
                    call_symbol = s;
                end
            end
            @test call_symbol != "";
            @info "covered call selection" call = call_symbol price = price

            leg = MyOptionLegModel(symbol = call_symbol, side = "sell");
            model = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100), options = [leg]);

            # the ids of the four orders this testset can send: buy shares, sell the call, buy back the call, and
            # sell shares. An empty id is an order that was not sent -
            buy_id = "";
            sell_call_id = "";
            buy_call_id = "";
            sell_id = "";
            try
                orders = Order[];
                try
                    orders = submit(client, model; type = "market");
                catch e
                    if (e isa AlpacaSequenceError && length(e.orders) > 0)
                        buy_id = e.orders[1].id;
                    end
                    rethrow();
                end
                buy_id = orders[1].id;
                sell_call_id = orders[2].id;
                @test length(orders) == 2
                @test orders[1].status == "filled"
                _v_wait_filled(client, sell_call_id);

                closed = Order[];
                try
                    closed = close(client, model; type = "market");
                catch e
                    if (e isa AlpacaSequenceError && length(e.orders) > 0)
                        buy_call_id = e.orders[1].id;
                    end
                    rethrow();
                end
                buy_call_id = closed[1].id;
                sell_id = closed[2].id;
                @test closed[1].status == "filled"
            finally
                # the shares and calls still held are the filled quantities of the opening orders less the filled
                # quantities of the reversing orders. The calls are bought back before the shares are sold, so that
                # no call is left uncovered -
                try
                    calls_held = _v_settle(client, sell_call_id) - _v_settle(client, buy_call_id);
                    shares_held = _v_settle(client, buy_id) - _v_settle(client, sell_id);
                    if (calls_held > 0)
                        order = close(client, leg; type = "market", qty = Int(round(calls_held)));
                        _v_wait_filled(client, order.id);
                    end
                    if (shares_held > 0)
                        order = close(client, "F"; qty = shares_held);
                        _v_wait_filled(client, order.id);
                    end
                catch e
                    @warn "covered call cleanup failed; check the paper account for these symbols by hand" symbols = [call_symbol, "F"] exception = e
                end
            end
        end
    end
else
    @info "skipping live verb tests (set ALPACA_LIVE_TESTS=1 to enable)"
end
