using DataFrames

# a multi-leg (mleg) order: a parent with two option legs. Later tests reuse it -
const _N_MLEG_ORDER = Dict{String,Any}(
    "id" => "0f4c1e7a-1111-4a6e-9a11-000000000001",
    "client_order_id" => "mleg-parent-1",
    "order_class" => "mleg",
    "qty" => "1",
    "filled_qty" => "0",
    "type" => "limit",
    "time_in_force" => "day",
    "limit_price" => "1.25",
    "status" => "new",
    "created_at" => "2026-11-17T14:30:00.123456Z",
    "submitted_at" => "2026-11-17T14:30:00.234567Z",
    "legs" => Any[
        Dict{String,Any}(
            "id" => "0f4c1e7a-2222-4a6e-9a11-000000000002",
            "symbol" => "AAPL261218C00200000",
            "side" => "buy",
            "position_intent" => "buy_to_open",
            "ratio_qty" => "1",
            "qty" => "1",
            "filled_qty" => "0",
            "type" => "limit",
            "time_in_force" => "day",
            "status" => "new",
            "asset_class" => "us_option"),
        Dict{String,Any}(
            "id" => "0f4c1e7a-3333-4a6e-9a11-000000000003",
            "symbol" => "AAPL261218C00210000",
            "side" => "sell",
            "position_intent" => "sell_to_open",
            "ratio_qty" => "1",
            "qty" => "1",
            "filled_qty" => "0",
            "type" => "limit",
            "time_in_force" => "day",
            "status" => "new",
            "asset_class" => "us_option")])

const _N_ASSET_TRADABLE = Dict{String,Any}(
    "id" => "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415", "class" => "us_equity", "exchange" => "NASDAQ",
    "symbol" => "AAPL", "name" => "Apple Inc.", "status" => "active", "tradable" => true,
    "marginable" => true, "shortable" => true, "easy_to_borrow" => true, "fractionable" => true)

const _N_ASSET_DEAD = Dict{String,Any}(
    "id" => "11111111-8b9b-48a9-ba46-b9d54906e415", "class" => "us_equity", "exchange" => "OTC",
    "symbol" => "DEAD", "name" => "Dead Corp.", "status" => "inactive", "tradable" => false,
    "marginable" => false, "shortable" => false, "easy_to_borrow" => false, "fractionable" => false)

const _N_ACCOUNT = Dict{String,Any}(
    "id" => "acct-1", "account_number" => "PA123", "status" => "ACTIVE", "currency" => "USD",
    "cash" => "100000.5", "buying_power" => "200000", "portfolio_value" => "100500.25",
    "equity" => "100500.25", "last_equity" => "100000", "pattern_day_trader" => false,
    "trading_blocked" => false, "transfers_blocked" => false, "account_blocked" => true)

const _N_POSITION = Dict{String,Any}(
    "asset_id" => "b0b6dd9d-8b9b-48a9-ba46-b9d54906e415", "symbol" => "AAPL", "exchange" => "NASDAQ",
    "asset_class" => "us_equity", "qty" => "10", "side" => "long", "avg_entry_price" => "150.5",
    "market_value" => "1600", "cost_basis" => "1505", "unrealized_pl" => "95", "unrealized_plpc" => "0.0631",
    "current_price" => "160", "lastday_price" => "158", "change_today" => "0.0127")

const _N_CONTRACT = Dict{String,Any}(
    "id" => "c-1", "symbol" => "AAPL261218C00200000", "name" => "AAPL Dec 18 2026 200 Call", "status" => "active",
    "tradable" => true, "expiration_date" => "2026-12-18", "root_symbol" => "AAPL", "underlying_symbol" => "AAPL",
    "underlying_asset_id" => "b0b6dd9d", "type" => "call", "style" => "american", "strike_price" => "200",
    "multiplier" => "100", "size" => "100", "open_interest" => "42", "open_interest_date" => "2026-11-16",
    "close_price" => "3.1", "close_price_date" => "2026-11-16")

@testset "parse: _parse_utc" begin
    @test Alpaca._parse_utc("2026-11-18T09:30:00-05:00") == DateTime(2026, 11, 18, 14, 30)
    @test Alpaca._parse_utc("2026-04-11T20:00:00.123456789Z") == DateTime(2026, 4, 11, 20, 0, 0, 123)
    @test Alpaca._parse_utc("2026-04-11T20:00:00+02:00") == DateTime(2026, 4, 11, 18, 0, 0)
    @test Alpaca._parse_utc("2026-04-11T20:00:00Z") == DateTime(2026, 4, 11, 20, 0, 0)
    @test ismissing(Alpaca._parse_utc(nothing))
    @test ismissing(Alpaca._parse_utc(""))
