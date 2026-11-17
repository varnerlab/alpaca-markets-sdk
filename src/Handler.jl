# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
# The default handlers live in the private section below. A handler receives the type of the endpoint model and
# the body of a response as a String, and returns a DataFrame with one row for each record.
# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
"""
    _json_records(body::String, list_keys::Vector{String}) -> Vector{Any}

Parse a JSON response body into a vector of records. A JSON array is a list of records. A JSON object that holds
a list under one of the `list_keys` is that list. Any other JSON object is a single record. When `list_keys`
is not empty and the object holds none of them, the response has no records.
"""
function _json_records(body::String, list_keys::Vector{String})::Vector{Any}

    # parse the response body -
    parsed = JSON3.read(body);
    records = Any[];

    # a JSON array is a list of records -
    if (parsed isa JSON3.Array)
        for record in parsed
            push!(records, record);
        end
        return records;
    end

    # a JSON object can hold the list of records under a key -
    for key in list_keys
        if (haskey(parsed, Symbol(key)) == true)
            for record in parsed[Symbol(key)]
                push!(records, record);
            end
            return records;
        end
    end

    # a list key that is not in the response means there are no records -
    if (isempty(list_keys) == false)
        return records;
    end

    # any other JSON object is a single record -
    push!(records, parsed);
    return records;
end

# _string_field: a required text field, or the default when the field is missing or null -
function _string_field(record, key::Symbol, default::String)::String

    # look up the field, and fall back to the default when it has no value -
    value = get(record, key, nothing);
    if (value === nothing)
        return default;
    end
    return String(value);
end

# _string_or_missing: an optional text field; missing when the field is missing or null -
function _string_or_missing(record, key::Symbol)::Union{Missing,String}

    # look up the field -
    value = get(record, key, nothing);
    if (value === nothing)
        return missing;
    end
    return String(value);
end

# _float_field: a number that Alpaca sends as text or as a number; the default when there is no value -
function _float_field(record, key::Symbol, default::Float64)::Float64

    # parse the field, and fall back to the default when it has no value -
    value = _parse_float(get(record, key, nothing));
    if (value === nothing)
        return default;
    end
    return value;
end

# _float_or_missing: an optional number; missing when there is no value -
function _float_or_missing(record, key::Symbol)::Union{Missing,Float64}

    # parse the field -
    value = _parse_float(get(record, key, nothing));
    if (value === nothing)
        return missing;
    end
    return value;
end

# _bool_field: a true or false flag; the default when the field is missing or null -
function _bool_field(record, key::Symbol, default::Bool)::Bool

    # look up the field, and fall back to the default when it has no value -
    value = get(record, key, nothing);
    if (value === nothing)
        return default;
    end
    return Bool(value);
end

# _date_or_missing: an optional ISO date; missing when there is no value -
function _date_or_missing(record, key::Symbol)::Union{Missing,Date}

    # parse the field -
    value = _parse_date_maybe(get(record, key, nothing));
    if (value === nothing)
        return missing;
    end
    return value;
end

# _time_or_missing: an optional calendar time of day (HHMM or HH:MM); missing when there is no value -
function _time_or_missing(record, key::Symbol)::Union{Missing,Time}

    # look up the field -
    value = get(record, key, nothing);
    if (value === nothing)
        return missing;
    end
    if (isempty(String(value)) == true)
        return missing;
    end
    return _parse_cal_time(String(value));
end

