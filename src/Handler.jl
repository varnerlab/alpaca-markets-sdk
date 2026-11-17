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

            # a list key that holds JSON null means there are no records -
            if (parsed[Symbol(key)] === nothing)
                return records;
            end
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
# _text_or_missing: an optional value that Alpaca can send as text or as a number (e.g., a trade id), kept as text -
function _text_or_missing(record, key::Symbol)::Union{Missing,String}

    # look up the field -
    value = get(record, key, nothing);
    if (value === nothing)
        return missing;
    end
    return string(value);
end

# _int_or_missing: an optional whole number; missing when there is no value -
function _int_or_missing(record, key::Symbol)::Union{Missing,Int}

    # parse the field as a number, and round it to a whole number -
    value = _parse_float(get(record, key, nothing));
    if (value === nothing)
        return missing;
    end
    return Int(round(value));
end

# _as_record: a record that is absent or null has no fields, so every lookup on it finds no value -
function _as_record(record)
    if (record === nothing)
        return Dict{Symbol,Any}();
    end
    return record;
end

"""
    _symbol_records(container) -> Tuple{Vector{Union{Missing,String}}, Vector{Any}}

Flatten a JSON object that maps a symbol to a record, or to a list of records, into two vectors of the same length:
the symbol of each record, and the record. The rows follow the order of the JSON object, and the order of each list.
A `container` that is `nothing` (a `null` in the response), or an entry that is not an object or a list, adds no rows.
"""
function _symbol_records(container)::Tuple{Vector{Union{Missing,String}},Vector{Any}}

    # initialize: the symbol and the record of each row -
    symbols = Union{Missing,String}[];
    records = Any[];
    if (container === nothing)
        return (symbols, records);
    end

    # visit the symbols in the order of the response -
    for (key, value) in pairs(container)
        if (value isa JSON3.Array)
            for record in value
                push!(symbols, String(key));
                push!(records, record);
            end
        elseif (value isa JSON3.Object)
            push!(symbols, String(key));
            push!(records, value);
        end
    end
    return (symbols, records);
end

# _symbol_records_under: the symbol records under one key of the response body -
function _symbol_records_under(body::String, key::Symbol)::Tuple{Vector{Union{Missing,String}},Vector{Any}}
    return _symbol_records(get(JSON3.read(body), key, nothing));
end

# _latest_stock_records: the one record under `key` of a latest stock response, and the top-level symbol (or missing) -
function _latest_stock_records(body::String, key::Symbol)::Tuple{Vector{Union{Missing,String}},Vector{Any}}

    # a latest stock response holds one record, and may name its symbol at the top level -
    parsed = JSON3.read(body);
    symbols = Union{Missing,String}[];
    records = Any[];
    record = get(parsed, key, nothing);
    if (record !== nothing)
        push!(symbols, _string_or_missing(parsed, :symbol));
        push!(records, record);
    end
    return (symbols, records);
end

# _option_snapshot_records: the snapshots of a snapshots response (stock or option), under the `snapshots` key or unwrapped -
function _option_snapshot_records(body::String)::Tuple{Vector{Union{Missing,String}},Vector{Any}}

    # the snapshots are under a key, or the response is the object of snapshots itself -
    parsed = JSON3.read(body);
    if (haskey(parsed, :snapshots) == true)
        return _symbol_records(parsed[:snapshots]);
    end
    return _symbol_records(parsed);
end

"""
    _bars_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any}) -> DataFrame

Build the bars table, one row for each bar record. The columns are `timestamp`, `symbol`, `open`, `high`, `low`,
`close`, `volume`, `trade_count`, and `vwap`. A field that Alpaca does not send is `missing`.
"""
function _bars_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    timestamps = Array{Union{Missing,DateTime},1}();
    opens = Array{Union{Missing,Float64},1}();
    highs = Array{Union{Missing,Float64},1}();
    lows = Array{Union{Missing,Float64},1}();
    closes = Array{Union{Missing,Float64},1}();
    volumes = Array{Union{Missing,Float64},1}();
    trade_counts = Array{Union{Missing,Int},1}();
    vwaps = Array{Union{Missing,Float64},1}();

    # visit the records, and select the fields we want -
    for item in records
        record = _as_record(item);
        push!(timestamps, _parse_utc(get(record, :t, nothing)));
        push!(opens, _float_or_missing(record, :o));
        push!(highs, _float_or_missing(record, :h));
        push!(lows, _float_or_missing(record, :l));
        push!(closes, _float_or_missing(record, :c));
        push!(volumes, _float_or_missing(record, :v));
        push!(trade_counts, _int_or_missing(record, :n));
        push!(vwaps, _float_or_missing(record, :vw));
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = timestamps, symbol = symbols, open = opens, high = highs, low = lows,
        close = closes, volume = volumes, trade_count = trade_counts, vwap = vwaps);
