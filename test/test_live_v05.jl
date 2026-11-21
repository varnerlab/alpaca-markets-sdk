# Live tests of the 0.5.0 endpoints against the real Alpaca paper API. Skipped unless ALPACA_LIVE_TESTS=1.
# The write tests (watchlists, account settings, one crypto order) also need ALPACA_LIVE_WRITE_TESTS=1.
#
#   ALPACA_LIVE_TESTS=1 ALPACA_LIVE_WRITE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()'
#
# An endpoint that the paper account's subscription refuses (HTTP 403) is recorded as a skip with Alpaca's
# message. Any other HTTP error is a failure. The tests never print the credentials.

"""
    _live_read(client::AlpacaClient, model) -> Tuple{Any,String}

Send one read request. Returns `(result, "")` when Alpaca answers, and `(nothing, message)` when Alpaca refuses
the request with HTTP 403. Any other error is thrown.
"""
function _live_read(client::AlpacaClient, model)::Tuple{Any,String}
    try
        return (api(client, model), "");
    catch error
        if (error isa AlpacaError && error.status == 403)
            return (nothing, error.message);
        end
        rethrow(error);
    end
end

if get(ENV, "ALPACA_LIVE_TESTS", "0") == "1"

    @testset "live read endpoints (0.5.0)" begin
        creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apidata.toml"))
        client = load_client(creds_path)

        # the columns that every typed price table has -
        bar_columns = ["timestamp", "symbol", "open", "high", "low", "close", "volume", "trade_count", "vwap"]
        quote_columns = ["timestamp", "symbol", "bid_price", "bid_size", "ask_price", "ask_size"]
        trade_columns = ["timestamp", "symbol", "price", "size"]
        start_time = DateTime(2026, 11, 16)
        finish_time = DateTime(2026, 11, 20)

        # api follows next_page_token to the last page, so the quote and trade requests use a window of one minute -
        window_start = DateTime(2026, 11, 20, 15, 0, 0)
        window_finish = DateTime(2026, 11, 20, 15, 1, 0)

        # each case: a label, a model, and the columns that the table must have -
        cases = Any[
            ("stock latest bars", MyStockLatestBarsEndpointModel(symbols = ["AAPL"]), bar_columns),
            ("stock latest quotes", MyStockLatestQuotesEndpointModel(symbols = ["AAPL"]), quote_columns),
            ("stock latest trades", MyStockLatestTradesEndpointModel(symbols = ["AAPL"]), trade_columns),
            ("stock auctions", MyStockAuctionsEndpointModel(symbols = ["AAPL"], start = start_time, finish = finish_time, limit = 5), String[]),
            ("stock conditions", MyStockConditionsEndpointModel(ticktype = "trade", tape = "A"), String[]),
            ("stock exchanges", MyStockExchangesEndpointModel(), String[]),
            ("global stock bars", MyGlobalStockBarsEndpointModel(feed = "xetr", symbols = ["SAP:XETR"], timeframe = "1Day", start = start_time, finish = finish_time, page_size = 5), bar_columns),
            ("global stock quotes", MyGlobalStockQuotesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"], start = window_start, finish = window_finish, page_size = 5), String[]),
            ("global stock trades", MyGlobalStockTradesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"], start = window_start, finish = window_finish, page_size = 5), String[]),
            ("global stock latest bars", MyGlobalStockLatestBarsEndpointModel(feed = "xetr", symbols = ["SAP:XETR"]), bar_columns),
            ("global stock latest quotes", MyGlobalStockLatestQuotesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"]), String[]),
            ("global stock latest trades", MyGlobalStockLatestTradesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"]), String[]),
            ("global stock snapshots", MyGlobalStockSnapshotsEndpointModel(feed = "xetr", symbols = ["SAP:XETR"]), String[]),
            ("option exchanges", MyOptionExchangesEndpointModel(), String[]),
            ("option conditions", MyOptionConditionsEndpointModel(ticktype = "trade"), String[]),
            ("crypto bars", MyCryptoBarsEndpointModel(symbols = ["BTC/USD"], timeframe = "1Hour", start = start_time, finish = finish_time, limit = 5), bar_columns),
            ("crypto quotes", MyCryptoQuotesEndpointModel(symbols = ["BTC/USD"], start = window_start, finish = window_finish, limit = 5), quote_columns),
            ("crypto trades", MyCryptoTradesEndpointModel(symbols = ["BTC/USD"], start = window_start, finish = window_finish, limit = 5), trade_columns),
            ("crypto latest bars", MyCryptoLatestBarsEndpointModel(symbols = ["BTC/USD"]), bar_columns),
            ("crypto latest quotes", MyCryptoLatestQuotesEndpointModel(symbols = ["BTC/USD"]), quote_columns),
            ("crypto latest trades", MyCryptoLatestTradesEndpointModel(symbols = ["BTC/USD"]), trade_columns),
            ("crypto latest orderbooks", MyCryptoLatestOrderbooksEndpointModel(symbols = ["BTC/USD"]), String[]),
            ("crypto snapshots", MyCryptoSnapshotsEndpointModel(symbols = ["BTC/USD"]), String[]),
            ("account configurations", MyAccountConfigurationsEndpointModel(), ["trade_confirm_email"]),
            ("account activities", MyAccountActivitiesEndpointModel(page_size = 3), String[]),
            ("portfolio history", MyPortfolioHistoryEndpointModel(period = "1W", timeframe = "1D"), String[]),
            ("market calendar", MyMarketCalendarEndpointModel(market = "NYSE", start = Date(2026, 11, 16), finish = Date(2026, 11, 20)), String[]),
            ("market clocks", MyMarketClocksEndpointModel(markets = ["NYSE", "XLON"]), String[]),
            ("watchlists", MyWatchlistsEndpointModel(), String[]),
            ("news", MyNewsEndpointModel(symbols = ["AAPL"], limit = 3), String[]),
            ("most actives", MyMostActivesEndpointModel(by = "volume", top = 3), String[]),
            ("movers", MyMoversEndpointModel(market_type = "stocks", top = 3), String[]),
            ("corporate actions", MyCorporateActionsEndpointModel(symbols = ["AAPL"], start = Date(2026, 1, 1), finish = Date(2026, 6, 30), limit = 5), String[]),
            ("logo", MyLogoEndpointModel(symbol = "AAPL"), String[]),
            ("logo of a crypto pair", MyLogoEndpointModel(symbol = "BTC/USD"), String[]),
            ("fixed income latest prices", MyFixedIncomeLatestPricesEndpointModel(isins = ["US912828ZT58"]), String[]),
            ("fixed income latest quotes", MyFixedIncomeLatestQuotesEndpointModel(isins = ["US912828ZT58"]), String[]),
        ]

        for case in cases
            label = case[1];
            model = case[2];
            columns = case[3];
            result, message = _live_read(client, model);
            if (result === nothing)
                # the subscription refuses this endpoint: record the skip with Alpaca's message -
                @info "live skip (HTTP 403)" endpoint = label message = message
                @test_skip false
            elseif (model isa MyLogoEndpointModel)
                # the logo handler returns the PNG bytes, not a DataFrame -
                @test result isa Vector{UInt8}
            else
                @test result isa DataFrame
                for column in columns
                    @test column in names(result)
                end
            end
        end
    end

    if get(ENV, "ALPACA_LIVE_WRITE_TESTS", "") == "1"

        @testset "live write endpoints (0.5.0)" begin
            creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apidata.toml"))
            client = load_client(creds_path)

            # the watchlist and the order that this testset creates, so the finally block can clean them up -
            watchlist_id = nothing
            order_id = nothing
            try

                # watchlist: create, add a symbol, remove the symbol, rename, delete -
                name = "sdk-live-" * Dates.format(now(UTC), "yyyymmddHHMMSS")
                created = api(client, MyCreateWatchlistEndpointModel(name = name, symbols = ["AAPL"]))
                @test created isa DataFrame
                @test "watchlist_id" in names(created)
                @test size(created, 1) == 1
                watchlist_id = created.watchlist_id[1]
                @test created.watchlist_name[1] == name

                added = api(client, MyAddWatchlistAssetEndpointModel(id = watchlist_id, symbol = "MSFT"))
                @test sort(string.(added.symbol)) == ["AAPL", "MSFT"]

                removed = api(client, MyRemoveWatchlistAssetEndpointModel(id = watchlist_id, symbol = "MSFT"))
                @test string.(removed.symbol) == ["AAPL"]

                renamed_to = name * "-renamed"
                # Alpaca replaces the whole watchlist on an update, so the update lists the symbols that stay -
                renamed = api(client, MyUpdateWatchlistEndpointModel(id = watchlist_id, new_name = renamed_to, symbols = ["AAPL"]))
                @test size(renamed, 1) == 1
                @test renamed.watchlist_name[1] == renamed_to

                fetched = api(client, MyWatchlistEndpointModel(id = watchlist_id))
                @test fetched.watchlist_name[1] == renamed_to

                deleted = api(client, MyDeleteWatchlistEndpointModel(id = watchlist_id))
                @test deleted isa DataFrame
                @test size(deleted, 1) == 0
                watchlist_id = nothing

                # account settings: read trade_confirm_email, and write the same value back -
                settings = api(client, MyAccountConfigurationsEndpointModel())
                @test size(settings, 1) == 1
                current = settings.trade_confirm_email[1]
                @test current isa AbstractString
                updated = api(client, MyUpdateAccountConfigurationsEndpointModel(trade_confirm_email = String(current)))
                @test updated.trade_confirm_email[1] == current

                # crypto order: a gtc limit buy at half of the latest bid, replace the limit price, cancel -
                quotes = api(client, MyCryptoLatestQuotesEndpointModel(symbols = ["BTC/USD"]))
                bid = quotes.bid_price[1]
                @test bid > 0
                limit_price = round(0.5 * bid, digits = 0)
                try
                    order = submit(client, MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", qty = 0.001);
                                   type = "limit", time_in_force = "gtc", limit_price = limit_price)
                    order_id = order.id
                    @test order.symbol == "BTC/USD"
                    @test order.side == "buy"
                    @test order.type == "limit"
                    @test order.time_in_force == "gtc"
                    @test order.limit_price == limit_price

                    # wait until Alpaca has accepted the order, because a pending order cannot be replaced -
                    for attempt in 1:20
                        status = api(client, MyOrderEndpointModel(id = order_id))
                        if (string(status.status[1]) != "pending_new")
                            break
                        end
                        sleep(0.5)
                    end

                    # Alpaca still answers "pending replacement" right after the status changes, so wait a little more -
                    sleep(3)

                    # replace the limit price: Alpaca gives the replacing order a new identifier -
                    new_price = limit_price - 1000.0
                    replaced = api(client, MyReplaceOrderEndpointModel(id = order_id, limit_price = new_price))
                    @test size(replaced, 1) == 1
                    @test parse(Float64, string(replaced.limit_price[1])) == new_price
                    order_id = string(replaced.id[1])

                    # a replaced order cannot be cancelled while the replacement is pending, so wait first -
                    sleep(3)
                    cancel(client, order_id)
                    order_id = nothing
                catch error
                    if (error isa AlpacaError && error.status in (403, 422) && occursin("crypto", lowercase(error.message)))
                        @info "live skip (crypto order refused)" status = error.status message = error.message
                        @test_skip false
                    else
                        rethrow(error)
                    end
                end
            finally
                # clean up whatever the testset created, even after a failed assertion -
                if (order_id !== nothing)
                    sleep(3)
                    try
                        cancel(client, string(order_id))
                    catch error
                        @warn "cleanup: could not cancel the order" message = (error isa AlpacaError ? error.message : "non-Alpaca error")
                    end
                end
                if (watchlist_id !== nothing)
                    try
                        api(client, MyDeleteWatchlistEndpointModel(id = string(watchlist_id)))
                    catch error
                        @warn "cleanup: could not delete the watchlist" message = (error isa AlpacaError ? error.message : "non-Alpaca error")
                    end
                end
            end
        end
    end
end
