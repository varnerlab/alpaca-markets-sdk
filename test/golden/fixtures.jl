# Deterministic mock server routes for the golden capture. Every payload is a
# fixed JSON string (or an ordered NamedTuple), so the recorded results never
# depend on Dict iteration order.

const _G_BAR_A1 = """{"t":"2025-01-02T05:00:00Z","o":100.5,"h":101.25,"l":99.75,"c":100.0,"v":1200000,"n":5400,"vw":100.4}"""
const _G_BAR_A2 = """{"t":"2025-01-03T05:00:00Z","o":100.0,"h":102.0,"l":99.5,"c":101.5,"v":1300000}"""
const _G_BAR_M1 = """{"t":"2025-01-02T05:00:00Z","o":400.0,"h":402.5,"l":398.0,"c":401.0,"v":900000,"n":4100,"vw":400.7}"""
const _G_BAR_M2 = """{"t":"2025-01-03T05:00:00Z","o":401.0,"h":403.0,"l":400.0,"c":402.0,"v":950000}"""

const _G_QUOTE_1 = """{"t":"2025-01-02T14:30:00.123456789Z","bp":100.1,"bs":2,"ap":100.2,"as":3,"bx":"V","ax":"K"}"""
const _G_QUOTE_2 = """{"t":"2025-01-02T14:30:01Z","bp":100.15,"bs":4,"ap":100.25,"as":1,"bx":"V","ax":"V"}"""
const _G_TRADE_1 = """{"t":"2025-01-02T14:30:00.5Z","p":100.12,"s":50,"x":"V","i":1001}"""
const _G_TRADE_2 = """{"t":"2025-01-02T14:30:02Z","p":100.14,"s":10,"x":"K"}"""

const _G_OPT_BAR_1 = """{"t":"2026-11-02T05:00:00Z","o":12.5,"h":13.0,"l":12.0,"c":12.75,"v":340,"n":42,"vw":12.6}"""
const _G_OPT_BAR_2 = """{"t":"2026-11-03T05:00:00Z","o":12.75,"h":13.5,"l":12.5,"c":13.25,"v":210}"""
const _G_OPT_QUOTE_1 = """{"t":"2026-11-02T14:30:00Z","bp":12.4,"bs":10,"ap":12.6,"as":12,"bx":"C","ax":"C"}"""
const _G_OPT_QUOTE_2 = """{"t":"2026-11-02T14:31:00Z","bp":12.5,"bs":8,"ap":12.7,"as":9,"bx":"C","ax":"W"}"""
const _G_OPT_TRADE_1 = """{"t":"2026-11-02T14:30:30Z","p":12.5,"s":3,"x":"C"}"""
const _G_OPT_TRADE_2 = """{"t":"2026-11-02T15:00:00Z","p":12.65,"s":1,"x":"W"}"""

const _G_CONTRACT_1 = """{"id":"c-1","symbol":"SPY261218P00500000","name":"SPY Dec 18 2026 500 Put","status":"active","tradable":true,"expiration_date":"2026-12-18","root_symbol":"SPY","underlying_symbol":"SPY","underlying_asset_id":"u-1","type":"put","style":"american","strike_price":"500","multiplier":"100","size":"100","open_interest":"1520","open_interest_date":"2026-11-16","close_price":"12.75","close_price_date":"2026-11-16"}"""
const _G_CONTRACT_2 = """{"id":"c-2","symbol":"SPY261218C00600000","name":"SPY Dec 18 2026 600 Call","status":"active","tradable":true,"expiration_date":"2026-12-18","underlying_symbol":"SPY","type":"call","strike_price":"600"}"""

const _G_SNAP_PUT = """{"latestQuote":$(_G_OPT_QUOTE_1),"latestTrade":$(_G_OPT_TRADE_1),"minuteBar":$(_G_OPT_BAR_1),"dailyBar":$(_G_OPT_BAR_2),"prevDailyBar":$(_G_OPT_BAR_1),"impliedVolatility":0.2315,"greeks":{"delta":-0.42,"gamma":0.011,"theta":-0.05,"vega":0.21,"rho":-0.03}}"""
const _G_SNAP_PUT_LATER = """{"latestQuote":$(_G_OPT_QUOTE_2),"impliedVolatility":0.24,"greeks":{"delta":-0.41,"gamma":0.012}}"""
const _G_SNAP_CALL = """{"latestQuote":$(_G_OPT_QUOTE_2),"latestTrade":$(_G_OPT_TRADE_2)}"""

const _G_ORDER_FILLED = """{"id":"ord-1","client_order_id":"cid-1","symbol":"AAPL","asset_class":"us_equity","side":"buy","type":"market","time_in_force":"day","order_class":"","qty":"10","filled_qty":"10","limit_price":null,"stop_price":null,"filled_avg_price":"150.5","status":"filled","created_at":"2026-11-17T09:30:00.123456Z","submitted_at":"2026-11-17T09:30:00.2Z","filled_at":"2026-11-17T09:30:01Z"}"""
const _G_ORDER_NEW = """{"id":"ord-2","client_order_id":"cid-2","symbol":"MSFT","asset_class":"us_equity","side":"sell","type":"limit","time_in_force":"gtc","qty":"5","filled_qty":"0","limit_price":"410.25","status":"new","created_at":"2026-11-17T10:00:00Z","submitted_at":"2026-11-17T10:00:00Z"}"""