end

"""
    _quotes_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any}) -> DataFrame

Build the quotes table, one row for each quote record. The columns are `timestamp`, `symbol`, `bid_price`,
`bid_size`, `ask_price`, `ask_size`, `bid_exchange`, and `ask_exchange`. A field that Alpaca does not send is `missing`.
"""
function _quotes_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    timestamps = Array{Union{Missing,DateTime},1}();
    bid_prices = Array{Union{Missing,Float64},1}();
    bid_sizes = Array{Union{Missing,Float64},1}();
    ask_prices = Array{Union{Missing,Float64},1}();
    ask_sizes = Array{Union{Missing,Float64},1}();
    bid_exchanges = Array{Union{Missing,String},1}();
    ask_exchanges = Array{Union{Missing,String},1}();

    # visit the records, and select the fields we want -
    for item in records
        record = _as_record(item);
        push!(timestamps, _parse_utc(get(record, :t, nothing)));
        push!(bid_prices, _float_or_missing(record, :bp));
        push!(bid_sizes, _float_or_missing(record, :bs));
        push!(ask_prices, _float_or_missing(record, :ap));
        push!(ask_sizes, _float_or_missing(record, :as));
        push!(bid_exchanges, _text_or_missing(record, :bx));
        push!(ask_exchanges, _text_or_missing(record, :ax));
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = timestamps, symbol = symbols, bid_price = bid_prices, bid_size = bid_sizes,
        ask_price = ask_prices, ask_size = ask_sizes, bid_exchange = bid_exchanges, ask_exchange = ask_exchanges);
end

"""
    _trades_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any}) -> DataFrame

Build the trades table, one row for each trade record. The columns are `timestamp`, `symbol`, `price`, `size`,
`exchange`, and `id`. The `id` is a whole number. A field that Alpaca does not send is `missing`.
"""
function _trades_table(symbols::Vector{Union{Missing,String}}, records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    timestamps = Array{Union{Missing,DateTime},1}();
    prices = Array{Union{Missing,Float64},1}();
    sizes = Array{Union{Missing,Float64},1}();
    exchanges = Array{Union{Missing,String},1}();
    ids = Array{Union{Missing,Int},1}();

    # visit the records, and select the fields we want -
    for item in records
        record = _as_record(item);
        push!(timestamps, _parse_utc(get(record, :t, nothing)));
        push!(prices, _float_or_missing(record, :p));
        push!(sizes, _float_or_missing(record, :s));
        push!(exchanges, _text_or_missing(record, :x));
        push!(ids, _int_or_missing(record, :i));
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = timestamps, symbol = symbols, price = prices, size = sizes,
        exchange = exchanges, id = ids);
end