"""
    _default_handler(model::Type{MyAccountEndpointModel}, body::String) -> DataFrame

Process the response of the `/account` endpoint. The table has one row. The columns are `id`, `account_number`,
`status`, `currency`, `cash`, `buying_power`, `portfolio_value`, `equity`, `last_equity`, `pattern_day_trader`,
`trading_blocked`, `transfers_blocked`, and `account_blocked`. The money columns are `Float64`.
"""
function _default_handler(model::Type{MyAccountEndpointModel}, body::String)::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    account_numbers = Array{String,1}();
    statuses = Array{String,1}();
    currencies = Array{String,1}();
    cashes = Array{Float64,1}();
    buying_powers = Array{Float64,1}();
    portfolio_values = Array{Float64,1}();
    equities = Array{Float64,1}();
    last_equities = Array{Float64,1}();
    pattern_day_traders = Array{Bool,1}();
    trading_blockeds = Array{Bool,1}();
    transfers_blockeds = Array{Bool,1}();
    account_blockeds = Array{Bool,1}();

    # visit the records, and select the fields we want -
    for record in _json_records(body, String[])
        push!(ids, String(record.id));
        push!(account_numbers, String(record.account_number));
        push!(statuses, String(record.status));
        push!(currencies, String(record.currency));
        push!(cashes, _float_field(record, :cash, 0.0));
        push!(buying_powers, _float_field(record, :buying_power, 0.0));
        push!(portfolio_values, _float_field(record, :portfolio_value, 0.0));
        push!(equities, _float_field(record, :equity, 0.0));
        push!(last_equities, _float_field(record, :last_equity, 0.0));
        push!(pattern_day_traders, _bool_field(record, :pattern_day_trader, false));
        push!(trading_blockeds, _bool_field(record, :trading_blocked, false));
        push!(transfers_blockeds, _bool_field(record, :transfers_blocked, false));
        push!(account_blockeds, _bool_field(record, :account_blocked, false));
    end

    # put the columns into a table, and return it -
    return DataFrame(id = ids, account_number = account_numbers, status = statuses, currency = currencies,
        cash = cashes, buying_power = buying_powers, portfolio_value = portfolio_values, equity = equities,
        last_equity = last_equities, pattern_day_trader = pattern_day_traders, trading_blocked = trading_blockeds,
        transfers_blocked = transfers_blockeds, account_blocked = account_blockeds);
end

"""
    _default_handler(model::Type{MyClockEndpointModel}, body::String) -> DataFrame

Process the response of the `/clock` endpoint. The table has one row. The columns are `timestamp`, `is_open`,
`next_open`, and `next_close`. The three times are `DateTime` values in UTC.
"""
function _default_handler(model::Type{MyClockEndpointModel}, body::String)::DataFrame

    # initialize: one array for each column of the table -
    timestamps = Array{Union{Missing,DateTime},1}();
    is_opens = Array{Bool,1}();
    next_opens = Array{Union{Missing,DateTime},1}();
    next_closes = Array{Union{Missing,DateTime},1}();

    # visit the records, and convert the times to UTC -
    for record in _json_records(body, String[])
        push!(timestamps, _parse_utc(get(record, :timestamp, nothing)));
        push!(is_opens, _bool_field(record, :is_open, false));
        push!(next_opens, _parse_utc(get(record, :next_open, nothing)));
        push!(next_closes, _parse_utc(get(record, :next_close, nothing)));
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = timestamps, is_open = is_opens, next_open = next_opens, next_close = next_closes);
end

"""
    _default_handler(model::Type{MyCalendarEndpointModel}, body::String) -> DataFrame

Process the response of the `/calendar` endpoint. The table has one row for each trading day. The columns are
`date`, `open`, `close`, `session_open`, and `session_close`. Alpaca writes the regular session times as `HH:MM` and
the extended session times as `HHMM`. Both become `Time` values. A day with no extended session has `missing` there.
"""
function _default_handler(model::Type{MyCalendarEndpointModel}, body::String)::DataFrame

    # initialize: one array for each column of the table -
    dates = Array{Date,1}();
    opens = Array{Time,1}();
    closes = Array{Time,1}();
    session_opens = Array{Union{Missing,Time},1}();
    session_closes = Array{Union{Missing,Time},1}();

    # visit the records, and convert the times of day -
    for record in _json_records(body, String[])
        push!(dates, Date(String(record.date)));
        push!(opens, _parse_cal_time(String(record.open)));
        push!(closes, _parse_cal_time(String(record.close)));
        push!(session_opens, _time_or_missing(record, :session_open));
        push!(session_closes, _time_or_missing(record, :session_close));
    end

    # put the columns into a table, and return it -
    return DataFrame(date = dates, open = opens, close = closes, session_open = session_opens,
        session_close = session_closes);
end