end

@testset "handler: clock in UTC" begin
    body = JSON3.write(Dict("timestamp" => "2026-11-17T10:00:00-05:00", "is_open" => true,
                            "next_open" => "2026-11-18T09:30:00-05:00", "next_close" => "2026-11-17T16:00:00-05:00"))
    df = Alpaca._default_handler(MyClockEndpointModel, body)
    @test names(df) == ["timestamp", "is_open", "next_open", "next_close"]
    @test df[1, :next_open] == DateTime(2026, 11, 18, 14, 30)
    @test df[1, :timestamp] == DateTime(2026, 11, 17, 15, 0)
    @test df[1, :is_open] == true
end

@testset "handler: account" begin
    df = Alpaca._default_handler(MyAccountEndpointModel, JSON3.write(_N_ACCOUNT))
    @test names(df) == ["id", "account_number", "status", "currency", "cash", "buying_power", "portfolio_value",
                        "equity", "last_equity", "pattern_day_trader", "trading_blocked", "transfers_blocked",
                        "account_blocked"]
    @test size(df, 1) == 1
    @test df[1, :cash] === 100000.5
    @test df[1, :account_blocked] == true
    @test df[1, :id] == "acct-1"
end

@testset "handler: calendar" begin
    body = JSON3.write([Dict("date" => "2026-11-18", "open" => "09:30", "close" => "16:00",
                             "session_open" => "0400", "session_close" => "2000"),
                        Dict("date" => "2026-11-19", "open" => "09:30", "close" => "13:00")])
    df = Alpaca._default_handler(MyCalendarEndpointModel, body)
    @test names(df) == ["date", "open", "close", "session_open", "session_close"]
    @test df[1, :date] == Date(2026, 11, 18)
    @test df[1, :open] == Time(9, 30)
    @test df[1, :session_open] == Time(4, 0)
    @test df[1, :session_close] == Time(20, 0)
    @test ismissing(df[2, :session_open])
    @test size(Alpaca._default_handler(MyCalendarEndpointModel, "[]"), 1) == 0
end

@testset "handler: assets and asset" begin
    cols = ["id", "class", "exchange", "symbol", "name", "status", "tradable", "marginable", "shortable",
            "easy_to_borrow", "fractionable"]
    df = Alpaca._default_handler(MyAssetsEndpointModel, JSON3.write([_N_ASSET_TRADABLE, _N_ASSET_DEAD]))
    @test names(df) == cols
    @test size(df, 1) == 2
    @test df[1, :symbol] == "AAPL"
    @test df[2, :tradable] == false
    one = Alpaca._default_handler(MyAssetEndpointModel, JSON3.write(_N_ASSET_TRADABLE))
    @test names(one) == cols
    @test size(one, 1) == 1
    @test one[1, :name] == "Apple Inc."
end

@testset "handler: positions and position" begin
    cols = ["asset_id", "symbol", "exchange", "asset_class", "qty", "side", "avg_entry_price", "market_value",
            "cost_basis", "unrealized_pl", "unrealized_plpc", "current_price", "lastday_price", "change_today"]
    df = Alpaca._default_handler(MyPositionsEndpointModel, JSON3.write([_N_POSITION]))
    @test names(df) == cols
    @test df[1, :qty] === 10.0
    @test df[1, :avg_entry_price] === 150.5
    one = Alpaca._default_handler(MyPositionEndpointModel, JSON3.write(_N_POSITION))
    @test names(one) == cols
    @test one[1, :symbol] == "AAPL"
    @test size(Alpaca._default_handler(MyPositionsEndpointModel, "[]"), 1) == 0
end

@testset "handler: orders with legs, and an empty orders table" begin
    df = Alpaca._default_handler(MyOrdersEndpointModel, JSON3.write([_N_MLEG_ORDER]))
    @test names(df) == ["id", "parent_id", "client_order_id", "symbol", "asset_class", "side", "type",
                        "time_in_force", "order_class", "position_intent", "qty", "filled_qty", "limit_price",
                        "stop_price", "filled_avg_price", "status", "created_at", "submitted_at", "filled_at"]
    @test size(df, 1) == 3
    @test ismissing(df[1, :parent_id])
    @test df[2, :parent_id] == df[1, :id]
    @test df[3, :parent_id] == df[1, :id]
    @test ismissing(df[1, :symbol])
    @test df[2, :symbol] == "AAPL261218C00200000"
    @test df[3, :position_intent] == "sell_to_open"
    @test df[1, :limit_price] === 1.25
    @test ismissing(df[1, :stop_price])
    @test df[1, :created_at] == DateTime(2026, 11, 17, 14, 30, 0, 123)
    @test ismissing(df[1, :filled_at])
    empty = Alpaca._default_handler(MyOrdersEndpointModel, "[]")
    @test size(empty, 1) == 0
    @test "parent_id" in names(empty)
    one = Alpaca._default_handler(MyOrderEndpointModel, JSON3.write(_N_MLEG_ORDER))
    @test size(one, 1) == 3