"""
    _snapshots_table(symbols::Vector{Union{Missing,String}}, snapshots::Vector{Any}, with_greeks::Bool) -> DataFrame

Build the snapshots table, one row for each snapshot. The columns are `symbol`, then the columns of the trades,
quotes, and bars tables (without `symbol`) for the `latestTrade`, `latestQuote`, `minuteBar`, `dailyBar`, and
`prevDailyBar` objects, with the prefixes `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, and
`prev_daily_bar_`. An object that is absent makes every column of its group `missing`. When `with_greeks` is `true`
(option snapshots), the columns `implied_volatility`, `delta`, `gamma`, `theta`, `vega`, and `rho` follow.
"""
function _snapshots_table(symbols::Vector{Union{Missing,String}}, snapshots::Vector{Any}, with_greeks::Bool)::DataFrame

    # the groups of a snapshot: the key in the response, the column prefix, and the kind of table -
    group_keys = [:latestTrade, :latestQuote, :minuteBar, :dailyBar, :prevDailyBar];
    prefixes = ["latest_trade_", "latest_quote_", "minute_bar_", "daily_bar_", "prev_daily_bar_"];
    kinds = ["trade", "quote", "bar", "bar", "bar"];

    # start the table with the symbol column -
    table = DataFrame(symbol = symbols);

    # build the table of each group, prefix its columns, and add it to the right of the others -
    for i in eachindex(group_keys)
        group_records = Any[];
        for snapshot in snapshots
            push!(group_records, get(snapshot, group_keys[i], nothing));
        end

        # the group table has the same rows as the snapshots, and its symbol column is dropped -
        group = DataFrame();
        if (kinds[i] == "trade")
            group = _trades_table(symbols, group_records);
        elseif (kinds[i] == "quote")
            group = _quotes_table(symbols, group_records);
        else
            group = _bars_table(symbols, group_records);
        end
        select!(group, Not(:symbol));
        for name in names(group)
            rename!(group, name => prefixes[i] * name);
        end
        table = hcat(table, group);
    end

    # option snapshots also carry the implied volatility and the greeks -
    if (with_greeks == true)
        implied_volatilities = Array{Union{Missing,Float64},1}();
        deltas = Array{Union{Missing,Float64},1}();
        gammas = Array{Union{Missing,Float64},1}();
        thetas = Array{Union{Missing,Float64},1}();
        vegas = Array{Union{Missing,Float64},1}();
        rhos = Array{Union{Missing,Float64},1}();
        for snapshot in snapshots
            greeks = _as_record(get(snapshot, :greeks, nothing));
            push!(implied_volatilities, _float_or_missing(snapshot, :impliedVolatility));
            push!(deltas, _float_or_missing(greeks, :delta));
            push!(gammas, _float_or_missing(greeks, :gamma));
            push!(thetas, _float_or_missing(greeks, :theta));
            push!(vegas, _float_or_missing(greeks, :vega));
            push!(rhos, _float_or_missing(greeks, :rho));
        end
        table.implied_volatility = implied_volatilities;
        table.delta = deltas;
        table.gamma = gammas;
        table.theta = thetas;
        table.vega = vegas;
        table.rho = rhos;
    end
    return table;
end

"""
    _default_handler(model::Type{MyStockBarsEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/bars` endpoint. The records are under the `bars` key, grouped by symbol. The table has one
row for each record, with the columns of `_bars_table`. A `null` or empty `bars` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockBarsEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockQuotesEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/quotes` endpoint. The records are under the `quotes` key, grouped by symbol. The table has one
row for each record, with the columns of `_quotes_table`. A `null` or empty `quotes` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockQuotesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :quotes);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockTradesEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/trades` endpoint. The records are under the `trades` key, grouped by symbol. The table has one
row for each record, with the columns of `_trades_table`. A `null` or empty `trades` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockTradesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :trades);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionBarsEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/bars` endpoint. The records are under the `bars` key, grouped by symbol. The table has one
row for each record, with the columns of `_bars_table`. A `null` or empty `bars` object gives a table with no rows.
"""
function _default_handler(model::Type{MyOptionBarsEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionQuotesEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/quotes` endpoint. The records are under the `quotes` key, grouped by symbol. The table has one
row for each record, with the columns of `_quotes_table`. A `null` or empty `quotes` object gives a table with no rows.
"""
function _default_handler(model::Type{MyOptionQuotesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :quotes);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionTradesEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/trades` endpoint. The records are under the `trades` key, grouped by symbol. The table has one
row for each record, with the columns of `_trades_table`. A `null` or empty `trades` object gives a table with no rows.
"""
function _default_handler(model::Type{MyOptionTradesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :trades);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockLatestBarEndpointModel}, body::String) -> DataFrame

Process the response of the latest bar endpoint for one stock. The table has one row, with the columns of
`_bars_table`. The `symbol` is the top-level `symbol` key of the response, or `missing` when the response has none.
"""
function _default_handler(model::Type{MyStockLatestBarEndpointModel}, body::String)::DataFrame
    (symbols, records) = _latest_stock_records(body, :bar);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockLatestQuoteEndpointModel}, body::String) -> DataFrame