"""
    _assets_table(records::Vector{Any}) -> DataFrame

Build the assets table from a vector of asset records. The columns are `id`, `class`, `exchange`, `symbol`, `name`,
`status`, `tradable`, `marginable`, `shortable`, `easy_to_borrow`, and `fractionable`. No asset is filtered out.
"""
function _assets_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    classes = Array{String,1}();
    exchanges = Array{String,1}();
    symbols = Array{String,1}();
    asset_names = Array{String,1}();
    statuses = Array{String,1}();
    tradables = Array{Bool,1}();
    marginables = Array{Bool,1}();
    shortables = Array{Bool,1}();
    easy_to_borrows = Array{Bool,1}();
    fractionables = Array{Bool,1}();

    # visit the records, and select the fields we want -
    for record in records
        push!(ids, String(record.id));
        push!(classes, String(record.class));
        push!(exchanges, String(record.exchange));
        push!(symbols, String(record.symbol));
        push!(asset_names, _string_field(record, :name, ""));
        push!(statuses, String(record.status));
        push!(tradables, _bool_field(record, :tradable, false));
        push!(marginables, _bool_field(record, :marginable, false));
        push!(shortables, _bool_field(record, :shortable, false));
        push!(easy_to_borrows, _bool_field(record, :easy_to_borrow, false));
        push!(fractionables, _bool_field(record, :fractionable, false));
    end

    # put the columns into a table, and return it -
    return DataFrame(id = ids, class = classes, exchange = exchanges, symbol = symbols, name = asset_names,
        status = statuses, tradable = tradables, marginable = marginables, shortable = shortables,
        easy_to_borrow = easy_to_borrows, fractionable = fractionables);
end

"""
    _default_handler(model::Type{MyAssetsEndpointModel}, body::String) -> DataFrame

Process the response of the `/assets` endpoint. The table has one row for each asset, with the columns of `_assets_table`.
"""
function _default_handler(model::Type{MyAssetsEndpointModel}, body::String)::DataFrame
    return _assets_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyAssetEndpointModel}, body::String) -> DataFrame

Process the response of the `/assets/{symbol_or_id}` endpoint. The table has one row, with the columns of `_assets_table`.
"""
function _default_handler(model::Type{MyAssetEndpointModel}, body::String)::DataFrame
    return _assets_table(_json_records(body, String[]));
end

"""
    _positions_table(records::Vector{Any}) -> DataFrame

Build the positions table from a vector of position records. The columns are `asset_id`, `symbol`, `exchange`,
`asset_class`, `qty`, `side`, `avg_entry_price`, `market_value`, `cost_basis`, `unrealized_pl`, `unrealized_plpc`,
`current_price`, `lastday_price`, and `change_today`. The quantities and prices are `Float64`.
"""
function _positions_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    asset_ids = Array{String,1}();
    symbols = Array{String,1}();
    exchanges = Array{String,1}();
    asset_classes = Array{String,1}();
    qtys = Array{Float64,1}();
    sides = Array{String,1}();
    avg_entry_prices = Array{Float64,1}();
    market_values = Array{Float64,1}();
    cost_bases = Array{Float64,1}();
    unrealized_pls = Array{Float64,1}();
    unrealized_plpcs = Array{Float64,1}();
    current_prices = Array{Float64,1}();
    lastday_prices = Array{Float64,1}();
    change_todays = Array{Float64,1}();

    # visit the records, and select the fields we want -
    for record in records
        push!(asset_ids, String(record.asset_id));
        push!(symbols, String(record.symbol));
        push!(exchanges, _string_field(record, :exchange, ""));
        push!(asset_classes, _string_field(record, :asset_class, "us_equity"));
        push!(qtys, _float_field(record, :qty, 0.0));
        push!(sides, _string_field(record, :side, "long"));
        push!(avg_entry_prices, _float_field(record, :avg_entry_price, 0.0));
        push!(market_values, _float_field(record, :market_value, 0.0));
        push!(cost_bases, _float_field(record, :cost_basis, 0.0));
        push!(unrealized_pls, _float_field(record, :unrealized_pl, 0.0));
        push!(unrealized_plpcs, _float_field(record, :unrealized_plpc, 0.0));
        push!(current_prices, _float_field(record, :current_price, 0.0));
        push!(lastday_prices, _float_field(record, :lastday_price, 0.0));
        push!(change_todays, _float_field(record, :change_today, 0.0));
    end

    # put the columns into a table, and return it -
    return DataFrame(asset_id = asset_ids, symbol = symbols, exchange = exchanges, asset_class = asset_classes,
        qty = qtys, side = sides, avg_entry_price = avg_entry_prices, market_value = market_values,
        cost_basis = cost_bases, unrealized_pl = unrealized_pls, unrealized_plpc = unrealized_plpcs,
        current_price = current_prices, lastday_price = lastday_prices, change_today = change_todays);
end

"""
    _default_handler(model::Type{MyPositionsEndpointModel}, body::String) -> DataFrame

