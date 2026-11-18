# Live paper tests of the verbs submit, close, and roll. They run only when ALPACA_LIVE_TESTS=1 (the _LIVE flag of
# test_integration.jl) and the market is open. The paper account is shared, so each testset closes only what it
# opened and has not already closed. It never calls close(client, symbol) without a qty.

using DataFrames

if _LIVE

    # _v_status: the status of the order with this id, read from the first row of the orders table -
    function _v_status(client::AlpacaClient, id::String)::String
        orders = api(client, MyOrderEndpointModel(id = id));
        return String(orders[1, :status]);
    end

    # _v_wait_filled: poll the order until it fills. On a terminal non-fill status or a timeout, the order is
    # cancelled (when still open) and the function throws -
    function _v_wait_filled(client::AlpacaClient, id::String; timeout_s::Real = 60, poll_s::Real = 1)::Nothing
        deadline = time() + timeout_s;
        while (time() < deadline)
            status = _v_status(client, id);
            if (status == "filled")
                return nothing;
            end
            if (status in ("canceled", "rejected", "expired"))
                error("order $id ended with status $status");
            end
            sleep(poll_s);
        end
        try
            cancel(client, id);
        catch
        end
        error("order $id did not fill within $(timeout_s) seconds");
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

    # _v_close_spread: close a spread with a market order, with a loud warning when the close fails -
    function _v_close_spread(client::AlpacaClient, legs::Vector{MyOptionLegModel})::Nothing
        try
            order = close(client, legs; type = "market", qty = 1);
            _v_wait_filled(client, order.id);
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

            # opened: the spread is held and has not been closed -
            opened = false;
            try
                open_order = submit(client, legs; type = "market");
                @test open_order isa Order
                _v_wait_filled(client, open_order.id);
                opened = true;
                @test _v_status(client, open_order.id) == "filled"

                close_order = close(client, legs; type = "market");
                @test close_order isa Order
                _v_wait_filled(client, close_order.id);
                @test _v_status(client, close_order.id) == "filled"
                opened = false;
            finally
                if (opened)
                    _v_close_spread(client, legs);
                end
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
            far = _v_pick_put_spread(client, today + Day(60), today + Day(80));
            @info "roll selections" near = [l.symbol for l in near] far = [l.symbol for l in far]

            # held: the legs the testset holds now. It starts as the near spread and becomes the far spread if the
            # roll order fills -
            opened = false;
            held = near;
            try
                open_order = submit(client, near; type = "market");
                _v_wait_filled(client, open_order.id);
                opened = true;

                roll_order = roll(client, near, far; limit_price = -0.01);
                @test roll_order isa Order
                @test _v_status(client, roll_order.id) != "rejected"

                # cancel the roll order after 5 seconds. A roll order that filled instead moved the position to
                # the far spread -
                sleep(5);
                if (_v_status(client, roll_order.id) == "filled")
                    held = far;
                else
                    cancel(client, roll_order);
                end
            finally
                if (opened)
                    _v_close_spread(client, held);
                end
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

            model = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
                options = [MyOptionLegModel(symbol = call_symbol, side = "sell")]);

            # shares_open and call_open: what this testset holds now -
            shares_open = false;
            call_open = false;
            try
                orders = Order[];
                try
                    orders = submit(client, model; type = "market");
                catch e
                    if (e isa AlpacaSequenceError && length(e.orders) > 0 && e.orders[1].status == "filled")
                        shares_open = true;
                    end
                    rethrow();
                end
                shares_open = true;
                @test length(orders) == 2
                @test orders[1].status == "filled"

                # the call is held once the option order fills -
                _v_wait_filled(client, orders[2].id);
                call_open = true;

                closed = Order[];
                try
                    closed = close(client, model; type = "market");
                catch e
                    if (e isa AlpacaSequenceError && length(e.orders) > 0 && e.orders[1].status == "filled")
                        call_open = false;
                    end
                    rethrow();
                end
                call_open = false;
                shares_open = false;
                @test closed[1].status == "filled"
            finally
                if (call_open)
                    try
                        close(client, model; type = "market");
                    catch e
                        @warn "covered call cleanup failed; check the paper account for these symbols by hand" symbols = [call_symbol, "F"] exception = e
                    end
                elseif (shares_open)
                    try
                        close(client, "F"; qty = 100);
                    catch e
                        @warn "share cleanup failed; check the paper account for these symbols by hand" symbols = ["F"] exception = e
                    end
                end
            end
        end
    end
else
    @info "skipping live verb tests (set ALPACA_LIVE_TESTS=1 to enable)"
end