_g_json(status::Integer, body::AbstractString) =
    HTTP.Response(status, ["Content-Type" => "application/json"], body)

# Build a two-page response. `key` wraps the page content; page 1 carries the
# cursor "p2", page 2 carries a null cursor.
function _g_paged(query::AbstractDict, key::AbstractString,
                  page1::AbstractString, page2::AbstractString)
    if get(query, "page_token", nothing) == "p2"
        return _g_json(200, """{"$(key)":$(page2),"next_page_token":null}""")
    end
    return _g_json(200, """{"$(key)":$(page1),"next_page_token":"p2"}""")
end

function _g_order_response(body)
    if get(body, :order_class, "") == "mleg"
        legs = body.legs
        parent = """{"id":"ord-mleg","client_order_id":"cid-mleg","asset_class":"us_option","type":"$(body.type)","time_in_force":"$(body.time_in_force)","order_class":"mleg","qty":"$(body.qty)","filled_qty":"0","limit_price":"$(get(body, :limit_price, ""))","status":"accepted","created_at":"2026-11-17T10:00:00Z","legs":[""" *
            """{"id":"leg-1","symbol":"$(legs[1].symbol)","asset_class":"us_option","side":"$(legs[1].side)","type":"$(body.type)","time_in_force":"day","order_class":"mleg","position_intent":"$(legs[1].position_intent)","qty":"$(body.qty)","filled_qty":"0","status":"accepted"},""" *
            """{"id":"leg-2","symbol":"$(legs[2].symbol)","asset_class":"us_option","side":"$(legs[2].side)","type":"$(body.type)","time_in_force":"day","order_class":"mleg","position_intent":"$(legs[2].position_intent)","qty":"$(body.qty)","filled_qty":"0","status":"accepted"}]}"""
        return _g_json(200, parent)
    end
    symbol = String(body.symbol)
    asset_class = length(symbol) > 10 ? "us_option" : "us_equity"
    order = (id = "ord-new", client_order_id = String(get(body, :client_order_id, "auto-1")),
             symbol = symbol, asset_class = asset_class, side = String(body.side),
             type = String(body.type), time_in_force = String(body.time_in_force),
             qty = get(body, :qty, nothing), notional = get(body, :notional, nothing),
             limit_price = get(body, :limit_price, nothing),
             filled_qty = "0", status = "accepted",
             created_at = "2026-11-17T10:05:00Z")
    return _g_json(200, JSON3.write(order))
end