Process the response of the `/positions` endpoint. The table has one row for each position, with the columns of `_positions_table`.
"""
function _default_handler(model::Type{MyPositionsEndpointModel}, body::String)::DataFrame
    return _positions_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyPositionEndpointModel}, body::String) -> DataFrame

Process the response of the `/positions/{symbol_or_asset_id}` endpoint. The table has one row, with the columns of `_positions_table`.
"""
function _default_handler(model::Type{MyPositionEndpointModel}, body::String)::DataFrame
    return _positions_table(_json_records(body, String[]));
end

"""
    _orders_table(records::Vector{Any}) -> DataFrame

Build the orders table from a vector of order records. A multi-leg parent order is followed by one row for each of
its legs. The `parent_id` of a leg is the `id` of its parent, and it is `missing` on a top-level row. The columns are
`id`, `parent_id`, `client_order_id`, `symbol`, `asset_class`, `side`, `type`, `time_in_force`, `order_class`,
`position_intent`, `qty`, `filled_qty`, `limit_price`, `stop_price`, `filled_avg_price`, `status`, `created_at`,
`submitted_at`, and `filled_at`. The three times are `DateTime` values in UTC.
"""
function _orders_table(records::Vector{Any})::DataFrame

    # flatten the records: each parent, then its legs. A leg remembers the id of its parent -
    rows = Any[];
    parent_of_row = Union{Missing,String}[];
    for record in records
        push!(rows, record);
        push!(parent_of_row, missing);
        legs = get(record, :legs, nothing);
        if (legs !== nothing)
            for leg in legs
                push!(rows, leg);
                push!(parent_of_row, String(record.id));
            end
        end
    end

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    parent_ids = Array{Union{Missing,String},1}();
    client_order_ids = Array{String,1}();
    symbols = Array{Union{Missing,String},1}();
    asset_classes = Array{String,1}();
    sides = Array{Union{Missing,String},1}();
    types = Array{String,1}();
    time_in_forces = Array{String,1}();
    order_classes = Array{String,1}();
    position_intents = Array{Union{Missing,String},1}();
    qtys = Array{Union{Missing,Float64},1}();
    filled_qtys = Array{Float64,1}();
    limit_prices = Array{Union{Missing,Float64},1}();
    stop_prices = Array{Union{Missing,Float64},1}();
    filled_avg_prices = Array{Union{Missing,Float64},1}();
    statuses = Array{String,1}();
    created_ats = Array{Union{Missing,DateTime},1}();
    submitted_ats = Array{Union{Missing,DateTime},1}();
    filled_ats = Array{Union{Missing,DateTime},1}();

    # visit the rows, and select the fields we want -
    for i in eachindex(rows)
        row = rows[i];
        push!(ids, String(row.id));
        push!(parent_ids, parent_of_row[i]);
        push!(client_order_ids, _string_field(row, :client_order_id, ""));
        push!(symbols, _string_or_missing(row, :symbol));
        push!(asset_classes, _string_field(row, :asset_class, "us_equity"));
        push!(sides, _string_or_missing(row, :side));
        push!(types, String(row.type));
        push!(time_in_forces, String(row.time_in_force));
        push!(order_classes, _string_field(row, :order_class, ""));
        push!(position_intents, _string_or_missing(row, :position_intent));
        push!(qtys, _float_or_missing(row, :qty));
        push!(filled_qtys, _float_field(row, :filled_qty, 0.0));
        push!(limit_prices, _float_or_missing(row, :limit_price));
        push!(stop_prices, _float_or_missing(row, :stop_price));
        push!(filled_avg_prices, _float_or_missing(row, :filled_avg_price));
        push!(statuses, String(row.status));
        push!(created_ats, _parse_utc(get(row, :created_at, nothing)));
        push!(submitted_ats, _parse_utc(get(row, :submitted_at, nothing)));
        push!(filled_ats, _parse_utc(get(row, :filled_at, nothing)));
    end

    # put the columns into a table, and return it -
    return DataFrame(id = ids, parent_id = parent_ids, client_order_id = client_order_ids, symbol = symbols,
        asset_class = asset_classes, side = sides, type = types, time_in_force = time_in_forces,
        order_class = order_classes, position_intent = position_intents, qty = qtys, filled_qty = filled_qtys,
        limit_price = limit_prices, stop_price = stop_prices, filled_avg_price = filled_avg_prices,
        status = statuses, created_at = created_ats, submitted_at = submitted_ats, filled_at = filled_ats);
end