end

@testset "handler: assets are not filtered" begin
    df = Alpaca._default_handler(MyAssetsEndpointModel, JSON3.write([_N_ASSET_TRADABLE, _N_ASSET_DEAD]))
    @test size(df, 1) == 2
end

@testset "handler: option contracts" begin
    cols = ["id", "symbol", "name", "status", "tradable", "expiration_date", "root_symbol", "underlying_symbol",
            "underlying_asset_id", "type", "style", "strike_price", "multiplier", "size", "open_interest",
            "open_interest_date", "close_price", "close_price_date"]
    df = Alpaca._default_handler(MyOptionContractsEndpointModel,
        JSON3.write(Dict("option_contracts" => [_N_CONTRACT], "next_page_token" => nothing)))
    @test names(df) == cols
    @test size(df, 1) == 1
    @test df[1, :expiration_date] == Date(2026, 12, 18)
    @test df[1, :strike_price] === 200.0
    @test df[1, :open_interest] === 42.0
    sparse = Dict{String,Any}(k => v for (k, v) in _N_CONTRACT if !(k in ("open_interest", "open_interest_date", "close_price", "close_price_date")))
    one = Alpaca._default_handler(MyOptionContractEndpointModel, JSON3.write(sparse))
    @test names(one) == cols
    @test ismissing(one[1, :open_interest])
    @test ismissing(one[1, :close_price_date])
    empty = Alpaca._default_handler(MyOptionContractsEndpointModel, JSON3.write(Dict("option_contracts" => Any[])))
    @test size(empty, 1) == 0
    @test names(empty) == cols
    null_list = Alpaca._default_handler(MyOptionContractsEndpointModel,
        "{\"option_contracts\":null,\"next_page_token\":null}")
    @test size(null_list, 1) == 0
    @test names(null_list) == cols
end

@testset "handler: a field that Alpaca does not send is missing, not a default" begin
    position = Alpaca._default_handler(MyPositionEndpointModel, JSON3.write(Dict("asset_id" => "a-1", "symbol" => "AAPL")))
    for name in ("exchange", "asset_class", "qty", "side", "avg_entry_price", "market_value", "cost_basis", "unrealized_pl",
                 "unrealized_plpc", "current_price", "lastday_price", "change_today")
        @test ismissing(position[1, name])
    end

    contract = Alpaca._default_handler(MyOptionContractEndpointModel, JSON3.write(Dict("id" => "c-1",
        "symbol" => "AAPL261218C00200000", "expiration_date" => "2026-12-18", "underlying_symbol" => "AAPL", "type" => "call")))
    for name in ("name", "status", "tradable", "root_symbol", "underlying_asset_id", "style", "strike_price", "multiplier", "size")
        @test ismissing(contract[1, name])
    end
    @test contract[1, :underlying_symbol] == "AAPL"

    account = Alpaca._default_handler(MyAccountEndpointModel, JSON3.write(Dict("id" => "acct-1", "account_number" => "PA123",
        "status" => "ACTIVE", "currency" => "USD")))
    for name in ("cash", "buying_power", "portfolio_value", "equity", "last_equity", "pattern_day_trader", "trading_blocked",
                 "transfers_blocked", "account_blocked")
        @test ismissing(account[1, name])
    end

    clock = Alpaca._default_handler(MyClockEndpointModel, JSON3.write(Dict("timestamp" => "2026-11-17T10:00:00-05:00")))
    @test ismissing(clock[1, :is_open])

    asset = Alpaca._default_handler(MyAssetEndpointModel, JSON3.write(Dict("id" => "x", "class" => "us_equity",
        "exchange" => "NASDAQ", "symbol" => "AAPL", "status" => "active")))
    for name in ("name", "tradable", "marginable", "shortable", "easy_to_borrow", "fractionable")
        @test ismissing(asset[1, name])
    end

    order = Alpaca._default_handler(MyOrderEndpointModel, JSON3.write(Dict("id" => "o-1", "type" => "market",
        "time_in_force" => "day", "status" => "new")))
    for name in ("client_order_id", "asset_class", "order_class", "filled_qty")
        @test ismissing(order[1, name])
    end
end