Process the response of the latest quote endpoint for one stock. The table has one row, with the columns of
`_quotes_table`. The `symbol` is the top-level `symbol` key of the response, or `missing` when the response has none.
"""
function _default_handler(model::Type{MyStockLatestQuoteEndpointModel}, body::String)::DataFrame
    (symbols, records) = _latest_stock_records(body, :quote);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockLatestTradeEndpointModel}, body::String) -> DataFrame

Process the response of the latest trade endpoint for one stock. The table has one row, with the columns of
`_trades_table`. The `symbol` is the top-level `symbol` key of the response, or `missing` when the response has none.
"""
function _default_handler(model::Type{MyStockLatestTradeEndpointModel}, body::String)::DataFrame
    (symbols, records) = _latest_stock_records(body, :trade);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionLatestBarEndpointModel}, body::String) -> DataFrame

Process the response of the latest bar endpoint for option contracts. The records are under the `bars` key,
one for each symbol. The table has one row for each symbol, with the columns of `_bars_table`.
"""
function _default_handler(model::Type{MyOptionLatestBarEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionLatestQuoteEndpointModel}, body::String) -> DataFrame

Process the response of the latest quote endpoint for option contracts. The records are under the `quotes` key,
one for each symbol. The table has one row for each symbol, with the columns of `_quotes_table`.
"""
function _default_handler(model::Type{MyOptionLatestQuoteEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :quotes);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionLatestTradeEndpointModel}, body::String) -> DataFrame

Process the response of the latest trade endpoint for option contracts. The records are under the `trades` key,
one for each symbol. The table has one row for each symbol, with the columns of `_trades_table`.
"""
function _default_handler(model::Type{MyOptionLatestTradeEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :trades);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockSnapshotsEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/snapshots` endpoint. The snapshots are the top-level keys of the response, one
for each symbol (a `snapshots` wrapper key is also accepted). The table has one row for each symbol, with the columns of `_snapshots_table` (without the greeks).
"""
function _default_handler(model::Type{MyStockSnapshotsEndpointModel}, body::String)::DataFrame
    (symbols, snapshots) = _option_snapshot_records(body);
    return _snapshots_table(symbols, snapshots, false);
end

"""
    _default_handler(model::Type{MyOptionSnapshotsEndpointModel}, body::String) -> DataFrame

Process the response of the `/options/snapshots` endpoint. The snapshots are under the `snapshots` key, or are the
top-level keys of the response. The table has one row for each symbol, with the columns of `_snapshots_table`
(with the greeks).
"""
function _default_handler(model::Type{MyOptionSnapshotsEndpointModel}, body::String)::DataFrame
    (symbols, snapshots) = _option_snapshot_records(body);
    return _snapshots_table(symbols, snapshots, true);
end

"""
    _default_handler(model::Type{MyOptionChainEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/snapshots/{underlying}` endpoint. The table has one row for each option contract,
with the columns of `_snapshots_table` (with the greeks).
"""
function _default_handler(model::Type{MyOptionChainEndpointModel}, body::String)::DataFrame
    (symbols, snapshots) = _option_snapshot_records(body);
    return _snapshots_table(symbols, snapshots, true);
end

# --- Legacy handlers: return the legacy structs of v0.3.1 -------------------------------------------------------- #

# _maybe_string: a text value that can be null; nothing when the value is nothing -
function _maybe_string(value)
    if (value === nothing)
        return nothing;
    end
    return String(value);
end

# _parse_cal_time: Alpaca sends the regular session times of /calendar as "HH:MM" and the extended session times as
# "HHMM" (no colon). This function reads both forms -
function _parse_cal_time(text::AbstractString)::Time

    # a time with a colon is already in the form that Time reads -
    if (occursin(':', text) == true)
        return Time(text);
    end

    # a time without a colon has the hour in the first two characters and the minute in the next two -
    return Time(text[1:2] * ":" * text[3:4]);
end

"""
    _parse_account(record::JSON3.Object) -> Account

Build an `Account` from one record of the `/account` endpoint. The `Account` keeps the record in its `raw` field.
"""
function _parse_account(record::JSON3.Object)::Account
    return Account(
        String(record.id),
        String(record.account_number),
        String(record.status),
        String(record.currency),
        _parse_float_default(get(record, :cash, "0")),
        _parse_float_default(get(record, :buying_power, "0")),
        _parse_float_default(get(record, :portfolio_value, "0")),
        _parse_float_default(get(record, :equity, "0")),
        _parse_float_default(get(record, :last_equity, "0")),
        Bool(get(record, :pattern_day_trader, false)),
        Bool(get(record, :trading_blocked, false)),
        Bool(get(record, :transfers_blocked, false)),
        Bool(get(record, :account_blocked, false)),
        record,
    );
