const _OPT_SYMBOL = "AAPL260117C00150000"

const _OPT_CONTRACT = Dict(
    "id"                  => "4f8a3d2c-0000-0000-0000-000000000001",
    "symbol"              => _OPT_SYMBOL,
    "name"                => "AAPL Jan 17 2026 \$150 Call",
    "status"              => "active",
    "tradable"            => true,
    "expiration_date"     => "2026-01-17",
    "root_symbol"         => "AAPL",
    "underlying_symbol"   => "AAPL",
    "underlying_asset_id" => "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415",
    "type"                => "call",
    "style"               => "american",
    "strike_price"        => "150.00",
    "multiplier"          => "100",
    "size"                => "100",
    "open_interest"       => "1500",
    "open_interest_date"  => "2026-04-10",
    "close_price"         => "12.50",
    "close_price_date"    => "2026-04-10",
)

@testset "options: list contracts (paginated)" begin
    call_count = Ref(0)
    handler, log = recording_handler() do req
        call_count[] += 1
        if occursin("page_token=PAGE2", HTTP.URI(req.target).query)
            return json_response(200, Dict(
                "option_contracts" => [_OPT_CONTRACT],
                "next_page_token"  => nothing,
            ))
        end
        return json_response(200, Dict(
            "option_contracts" => [_OPT_CONTRACT],
            "next_page_token"  => "PAGE2",
        ))
    end

    with_mock(handler) do client
        contracts = list_option_contracts(client;
                                          underlying_symbols = "AAPL",
                                          type = "call",
                                          strike_price_gte = 140,
                                          strike_price_lte = 160)
        @test length(contracts) == 2
        c = contracts[1]
        @test c isa OptionContract
        @test c.symbol == _OPT_SYMBOL
        @test c.underlying_symbol == "AAPL"
        @test c.type == "call"
        @test c.style == "american"
        @test c.strike_price == 150.0
        @test c.expiration_date == Date(2026, 1, 17)
        @test c.multiplier == 100.0
        @test c.open_interest == 1500.0
        @test c.open_interest_date == Date(2026, 4, 10)
    end

    @test call_count[] == 2
    q1 = log[1].query
    @test occursin("underlying_symbols=AAPL", q1)
    @test occursin("type=call", q1)
    @test occursin("strike_price_gte=140", q1)
    @test occursin("strike_price_lte=160", q1)
end

@testset "options: get single contract" begin
    handler, log = recording_handler() do _req
        return json_response(200, _OPT_CONTRACT)
    end

    with_mock(handler) do client
        c = get_option_contract(client, _OPT_SYMBOL)
        @test c.symbol == _OPT_SYMBOL
        @test c.strike_price == 150.0
    end

    @test log[1].path == "/options/contracts/$(_OPT_SYMBOL)"
end

@testset "options: historical bars auto-paginate" begin
    bar1 = Dict("t" => "2026-04-06T13:30:00Z", "o" => 10.0, "h" => 11.0,
                "l" => 9.5, "c" => 10.5, "v" => 500, "n" => 12, "vw" => 10.3)
    bar2 = Dict("t" => "2026-04-07T13:30:00Z", "o" => 10.5, "h" => 12.0,
                "l" => 10.4, "c" => 11.8, "v" => 700, "n" => 18, "vw" => 11.1)

    handler, log = recording_handler() do req
        q = HTTP.URI(req.target).query
        if occursin("page_token=P2", q)
            return json_response(200, Dict(
                "bars"            => Dict(_OPT_SYMBOL => [bar2]),
                "next_page_token" => nothing,
            ))
        end
        return json_response(200, Dict(
            "bars"            => Dict(_OPT_SYMBOL => [bar1]),
            "next_page_token" => "P2",
        ))
    end

    with_mock(handler) do client
        result = get_option_bars(client, _OPT_SYMBOL, "1Day";
                                 start = Date(2026, 4, 6), finish = Date(2026, 4, 7))
        @test haskey(result, _OPT_SYMBOL)
        @test length(result[_OPT_SYMBOL]) == 2
        @test result[_OPT_SYMBOL][1].c == 10.5
        @test result[_OPT_SYMBOL][2].c == 11.8
    end

    @test length(log) == 2
    @test log[1].path == "/options/bars"
    @test occursin("timeframe=1Day", log[1].query)
end