function golden_handler(req::HTTP.Request)::HTTP.Response
    uri = HTTP.URI(req.target)
    path = String(uri.path)
    query = Dict{String,String}(HTTP.queryparams(uri.query))
    method = String(req.method)

    if method == "POST" && path == "/orders"
        body = JSON3.read(String(req.body))
        if get(body, :symbol, "") == "FAIL"
            return _g_json(422, """{"code":40010001,"message":"qty must be positive"}""")
        end
        return _g_order_response(body)
    end

    if method == "DELETE"
        if path == "/orders/ord-1"
            return HTTP.Response(204, String[], "")
        elseif path == "/orders"
            return _g_json(207, """[{"id":"ord-1","status":200},{"id":"ord-2","status":200}]""")
        elseif path == "/positions/AAPL"
            return _g_json(200, _G_ORDER_FILLED)
        elseif path == "/positions"
            return _g_json(207, """[{"symbol":"AAPL","status":200,"body":$(_G_ORDER_FILLED)},{"symbol":"MSFT","status":200,"body":$(_G_ORDER_NEW)}]""")
        end
        return _g_json(404, """{"code":40410000,"message":"not found"}""")
    end

    if method != "GET"
        return _g_json(405, """{"message":"method not allowed"}""")
    end

    if path == "/account"
        return _g_json(200, """{"id":"acct-1","account_number":"PA123","status":"ACTIVE","currency":"USD","cash":"10000.50","buying_power":"20000","portfolio_value":"25000.75","equity":"25000.75","last_equity":"24900","pattern_day_trader":false,"trading_blocked":false,"transfers_blocked":false,"account_blocked":false}""")
    elseif path == "/clock"
        return _g_json(200, """{"timestamp":"2026-11-17T10:00:00.123456789-05:00","is_open":true,"next_open":"2026-11-18T09:30:00-05:00","next_close":"2026-11-17T16:00:00-05:00"}""")
    elseif path == "/calendar"
        return _g_json(200, """[{"date":"2026-11-16","open":"09:30","close":"16:00","session_open":"0400","session_close":"2000"},{"date":"2026-11-17","open":"09:30","close":"13:00"}]""")
    elseif path == "/assets"
        return _g_json(200, """[{"id":"a-1","class":"us_equity","exchange":"NASDAQ","symbol":"AAPL","name":"Apple Inc.","status":"active","tradable":true,"marginable":true,"shortable":true,"easy_to_borrow":true,"fractionable":true},{"id":"a-2","class":"us_equity","exchange":"NYSE","symbol":"DEAD","status":"active","tradable":false}]""")
    elseif path == "/assets/AAPL"
        return _g_json(200, """{"id":"a-1","class":"us_equity","exchange":"NASDAQ","symbol":"AAPL","name":"Apple Inc.","status":"active","tradable":true,"marginable":true,"shortable":false,"easy_to_borrow":true,"fractionable":true}""")
    elseif path == "/positions"
        return _g_json(200, """[{"asset_id":"a-1","symbol":"AAPL","exchange":"NASDAQ","asset_class":"us_equity","qty":"10","side":"long","avg_entry_price":"150.5","market_value":"1600","cost_basis":"1505","unrealized_pl":"95","unrealized_plpc":"0.0631","current_price":"160","lastday_price":"158","change_today":"0.0127"},{"asset_id":"a-3","symbol":"SPY261218C00600000","qty":"-1"}]""")
    elseif path == "/positions/AAPL"
        return _g_json(200, """{"asset_id":"a-1","symbol":"AAPL","exchange":"NASDAQ","asset_class":"us_equity","qty":"10","side":"long","avg_entry_price":"150.5","market_value":"1600","cost_basis":"1505","unrealized_pl":"95","unrealized_plpc":"0.0631","current_price":"160","lastday_price":"158","change_today":"0.0127"}""")
    elseif path == "/orders"
        return _g_json(200, "[" * _G_ORDER_FILLED * "," * _G_ORDER_NEW * "]")
    elseif path == "/orders/ord-1" || path == "/orders:by_client_order_id"
        return _g_json(200, _G_ORDER_FILLED)

    elseif path == "/stocks/bars"
        return _g_paged(query, "bars",
            """{"AAPL":[$(_G_BAR_A1)],"MSFT":[$(_G_BAR_M1)]}""",
            """{"AAPL":[$(_G_BAR_A2)],"MSFT":[$(_G_BAR_M2)]}""")
    elseif path == "/stocks/quotes"
        return _g_paged(query, "quotes",
            """{"AAPL":[$(_G_QUOTE_1)]}""", """{"AAPL":[$(_G_QUOTE_2)]}""")
    elseif path == "/stocks/trades"
        return _g_paged(query, "trades",
            """{"AAPL":[$(_G_TRADE_1)]}""", """{"AAPL":[$(_G_TRADE_2)]}""")
    elseif path == "/stocks/AAPL/bars/latest"
        return _g_json(200, """{"bar":$(_G_BAR_A1)}""")
    elseif path == "/stocks/AAPL/quotes/latest"
        return _g_json(200, """{"quote":$(_G_QUOTE_1)}""")
    elseif path == "/stocks/AAPL/trades/latest"
        return _g_json(200, """{"trade":$(_G_TRADE_1)}""")
    elseif path == "/stocks/snapshots"
        return _g_json(200, """{"AAPL":{"latestTrade":$(_G_TRADE_1),"latestQuote":$(_G_QUOTE_1),"minuteBar":$(_G_BAR_A1),"dailyBar":$(_G_BAR_A2)},"MSFT":{"latestTrade":$(_G_TRADE_2)}}""")

    elseif path == "/options/contracts"
        return _g_paged(query, "option_contracts",
            "[" * _G_CONTRACT_1 * "]", "[" * _G_CONTRACT_2 * "]")
    elseif path == "/options/contracts/SPY261218P00500000"
        return _g_json(200, _G_CONTRACT_1)
    elseif path == "/options/bars"
        return _g_paged(query, "bars",
            """{"SPY261218P00500000":[$(_G_OPT_BAR_1)]}""",
            """{"SPY261218P00500000":[$(_G_OPT_BAR_2)]}""")
    elseif path == "/options/trades"
        return _g_paged(query, "trades",
            """{"SPY261218P00500000":[$(_G_OPT_TRADE_1)]}""",
            """{"SPY261218P00500000":[$(_G_OPT_TRADE_2)]}""")
    elseif path == "/options/quotes/latest"
        return _g_json(200, """{"quotes":{"SPY261218P00500000":$(_G_OPT_QUOTE_1),"SPY261218C00600000":$(_G_OPT_QUOTE_2)}}""")
    elseif path == "/options/trades/latest"
        return _g_json(200, """{"trades":{"SPY261218P00500000":$(_G_OPT_TRADE_1),"SPY261218C00600000":$(_G_OPT_TRADE_2)}}""")
    elseif path == "/options/snapshots"
        return _g_json(200, """{"snapshots":{"SPY261218P00500000":$(_G_SNAP_PUT),"SPY261218C00600000":$(_G_SNAP_CALL)}}""")
    elseif path == "/options/snapshots/SPY"
        return _g_paged(query, "snapshots",
            """{"SPY261218P00500000":$(_G_SNAP_PUT),"SPY261218C00600000":$(_G_SNAP_CALL)}""",
            """{"SPY261218P00500000":$(_G_SNAP_PUT_LATER)}""")
    end

    return _g_json(404, """{"code":40410000,"message":"no golden route for $(method) $(path)"}""")
end