end

"""
    _parse_asset(record::JSON3.Object) -> Asset

Build an `Asset` from one record of the `/assets` endpoint. The `Asset` keeps the record in its `raw` field.
"""
function _parse_asset(record::JSON3.Object)::Asset
    return Asset(
        String(record.id),
        String(record.class),
        String(record.exchange),
        String(record.symbol),
        String(get(record, :name, "")),
        String(record.status),
        Bool(get(record, :tradable, false)),
        Bool(get(record, :marginable, false)),
        Bool(get(record, :shortable, false)),
        Bool(get(record, :easy_to_borrow, false)),
        Bool(get(record, :fractionable, false)),
        record,
    );
end

"""
    _parse_position(record::JSON3.Object) -> Position

Build a `Position` from one record of the `/positions` endpoint. The `Position` keeps the record in its `raw` field.
"""
function _parse_position(record::JSON3.Object)::Position
    return Position(
        String(record.asset_id),
        String(record.symbol),
        String(get(record, :exchange, "")),
        String(get(record, :asset_class, "us_equity")),
        _parse_float_default(get(record, :qty, "0")),
        String(get(record, :side, "long")),
        _parse_float_default(get(record, :avg_entry_price, "0")),
        _parse_float_default(get(record, :market_value, "0")),
        _parse_float_default(get(record, :cost_basis, "0")),
        _parse_float_default(get(record, :unrealized_pl, "0")),
        _parse_float_default(get(record, :unrealized_plpc, "0")),
        _parse_float_default(get(record, :current_price, "0")),
        _parse_float_default(get(record, :lastday_price, "0")),
        _parse_float_default(get(record, :change_today, "0")),
        record,
    );
end

"""
    _parse_legs(legs) -> Union{Nothing,Vector{Order}}

Build the child `Order` values of a multi-leg order. The result is `nothing` when the response has no legs.
"""
function _parse_legs(legs)::Union{Nothing,Vector{Order}}

    # a response without legs, or with an empty list of legs, has no child orders -
    if (legs === nothing)
        return nothing;
    end
    if (isempty(legs) == true)
        return nothing;
    end

    # build one Order for each leg -
    leg_orders = Order[];
    for leg in legs
        push!(leg_orders, _parse_order(leg));
    end
    return leg_orders;
end

"""
    _parse_order(record::JSON3.Object) -> Order

Build an `Order` from one record of the `/orders` endpoint. The `Order` keeps the record in its `raw` field.
"""
function _parse_order(record::JSON3.Object)::Order
    return Order(
        String(record.id),
        String(get(record, :client_order_id, "")),
        _maybe_string(get(record, :symbol, nothing)),
        String(get(record, :asset_class, "us_equity")),
        _maybe_string(get(record, :side, nothing)),
        String(record.type),
        String(record.time_in_force),
        String(get(record, :order_class, "")),
        _maybe_string(get(record, :position_intent, nothing)),
        _parse_float(get(record, :qty, nothing)),
        _parse_float_default(get(record, :filled_qty, "0")),
        _parse_float(get(record, :limit_price, nothing)),
        _parse_float(get(record, :stop_price, nothing)),
        _parse_float(get(record, :filled_avg_price, nothing)),
        String(record.status),
        _parse_rfc3339(get(record, :created_at, nothing)),
        _parse_rfc3339(get(record, :submitted_at, nothing)),
        _parse_rfc3339(get(record, :filled_at, nothing)),
        _parse_legs(get(record, :legs, nothing)),
        record,
    );
end

"""
    _parse_option_contract(record::JSON3.Object) -> OptionContract

Build an `OptionContract` from one record of the `/options/contracts` endpoint. The `OptionContract` keeps the
record in its `raw` field.
"""
function _parse_option_contract(record::JSON3.Object)::OptionContract
    return OptionContract(
        String(record.id),
        String(record.symbol),
        String(get(record, :name, "")),
        String(get(record, :status, "")),
        Bool(get(record, :tradable, false)),
        Date(String(record.expiration_date)),
        String(get(record, :root_symbol, get(record, :underlying_symbol, ""))),
        String(record.underlying_symbol),
        String(get(record, :underlying_asset_id, "")),
        String(record.type),
        String(get(record, :style, "american")),
        _parse_float_default(get(record, :strike_price, "0")),
        _parse_float_default(get(record, :multiplier, "100")),
        _parse_float_default(get(record, :size, "100")),
        _parse_float(get(record, :open_interest, nothing)),
        _parse_date_maybe(get(record, :open_interest_date, nothing)),
        _parse_float(get(record, :close_price, nothing)),
        _parse_date_maybe(get(record, :close_price_date, nothing)),
        record,
    );