@testset "options: latest quote / trade / bar" begin
    latest_quote = Dict("t" => "2026-04-11T20:00:00Z", "bp" => 10.2,
                        "bs" => 5, "ap" => 10.4, "as" => 4, "bx" => "C", "ax" => "C")
    latest_trade = Dict("t" => "2026-04-11T20:00:00Z", "p" => 10.3,
                        "s" => 7, "x" => "C", "i" => 99)
    latest_bar = Dict("t" => "2026-04-11T20:00:00Z", "o" => 10.1, "h" => 10.5,
                      "l" => 10.0, "c" => 10.3, "v" => 1200, "n" => 30, "vw" => 10.25)

    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if uri.path == "/options/quotes/latest"
            return json_response(200, Dict("quotes" => Dict(_OPT_SYMBOL => latest_quote)))
        elseif uri.path == "/options/trades/latest"
            return json_response(200, Dict("trades" => Dict(_OPT_SYMBOL => latest_trade)))
        elseif uri.path == "/options/bars/latest"
            return json_response(200, Dict("bars"   => Dict(_OPT_SYMBOL => latest_bar)))
        end
        return plain_response(404, "nope")
    end

    with_mock(handler) do client
        q = get_latest_option_quote(client, _OPT_SYMBOL)
        @test haskey(q, _OPT_SYMBOL)
        @test q[_OPT_SYMBOL].bid_price == 10.2
        @test q[_OPT_SYMBOL].ask_price == 10.4

        t = get_latest_option_trade(client, _OPT_SYMBOL)
        @test t[_OPT_SYMBOL].price == 10.3
        @test t[_OPT_SYMBOL].id == 99

        b = get_latest_option_bar(client, _OPT_SYMBOL)
        @test b[_OPT_SYMBOL].c == 10.3
    end

    @test occursin("symbols=$(_OPT_SYMBOL)", log[1].query)
end

@testset "options: per-symbol snapshots with greeks" begin
    snapshot_payload = Dict(
        "latestQuote" => Dict("t" => "2026-04-11T20:00:00Z",
                              "bp" => 10.2, "bs" => 5,
                              "ap" => 10.4, "as" => 4,
                              "bx" => "C", "ax" => "C"),
        "latestTrade" => Dict("t" => "2026-04-11T20:00:00Z",
                              "p" => 10.3, "s" => 7, "x" => "C", "i" => 99),
        "minuteBar"   => Dict("t" => "2026-04-11T20:00:00Z",
                              "o" => 10.1, "h" => 10.5, "l" => 10.0,
                              "c" => 10.3, "v" => 1200),
        "dailyBar"    => Dict("t" => "2026-04-11T00:00:00Z",
                              "o" => 9.8, "h" => 10.6, "l" => 9.7,
                              "c" => 10.3, "v" => 12000),
        "prevDailyBar" => Dict("t" => "2026-04-10T00:00:00Z",
                               "o" => 9.5, "h" => 9.9, "l" => 9.3,
                               "c" => 9.8, "v" => 10000),
        "impliedVolatility" => 0.35,
        "greeks" => Dict("delta" => 0.55, "gamma" => 0.03,
                         "theta" => -0.07, "vega" => 0.11, "rho" => 0.04),
    )

    handler, log = recording_handler() do _req
        return json_response(200, Dict("snapshots" =>
            Dict(_OPT_SYMBOL => snapshot_payload)))
    end

    with_mock(handler) do client
        snaps = get_option_snapshots(client, _OPT_SYMBOL)
        @test haskey(snaps, _OPT_SYMBOL)
        s = snaps[_OPT_SYMBOL]
        @test s isa OptionSnapshot
        @test s.implied_volatility == 0.35
        @test s.greeks isa OptionGreeks
        @test s.greeks.delta == 0.55
        @test s.greeks.theta == -0.07
        @test s.latest_quote !== nothing
        @test s.latest_quote.bid_price == 10.2
        @test s.minute_bar.c == 10.3
        @test s.daily_bar.v == 12000
        @test s.prev_daily_bar.c == 9.8
    end

    @test log[1].path == "/options/snapshots"
    @test occursin("symbols=$(_OPT_SYMBOL)", log[1].query)
end

@testset "options: chain snapshot for underlying" begin
    sample = Dict(
        "latestQuote" => Dict("t" => "2026-04-11T20:00:00Z",
                              "bp" => 1.0, "bs" => 1, "ap" => 1.2, "as" => 1,
                              "bx" => "C", "ax" => "C"),
        "impliedVolatility" => 0.25,
        "greeks" => Dict("delta" => 0.4),
    )

    handler, log = recording_handler() do req
        return json_response(200, Dict(
            "snapshots" => Dict(
                "AAPL260117C00150000" => sample,
                "AAPL260117P00150000" => sample,
            ),
            "next_page_token" => nothing,
        ))
    end

    with_mock(handler) do client
        chain = get_option_chain_snapshot(client, "AAPL";
                                          type = "call",
                                          strike_price_gte = 140,
                                          strike_price_lte = 160,
                                          expiration_date = Date(2026, 1, 17))
        @test length(chain) == 2
        @test haskey(chain, "AAPL260117C00150000")
    end

    @test log[1].path == "/options/snapshots/AAPL"
    @test occursin("type=call", log[1].query)
    @test occursin("strike_price_gte=140", log[1].query)
    @test occursin("expiration_date=2026-01-17", log[1].query)
end

@testset "client: options_data_url derivation" begin
    c1 = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2",
                             "https://data.alpaca.markets/v2",
                             "K", "S")
    @test c1.options_data_url == "https://data.alpaca.markets/v1beta1"

    # Non-v2 base (mock) — reuse as-is
    c2 = Alpaca.AlpacaClient("http://127.0.0.1:1234",
                             "http://127.0.0.1:1234",
                             "K", "S")
    @test c2.options_data_url == "http://127.0.0.1:1234"
end
