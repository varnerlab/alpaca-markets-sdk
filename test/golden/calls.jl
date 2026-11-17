# One entry per legacy call. Each function takes the client.

include("fixtures.jl")
include("canonical.jl")

const _G_OPT_P = "SPY261218P00500000"
const _G_OPT_C = "SPY261218C00600000"

function _golden_bars_csv(c)
    bars = get_bars(c, "AAPL", "1Day"; start = Date(2025, 1, 2), finish = Date(2025, 1, 3))
    path = tempname() * ".csv"
    write_bars_csv(path, bars["AAPL"])
    text = read(path, String)
    back = read_bars_csv(path)
    rm(path; force = true)
    return (text, back)
end

const GOLDEN_CALLS = Tuple{String,Function}[
    ("account", c -> get_account(c)),
    ("clock", c -> get_clock(c)),
    ("calendar", c -> get_calendar(c; start = Date(2026, 11, 16), finish = Date(2026, 11, 17))),
    ("calendar_noargs", c -> get_calendar(c)),
    ("assets", c -> list_assets(c)),
    ("assets_all", c -> list_assets(c; tradable_only = false)),
    ("asset", c -> get_asset(c, "AAPL")),
    ("positions", c -> list_positions(c)),
    ("position", c -> get_position(c, "AAPL")),
    ("close_position", c -> close_position(c, "AAPL"; qty = 5)),
    ("close_all_positions", c -> close_all_positions(c; cancel_orders = true)),
    ("orders", c -> list_orders(c; status = "all", symbols = ["AAPL", "MSFT"], after = DateTime(2026, 1, 1))),
    ("order", c -> get_order(c, "ord-1")),
    ("order_by_client_id", c -> get_order(c, "cid-1"; by_client_order_id = true)),
    ("submit_limit", c -> submit_order(c, "AAPL", 10, "buy"; type = "limit", limit_price = 150.25, client_order_id = "cid-9")),
    ("submit_notional", c -> submit_order(c, "AAPL", nothing, "buy"; notional = 500)),
    ("submit_option", c -> submit_order(c, _G_OPT_C, 1, "buy")),
    ("submit_error", c -> submit_order(c, "FAIL", 10, "buy")),
    ("submit_mleg", c -> submit_multileg_order(c,
        [OrderLeg("SPY261218P00540000", 1, "sell", "sell_to_open"),
         OrderLeg("SPY261218P00530000", 1, "buy", "buy_to_open")];
        limit_price = -1.25, qty = 2)),
    ("cancel_order", c -> cancel_order(c, "ord-1")),
    ("cancel_all_orders", c -> cancel_all_orders(c)),
    ("bars", c -> get_bars(c, ["AAPL", "MSFT"], "1Day"; start = Date(2025, 1, 2), finish = Date(2025, 1, 3))),
    ("quotes", c -> get_quotes(c, "AAPL"; start = DateTime(2025, 1, 2, 14, 30))),
    ("trades", c -> get_trades(c, "AAPL"; start = DateTime(2025, 1, 2, 14, 30), limit = 5)),
    ("latest_bar", c -> get_latest_bar(c, "AAPL")),
    ("latest_quote", c -> get_latest_quote(c, "AAPL")),
    ("latest_trade", c -> get_latest_trade(c, "AAPL"; feed = "sip")),
    ("snapshot", c -> get_snapshot(c, ["AAPL", "MSFT"])),
    ("download_bars", c -> download_bars(c, "AAPL", "1Day"; start = Date(2025, 1, 1), finish = Date(2025, 3, 31), chunk_months = 1)),
    ("bars_csv", _golden_bars_csv),
    ("option_contracts", c -> list_option_contracts(c; underlying_symbols = "SPY", expiration_date_gte = Date(2026, 12, 1), strike_price_gte = 140, type = "put")),
    ("option_contract", c -> get_option_contract(c, _G_OPT_P)),
    ("option_bars", c -> get_option_bars(c, [_G_OPT_P], "1Day"; start = Date(2026, 11, 2))),
    ("option_quotes", c -> get_option_quotes(c, _G_OPT_P; start = Date(2026, 11, 2))),
    ("option_trades", c -> get_option_trades(c, _G_OPT_P; start = Date(2026, 11, 2), finish = Date(2026, 11, 3))),
    ("option_latest_bar", c -> get_latest_option_bar(c, [_G_OPT_P, _G_OPT_C])),
    ("option_latest_quote", c -> get_latest_option_quote(c, [_G_OPT_P, _G_OPT_C])),
    ("option_latest_trade", c -> get_latest_option_trade(c, [_G_OPT_P, _G_OPT_C])),
    ("option_snapshots", c -> get_option_snapshots(c, [_G_OPT_P, _G_OPT_C])),
    ("option_chain", c -> get_option_chain_snapshot(c, "SPY"; type = "call", strike_price_gte = 140, expiration_date = Date(2026, 12, 18), limit = 2)),
]

# Run one call against the golden mock. Returns (canonical result, canonical requests).
function run_golden_call(f::Function)
    recorder, log = recording_handler(req -> HTTP.Response(200))
    # The recorder's String(req.body) empties the body vector, so the recorder
    # wraps a no-op and the route handler gets a request that still has its body.
    handler = function (req::HTTP.Request)
        saved = copy(req.body)
        recorder(req)
        return golden_handler(HTTP.Request(req.method, req.target, req.headers, saved))
    end
    result = nothing
    with_mock(handler) do client
        Logging.with_logger(Logging.NullLogger()) do
            try
                result = f(client)
            catch e
                result = e
            end
        end
    end
    requests = Any[golden_canonical_request(r) for r in log.entries]
    return (golden_canonical(result), requests)
end