end

"""
    _legacy_handler(model::Type, body::String)

The handlers that return the legacy values of v0.3.1 instead of a `DataFrame`. The legacy functions pass these
handlers to `api`. Each method receives the type of the endpoint model and the body of one response.
"""
function _legacy_handler end

# _legacy_handler: /account returns one Account -
function _legacy_handler(model::Type{MyAccountEndpointModel}, body::String)::Account
    return _parse_account(JSON3.read(body));
end

# _legacy_handler: /clock returns one MarketClock -
function _legacy_handler(model::Type{MyClockEndpointModel}, body::String)::MarketClock
    record = JSON3.read(body);
    return MarketClock(
        _parse_rfc3339(String(record.timestamp)),
        Bool(record.is_open),
        _parse_rfc3339(String(record.next_open)),
        _parse_rfc3339(String(record.next_close)),
    );
end

# _legacy_handler: /calendar returns one CalendarDay for each trading day -
function _legacy_handler(model::Type{MyCalendarEndpointModel}, body::String)::Vector{CalendarDay}

    # build one CalendarDay for each record. The session times are optional -
    days = CalendarDay[];
    for record in JSON3.read(body)
        session_open = nothing;
        if (haskey(record, :session_open) == true)
            session_open = _parse_cal_time(String(record.session_open));
        end
        session_close = nothing;
        if (haskey(record, :session_close) == true)
            session_close = _parse_cal_time(String(record.session_close));
        end
        push!(days, CalendarDay(
            Date(String(record.date)),
            _parse_cal_time(String(record.open)),
            _parse_cal_time(String(record.close)),
            session_open,
            session_close,
        ));
    end
    return days;
end

# _legacy_handler: /assets returns one Asset for each asset. The handler does not filter on tradable -
function _legacy_handler(model::Type{MyAssetsEndpointModel}, body::String)::Vector{Asset}
    assets = Asset[];
    for record in JSON3.read(body)
        push!(assets, _parse_asset(record));
    end
    return assets;
end

# _legacy_handler: /assets/{symbol} returns one Asset -
function _legacy_handler(model::Type{MyAssetEndpointModel}, body::String)::Asset
    return _parse_asset(JSON3.read(body));
end

# _legacy_handler: /positions returns one Position for each open position -
function _legacy_handler(model::Type{MyPositionsEndpointModel}, body::String)::Vector{Position}
    positions = Position[];
    for record in JSON3.read(body)
        push!(positions, _parse_position(record));
    end
    return positions;
end

# _legacy_handler: /positions/{symbol} returns one Position -
function _legacy_handler(model::Type{MyPositionEndpointModel}, body::String)::Position
    return _parse_position(JSON3.read(body));
end

# _legacy_handler: /orders returns one Order for each order -
function _legacy_handler(model::Type{MyOrdersEndpointModel}, body::String)::Vector{Order}
    orders = Order[];
    for record in JSON3.read(body)
        push!(orders, _parse_order(record));
    end
    return orders;
end

# _legacy_handler: /orders/{id} and /orders:by_client_order_id return one Order -
function _legacy_handler(model::Type{MyOrderEndpointModel}, body::String)::Order
    return _parse_order(JSON3.read(body));
end

# _legacy_handler: /options/contracts returns one OptionContract for each contract on the page -
function _legacy_handler(model::Type{MyOptionContractsEndpointModel}, body::String)::Vector{OptionContract}
    contracts = OptionContract[];
    for record in _json_records(body, String["option_contracts", "contracts"])
        push!(contracts, _parse_option_contract(record));
    end
    return contracts;
end

# _legacy_handler: /options/contracts/{symbol} returns one OptionContract -
function _legacy_handler(model::Type{MyOptionContractEndpointModel}, body::String)::OptionContract
    return _parse_option_contract(JSON3.read(body));
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