"""
    _default_handler(model::Type{MyOrdersEndpointModel}, body::String) -> DataFrame

Process the response of the `/orders` endpoint. The table lists each multi-leg parent and then one row for each leg,
with the columns of `_orders_table`.
"""
function _default_handler(model::Type{MyOrdersEndpointModel}, body::String)::DataFrame
    return _orders_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyOrderEndpointModel}, body::String) -> DataFrame

Process the response of the `/orders/{order_id}` endpoint. The table lists the order and then one row for each leg,
with the columns of `_orders_table`.
"""
function _default_handler(model::Type{MyOrderEndpointModel}, body::String)::DataFrame
    return _orders_table(_json_records(body, String[]));
end

"""
    _option_contracts_table(records::Vector{Any}) -> DataFrame

Build the option contracts table from a vector of contract records. The columns are `id`, `symbol`, `name`, `status`,
`tradable`, `expiration_date`, `root_symbol`, `underlying_symbol`, `underlying_asset_id`, `type`, `style`,
`strike_price`, `multiplier`, `size`, `open_interest`, `open_interest_date`, `close_price`, and `close_price_date`.
The open interest and close price columns, and their dates, are `missing` when Alpaca sends no value.
"""
function _option_contracts_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    symbols = Array{String,1}();
    contract_names = Array{String,1}();
    statuses = Array{String,1}();
    tradables = Array{Bool,1}();
    expiration_dates = Array{Date,1}();
    root_symbols = Array{String,1}();
    underlying_symbols = Array{String,1}();
    underlying_asset_ids = Array{String,1}();
    types = Array{String,1}();
    styles = Array{String,1}();
    strike_prices = Array{Float64,1}();
    multipliers = Array{Float64,1}();
    sizes = Array{Float64,1}();
    open_interests = Array{Union{Missing,Float64},1}();
    open_interest_dates = Array{Union{Missing,Date},1}();
    close_prices = Array{Union{Missing,Float64},1}();
    close_price_dates = Array{Union{Missing,Date},1}();

    # visit the records, and select the fields we want -
    for record in records
        underlying_symbol = String(record.underlying_symbol);
        push!(ids, String(record.id));
        push!(symbols, String(record.symbol));
        push!(contract_names, _string_field(record, :name, ""));
        push!(statuses, _string_field(record, :status, ""));
        push!(tradables, _bool_field(record, :tradable, false));
        push!(expiration_dates, Date(String(record.expiration_date)));
        push!(root_symbols, _string_field(record, :root_symbol, underlying_symbol));
        push!(underlying_symbols, underlying_symbol);
        push!(underlying_asset_ids, _string_field(record, :underlying_asset_id, ""));
        push!(types, String(record.type));
        push!(styles, _string_field(record, :style, "american"));
        push!(strike_prices, _float_field(record, :strike_price, 0.0));
        push!(multipliers, _float_field(record, :multiplier, 100.0));
        push!(sizes, _float_field(record, :size, 100.0));
        push!(open_interests, _float_or_missing(record, :open_interest));
        push!(open_interest_dates, _date_or_missing(record, :open_interest_date));
        push!(close_prices, _float_or_missing(record, :close_price));
        push!(close_price_dates, _date_or_missing(record, :close_price_date));
    end

    # put the columns into a table, and return it -
    return DataFrame(id = ids, symbol = symbols, name = contract_names, status = statuses, tradable = tradables,
        expiration_date = expiration_dates, root_symbol = root_symbols, underlying_symbol = underlying_symbols,
        underlying_asset_id = underlying_asset_ids, type = types, style = styles, strike_price = strike_prices,
        multiplier = multipliers, size = sizes, open_interest = open_interests,
        open_interest_date = open_interest_dates, close_price = close_prices, close_price_date = close_price_dates);
end

"""
    _default_handler(model::Type{MyOptionContractsEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/contracts` endpoint. The contracts are under the `option_contracts` key
(or `contracts`). The table has one row for each contract, with the columns of `_option_contracts_table`.
"""
function _default_handler(model::Type{MyOptionContractsEndpointModel}, body::String)::DataFrame
    return _option_contracts_table(_json_records(body, String["option_contracts", "contracts"]));
end

"""
    _default_handler(model::Type{MyOptionContractEndpointModel}, body::String) -> DataFrame

Process the response of the `/options/contracts/{symbol_or_id}` endpoint. The table has one row, with the columns of
`_option_contracts_table`.
"""
function _default_handler(model::Type{MyOptionContractEndpointModel}, body::String)::DataFrame
    return _option_contracts_table(_json_records(body, String[]));
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
