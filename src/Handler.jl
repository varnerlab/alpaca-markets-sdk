# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
# The default handlers live in the private section below. A handler receives the type of the endpoint model and
# the body of a response as a String, and returns a DataFrame with one row for each record.
# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
# _empty_table: the handler result of a write that Alpaca answers with no body -
function _empty_table(body::String)::DataFrame
    return DataFrame();
end

# _is_time_column: true when the name of a column holds a timestamp that _records_table parses -
function _is_time_column(name::String)::Bool
    if (endswith(name, "_at") == true)
        return true;
    end
    if (name == "timestamp" || name == "transaction_time" || name == "t")
        return true;
    end
    return false;
end

# _record_value: one JSON value as a table cell. A number is a Float64, text in a time column is a UTC DateTime,
# an array or a deeper object is its JSON text, and null is missing -
function _record_value(name::String, value)
    if (value === nothing)
        return missing;
    end
    if (value isa Bool)
        return value;
    end
    if (value isa Number)
        return Float64(value);
    end
    if (value isa AbstractString)
        if (_is_time_column(name) == true)
            return _parse_utc(String(value));
        end
        return String(value);
    end
    return JSON3.write(value);
end

"""
    _records_table(records::Vector{Any}) -> DataFrame

Build a table from records whose fields differ by type, e.g., account activities or watchlists.
The columns are the union of the record keys, in first-seen order, and a field that a record lacks is `missing`.
A nested object is flattened one level with the prefix `<key>_`, and an array becomes its JSON text.
Text in a field whose name ends with `_at`, or is `timestamp`, `transaction_time` or `t`, becomes a UTC `DateTime`.
Every other value keeps its JSON type (`String`, `Float64` for any number, `Bool`), and `null` is `missing`.

### Arguments
- `records::Vector{Any}`: the parsed JSON objects, one for each row.

### Returns
- `DataFrame`: one row for each record. No records give an empty table with no columns.
"""
function _records_table(records::Vector{Any})::DataFrame

    # flatten each record into (column name, value) pairs, and collect the column names in first-seen order -
    flat_records = Vector{Dict{String,Any}}();
    column_names = String[];
    for record in records
        flat = Dict{String,Any}();
        for (key, value) in pairs(record)
            name = String(key);

            # a nested object is flattened one level -
            if (value isa JSON3.Object)
                for (inner_key, inner_value) in pairs(value)
                    inner_name = name * "_" * String(inner_key);
                    flat[inner_name] = _record_value(inner_name, inner_value);
                    if ((inner_name in column_names) == false)
                        push!(column_names, inner_name);
                    end
                end
            else
                flat[name] = _record_value(name, value);
                if ((name in column_names) == false)
                    push!(column_names, name);
                end
            end
        end
        push!(flat_records, flat);
    end

    # one column for each name, with missing where a record lacks the field -
    table = DataFrame();
    for name in column_names
        column = Any[];
        for flat in flat_records
            push!(column, get(flat, name, missing));
        end
        table[!, Symbol(name)] = identity.(column);
    end
    return table;
end
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

# _string_or_missing: an optional text field; missing when the field is missing or null -
function _string_or_missing(record, key::Symbol)::Union{Missing,String}

    # look up the field -
    value = get(record, key, nothing);
    if (value === nothing)
        return missing;
    end
    return String(value);
end

# _float_or_missing: a number that Alpaca sends as text or as a number; missing when there is no value -
function _float_or_missing(record, key::Symbol)::Union{Missing,Float64}

    # parse the field -
    value = _parse_float(get(record, key, nothing));
    if (value === nothing)
        return missing;
    end
    return value;
end

# _bool_or_missing: a true or false flag; missing when the field is missing or null -
function _bool_or_missing(record, key::Symbol)::Union{Missing,Bool}

    # look up the field -
    value = get(record, key, nothing);
    if (value === nothing)
        return missing;
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
`trading_blocked`, `transfers_blocked`, and `account_blocked`. The money columns are `Float64`. A field that Alpaca
does not send is `missing`.
"""
function _default_handler(model::Type{MyAccountEndpointModel}, body::String)::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    account_numbers = Array{String,1}();
    statuses = Array{String,1}();
    currencies = Array{String,1}();
    cashes = Array{Union{Missing,Float64},1}();
    buying_powers = Array{Union{Missing,Float64},1}();
    portfolio_values = Array{Union{Missing,Float64},1}();
    equities = Array{Union{Missing,Float64},1}();
    last_equities = Array{Union{Missing,Float64},1}();
    pattern_day_traders = Array{Union{Missing,Bool},1}();
    trading_blockeds = Array{Union{Missing,Bool},1}();
    transfers_blockeds = Array{Union{Missing,Bool},1}();
    account_blockeds = Array{Union{Missing,Bool},1}();

    # visit the records, and select the fields we want -
    for record in _json_records(body, String[])
        push!(ids, String(record.id));
        push!(account_numbers, String(record.account_number));
        push!(statuses, String(record.status));
        push!(currencies, String(record.currency));
        push!(cashes, _float_or_missing(record, :cash));
        push!(buying_powers, _float_or_missing(record, :buying_power));
        push!(portfolio_values, _float_or_missing(record, :portfolio_value));
        push!(equities, _float_or_missing(record, :equity));
        push!(last_equities, _float_or_missing(record, :last_equity));
        push!(pattern_day_traders, _bool_or_missing(record, :pattern_day_trader));
        push!(trading_blockeds, _bool_or_missing(record, :trading_blocked));
        push!(transfers_blockeds, _bool_or_missing(record, :transfers_blocked));
        push!(account_blockeds, _bool_or_missing(record, :account_blocked));
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
`next_open`, and `next_close`. The three times are `DateTime` values in UTC. A field that Alpaca does not send is `missing`.
"""
function _default_handler(model::Type{MyClockEndpointModel}, body::String)::DataFrame

    # initialize: one array for each column of the table -
    timestamps = Array{Union{Missing,DateTime},1}();
    is_opens = Array{Union{Missing,Bool},1}();
    next_opens = Array{Union{Missing,DateTime},1}();
    next_closes = Array{Union{Missing,DateTime},1}();

    # visit the records, and convert the times to UTC -
    for record in _json_records(body, String[])
        push!(timestamps, _parse_utc(get(record, :timestamp, nothing)));
        push!(is_opens, _bool_or_missing(record, :is_open));
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
A field that Alpaca does not send is `missing`.
"""
function _assets_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    classes = Array{String,1}();
    exchanges = Array{String,1}();
    symbols = Array{String,1}();
    asset_names = Array{Union{Missing,String},1}();
    statuses = Array{String,1}();
    tradables = Array{Union{Missing,Bool},1}();
    marginables = Array{Union{Missing,Bool},1}();
    shortables = Array{Union{Missing,Bool},1}();
    easy_to_borrows = Array{Union{Missing,Bool},1}();
    fractionables = Array{Union{Missing,Bool},1}();

    # visit the records, and select the fields we want -
    for record in records
        push!(ids, String(record.id));
        push!(classes, String(record.class));
        push!(exchanges, String(record.exchange));
        push!(symbols, String(record.symbol));
        push!(asset_names, _string_or_missing(record, :name));
        push!(statuses, String(record.status));
        push!(tradables, _bool_or_missing(record, :tradable));
        push!(marginables, _bool_or_missing(record, :marginable));
        push!(shortables, _bool_or_missing(record, :shortable));
        push!(easy_to_borrows, _bool_or_missing(record, :easy_to_borrow));
        push!(fractionables, _bool_or_missing(record, :fractionable));
    end

    # put the columns into a table, and return it -
    return DataFrame(id = ids, class = classes, exchange = exchanges, symbol = symbols, name = asset_names,
        status = statuses, tradable = tradables, marginable = marginables, shortable = shortables,
        easy_to_borrow = easy_to_borrows, fractionable = fractionables);
end

"""
    _default_handler(model::Type{MyAssetsEndpointModel}, body::String) -> DataFrame

Process the response of the `/assets` endpoint.
The table has one row for each asset, with the columns of `_assets_table`.
"""
function _default_handler(model::Type{MyAssetsEndpointModel}, body::String)::DataFrame
    return _assets_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyAssetEndpointModel}, body::String) -> DataFrame

Process the response of the `/assets/{symbol_or_id}` endpoint.
The table has one row, with the columns of `_assets_table`.
"""
function _default_handler(model::Type{MyAssetEndpointModel}, body::String)::DataFrame
    return _assets_table(_json_records(body, String[]));
end

"""
    _positions_table(records::Vector{Any}) -> DataFrame

Build the positions table from a vector of position records. The columns are `asset_id`, `symbol`, `exchange`,
`asset_class`, `qty`, `side`, `avg_entry_price`, `market_value`, `cost_basis`, `unrealized_pl`, `unrealized_plpc`,
`current_price`, `lastday_price`, and `change_today`. The quantities and prices are `Float64`. A field that Alpaca does
not send is `missing`.
"""
function _positions_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    asset_ids = Array{String,1}();
    symbols = Array{String,1}();
    exchanges = Array{Union{Missing,String},1}();
    asset_classes = Array{Union{Missing,String},1}();
    qtys = Array{Union{Missing,Float64},1}();
    sides = Array{Union{Missing,String},1}();
    avg_entry_prices = Array{Union{Missing,Float64},1}();
    market_values = Array{Union{Missing,Float64},1}();
    cost_bases = Array{Union{Missing,Float64},1}();
    unrealized_pls = Array{Union{Missing,Float64},1}();
    unrealized_plpcs = Array{Union{Missing,Float64},1}();
    current_prices = Array{Union{Missing,Float64},1}();
    lastday_prices = Array{Union{Missing,Float64},1}();
    change_todays = Array{Union{Missing,Float64},1}();

    # visit the records, and select the fields we want -
    for record in records
        push!(asset_ids, String(record.asset_id));
        push!(symbols, String(record.symbol));
        push!(exchanges, _string_or_missing(record, :exchange));
        push!(asset_classes, _string_or_missing(record, :asset_class));
        push!(qtys, _float_or_missing(record, :qty));
        push!(sides, _string_or_missing(record, :side));
        push!(avg_entry_prices, _float_or_missing(record, :avg_entry_price));
        push!(market_values, _float_or_missing(record, :market_value));
        push!(cost_bases, _float_or_missing(record, :cost_basis));
        push!(unrealized_pls, _float_or_missing(record, :unrealized_pl));
        push!(unrealized_plpcs, _float_or_missing(record, :unrealized_plpc));
        push!(current_prices, _float_or_missing(record, :current_price));
        push!(lastday_prices, _float_or_missing(record, :lastday_price));
        push!(change_todays, _float_or_missing(record, :change_today));
    end

    # put the columns into a table, and return it -
    return DataFrame(asset_id = asset_ids, symbol = symbols, exchange = exchanges, asset_class = asset_classes,
        qty = qtys, side = sides, avg_entry_price = avg_entry_prices, market_value = market_values,
        cost_basis = cost_bases, unrealized_pl = unrealized_pls, unrealized_plpc = unrealized_plpcs,
        current_price = current_prices, lastday_price = lastday_prices, change_today = change_todays);
end

"""
    _default_handler(model::Type{MyPositionsEndpointModel}, body::String) -> DataFrame

Process the response of the `/positions` endpoint.
The table has one row for each position, with the columns of `_positions_table`.
"""
function _default_handler(model::Type{MyPositionsEndpointModel}, body::String)::DataFrame
    return _positions_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyPositionEndpointModel}, body::String) -> DataFrame

Process the response of the `/positions/{symbol_or_asset_id}` endpoint.
The table has one row, with the columns of `_positions_table`.
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
`submitted_at`, and `filled_at`. The three times are `DateTime` values in UTC. A field that Alpaca does not send is
`missing`.
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
    client_order_ids = Array{Union{Missing,String},1}();
    symbols = Array{Union{Missing,String},1}();
    asset_classes = Array{Union{Missing,String},1}();
    sides = Array{Union{Missing,String},1}();
    types = Array{String,1}();
    time_in_forces = Array{String,1}();
    order_classes = Array{Union{Missing,String},1}();
    position_intents = Array{Union{Missing,String},1}();
    qtys = Array{Union{Missing,Float64},1}();
    filled_qtys = Array{Union{Missing,Float64},1}();
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
        push!(client_order_ids, _string_or_missing(row, :client_order_id));
        push!(symbols, _string_or_missing(row, :symbol));
        push!(asset_classes, _string_or_missing(row, :asset_class));
        push!(sides, _string_or_missing(row, :side));
        push!(types, String(row.type));
        push!(time_in_forces, String(row.time_in_force));
        push!(order_classes, _string_or_missing(row, :order_class));
        push!(position_intents, _string_or_missing(row, :position_intent));
        push!(qtys, _float_or_missing(row, :qty));
        push!(filled_qtys, _float_or_missing(row, :filled_qty));
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
A field that Alpaca does not send is `missing`.
"""
function _option_contracts_table(records::Vector{Any})::DataFrame

    # initialize: one array for each column of the table -
    ids = Array{String,1}();
    symbols = Array{String,1}();
    contract_names = Array{Union{Missing,String},1}();
    statuses = Array{Union{Missing,String},1}();
    tradables = Array{Union{Missing,Bool},1}();
    expiration_dates = Array{Date,1}();
    root_symbols = Array{Union{Missing,String},1}();
    underlying_symbols = Array{String,1}();
    underlying_asset_ids = Array{Union{Missing,String},1}();
    types = Array{String,1}();
    styles = Array{Union{Missing,String},1}();
    strike_prices = Array{Union{Missing,Float64},1}();
    multipliers = Array{Union{Missing,Float64},1}();
    sizes = Array{Union{Missing,Float64},1}();
    open_interests = Array{Union{Missing,Float64},1}();
    open_interest_dates = Array{Union{Missing,Date},1}();
    close_prices = Array{Union{Missing,Float64},1}();
    close_price_dates = Array{Union{Missing,Date},1}();

    # visit the records, and select the fields we want -
    for record in records
        push!(ids, String(record.id));
        push!(symbols, String(record.symbol));
        push!(contract_names, _string_or_missing(record, :name));
        push!(statuses, _string_or_missing(record, :status));
        push!(tradables, _bool_or_missing(record, :tradable));
        push!(expiration_dates, Date(String(record.expiration_date)));
        push!(root_symbols, _string_or_missing(record, :root_symbol));
        push!(underlying_symbols, String(record.underlying_symbol));
        push!(underlying_asset_ids, _string_or_missing(record, :underlying_asset_id));
        push!(types, String(record.type));
        push!(styles, _string_or_missing(record, :style));
        push!(strike_prices, _float_or_missing(record, :strike_price));
        push!(multipliers, _float_or_missing(record, :multiplier));
        push!(sizes, _float_or_missing(record, :size));
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

Process one page of the `/stocks/bars` endpoint. The records are under the `bars` key, grouped by symbol.
The table has one row for each record, with the columns of `_bars_table`.
A `null` or empty `bars` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockBarsEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockQuotesEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/quotes` endpoint. The records are under the `quotes` key, grouped by symbol.
The table has one row for each record, with the columns of `_quotes_table`.
A `null` or empty `quotes` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockQuotesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :quotes);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockTradesEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/trades` endpoint. The records are under the `trades` key, grouped by symbol.
The table has one row for each record, with the columns of `_trades_table`.
A `null` or empty `trades` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockTradesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :trades);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionBarsEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/bars` endpoint. The records are under the `bars` key, grouped by symbol.
The table has one row for each record, with the columns of `_bars_table`.
A `null` or empty `bars` object gives a table with no rows.
"""
function _default_handler(model::Type{MyOptionBarsEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyOptionTradesEndpointModel}, body::String) -> DataFrame

Process one page of the `/options/trades` endpoint. The records are under the `trades` key, grouped by symbol.
The table has one row for each record, with the columns of `_trades_table`.
A `null` or empty `trades` object gives a table with no rows.
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

# _codes_table: the table of a response that maps each code to its name, one row for each code in response order -
function _codes_table(body::String)::DataFrame

    # visit the codes in the order of the response -
    codes = String[];
    names = String[];
    parsed = JSON3.read(body);
    for (key, value) in pairs(parsed)
        push!(codes, String(key));
        push!(names, String(value));
    end

    # put the columns into a table, and return it -
    return DataFrame(code = codes, name = names);
end

# _auction_prints!: add the prints of one auction (opening or closing) of one day to the columns of the auctions table -
function _auction_prints!(columns::Dict{Symbol,Any}, symbol::String, day, label::String, prints)

    # a day without prints of this auction adds no rows -
    if (prints === nothing)
        return nothing;
    end

    # visit the prints in the order of the response -
    for item in prints
        record = _as_record(item);
        push!(columns[:timestamp], _parse_utc(get(record, :t, nothing)));
        push!(columns[:symbol], symbol);
        push!(columns[:date], _date_or_missing(day, :d));
        push!(columns[:auction], label);
        push!(columns[:price], _float_or_missing(record, :p));
        push!(columns[:size], _int_or_missing(record, :s));
        push!(columns[:exchange], _string_or_missing(record, :x));
        push!(columns[:condition], _string_or_missing(record, :c));
    end
    return nothing;
end

# _auctions_table: the auctions table, one row for each auction print; for each day, the opening prints come first -
function _auctions_table(body::String)::DataFrame

    # initialize: one array for each column of the table -
    columns = Dict{Symbol,Any}();
    columns[:timestamp] = Array{Union{Missing,DateTime},1}();
    columns[:symbol] = Array{Union{Missing,String},1}();
    columns[:date] = Array{Union{Missing,Date},1}();
    columns[:auction] = Array{String,1}();
    columns[:price] = Array{Union{Missing,Float64},1}();
    columns[:size] = Array{Union{Missing,Int},1}();
    columns[:exchange] = Array{Union{Missing,String},1}();
    columns[:condition] = Array{Union{Missing,String},1}();

    # visit the symbols, then the days of each symbol -
    container = get(JSON3.read(body), :auctions, nothing);
    if (container !== nothing)
        for (key, days) in pairs(container)
            if (days isa JSON3.Array)
                for day in days
                    _auction_prints!(columns, String(key), day, "open", get(day, :o, nothing));
                    _auction_prints!(columns, String(key), day, "close", get(day, :c, nothing));
                end
            end
        end
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = columns[:timestamp], symbol = columns[:symbol], date = columns[:date], auction = columns[:auction],
        price = columns[:price], size = columns[:size], exchange = columns[:exchange], condition = columns[:condition]);
end

"""
    _default_handler(model::Type{MyStockLatestBarsEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/bars/latest` endpoint. The records are under the `bars` key, one for each symbol.
The table has one row for each symbol, with the columns of `_bars_table`.
A `null` or empty `bars` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockLatestBarsEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :bars);
    return _bars_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockLatestQuotesEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/quotes/latest` endpoint. The records are under the `quotes` key, one for each symbol.
The table has one row for each symbol, with the columns of `_quotes_table`.
A `null` or empty `quotes` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockLatestQuotesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :quotes);
    return _quotes_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockLatestTradesEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/trades/latest` endpoint. The records are under the `trades` key, one for each symbol.
The table has one row for each symbol, with the columns of `_trades_table`.
A `null` or empty `trades` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockLatestTradesEndpointModel}, body::String)::DataFrame
    (symbols, records) = _symbol_records_under(body, :trades);
    return _trades_table(symbols, records);
end

"""
    _default_handler(model::Type{MyStockAuctionsEndpointModel}, body::String) -> DataFrame

Process one page of the `/stocks/auctions` endpoint. The days are under the `auctions` key, grouped by symbol.
The table has one row for each auction print, with the columns of `_auctions_table`.
A `null` or empty `auctions` object gives a table with no rows.
"""
function _default_handler(model::Type{MyStockAuctionsEndpointModel}, body::String)::DataFrame
    return _auctions_table(body);
end

"""
    _default_handler(model::Type{MyStockConditionsEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/meta/conditions/{ticktype}` endpoint.
The table has the columns `code` and `name`, one row for each condition code.
"""
function _default_handler(model::Type{MyStockConditionsEndpointModel}, body::String)::DataFrame
    return _codes_table(body);
end

"""
    _default_handler(model::Type{MyStockExchangesEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/meta/exchanges` endpoint.
The table has the columns `code` and `name`, one row for each exchange code.
"""
function _default_handler(model::Type{MyStockExchangesEndpointModel}, body::String)::DataFrame
    return _codes_table(body);
end

"""
    _default_handler(model::Type{MyStockSnapshotsEndpointModel}, body::String) -> DataFrame

Process the response of the `/stocks/snapshots` endpoint. The snapshots are the top-level keys of the response, one
for each symbol (a `snapshots` wrapper key is also accepted).
The table has one row for each symbol, with the columns of `_snapshots_table` (without the greeks).
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

"""
    _default_handler(model::Type{MyAccountConfigurationsEndpointModel}, body::String) -> DataFrame

Process the response of the `/account/configurations` endpoint. The table has one row, with one column for each setting of the account.
"""
function _default_handler(model::Type{MyAccountConfigurationsEndpointModel}, body::String)::DataFrame
    return _records_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyAccountActivitiesEndpointModel}, body::String) -> DataFrame

Process the response of the `/account/activities` endpoints. The table has one row for each activity.
The activities of different types have different fields, so a field that an activity lacks is `missing`.
"""
function _default_handler(model::Type{MyAccountActivitiesEndpointModel}, body::String)::DataFrame
    return _records_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyPortfolioHistoryEndpointModel}, body::String) -> DataFrame

Process the response of the `/account/portfolio/history` endpoint. The table has one row for each timestamp.
The columns are `timestamp` (a UTC `DateTime` from Unix seconds), `equity`, `profit_loss`, `profit_loss_pct`, and `base_value`,
which holds the same value in every row. The `cashflow` object of the response is not a column.
A response with empty or null arrays gives a table with no rows and the same five columns.
"""
function _default_handler(model::Type{MyPortfolioHistoryEndpointModel}, body::String)::DataFrame

    # parse the response body -
    parsed = JSON3.read(body);

    # get the base value, which is the same in every row -
    base_value = Float64(get(parsed, :base_value, 0));

    # initialize: one array for each column of the table -
    timestamps = Array{DateTime,1}();
    equities = Array{Float64,1}();
    profit_losses = Array{Float64,1}();
    profit_loss_pcts = Array{Float64,1}();
    base_values = Array{Float64,1}();

    # null arrays are no rows; otherwise visit the rows by position -
    stamps = get(parsed, :timestamp, nothing);
    if (stamps !== nothing)
        equity = get(parsed, :equity, nothing);
        profit_loss = get(parsed, :profit_loss, nothing);
        profit_loss_pct = get(parsed, :profit_loss_pct, nothing);
        for i in eachindex(stamps)
            push!(timestamps, Dates.unix2datetime(stamps[i]));
            push!(equities, Float64(equity[i]));
            push!(profit_losses, Float64(profit_loss[i]));
            push!(profit_loss_pcts, Float64(profit_loss_pct[i]));
            push!(base_values, base_value);
        end
    end

    # put the columns into a table, and return it -
    return DataFrame(timestamp = timestamps, equity = equities, profit_loss = profit_losses,
        profit_loss_pct = profit_loss_pcts, base_value = base_values);
end

"""
    _default_handler(model::Type{MyMarketCalendarEndpointModel}, body::String) -> DataFrame

Process the response of the `/v3/calendar/{market}` endpoint. The table has one row for each calendar day.
The first column is `market`, which holds the acronym of the market in every row. The other columns are the fields of the
calendar entries, e.g., `date`, `settlement_date`, `core_start` and `core_end`.
"""
function _default_handler(model::Type{MyMarketCalendarEndpointModel}, body::String)::DataFrame

    # the calendar entries become the columns after the market -
    table = _records_table(_json_records(body, String["calendar"]));

    # read the acronym of the market, and put it first in every row -
    parsed = JSON3.read(body);
    acronym = missing;
    if (haskey(parsed, :market) == true && parsed[:market] !== nothing)
        acronym = String(get(parsed[:market], :acronym, ""));
    end
    markets = Vector{Union{Missing,String}}(fill(acronym, size(table, 1)));
    insertcols!(table, 1, :market => markets);
    return table;
end

"""
    _default_handler(model::Type{MyMarketClocksEndpointModel}, body::String) -> DataFrame

Process the response of the `/v3/clock` endpoint. The table has one row for each market clock.
The `market` object of each clock is flattened into the columns `market_acronym`, `market_bic`, `market_mic`, `market_name` and `market_timezone`.
"""
function _default_handler(model::Type{MyMarketClocksEndpointModel}, body::String)::DataFrame
    return _records_table(_json_records(body, String["clocks"]));
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

"""
    _parse_bar(symbol::AbstractString, record) -> Bar

Build a `Bar` from one bar record of a market data endpoint. The `symbol` argument fills the `symbol` field,
because a bar record does not carry its symbol. The trade count `n` and the volume weighted price `vw` are optional.
"""
function _parse_bar(symbol::AbstractString, record)::Bar

    # the trade count and the volume weighted price are optional -
    trade_count = nothing;
    if (haskey(record, :n) == true)
        trade_count = Int(record.n);
    end
    vwap = nothing;
    if (haskey(record, :vw) == true)
        vwap = Float64(record.vw);
    end

    # build the bar -
    return Bar(
        String(symbol),
        _parse_rfc3339(String(record.t)),
        Float64(record.o),
        Float64(record.h),
        Float64(record.l),
        Float64(record.c),
        Float64(record.v),
        trade_count,
        vwap,
    );
end

"""
    _parse_quote(symbol::AbstractString, record) -> Quote

Build a `Quote` from one quote record of a market data endpoint. The `symbol` argument fills the `symbol` field.
A missing price, size, or exchange takes the value `0.0` or `""`.
"""
function _parse_quote(symbol::AbstractString, record)::Quote
    return Quote(
        String(symbol),
        _parse_rfc3339(String(record.t)),
        Float64(get(record, :bp, 0.0)),
        Float64(get(record, :bs, 0.0)),
        Float64(get(record, :ap, 0.0)),
        Float64(get(record, :as, 0.0)),
        String(get(record, :bx, "")),
        String(get(record, :ax, "")),
    );
end

"""
    _parse_trade(symbol::AbstractString, record) -> Trade

Build a `Trade` from one trade record of a market data endpoint. The `symbol` argument fills the `symbol` field.
The trade identifier `i` is optional.
"""
function _parse_trade(symbol::AbstractString, record)::Trade

    # the trade identifier is optional -
    trade_id = nothing;
    if (haskey(record, :i) == true)
        trade_id = Int(record.i);
    end

    # build the trade -
    return Trade(
        String(symbol),
        _parse_rfc3339(String(record.t)),
        Float64(get(record, :p, 0.0)),
        Float64(get(record, :s, 0.0)),
        String(get(record, :x, "")),
        trade_id,
    );
end

# _maybe_float: the value of the key as a Float64, or nothing when the key is missing or null -
function _maybe_float(record, key::Symbol)::Union{Nothing,Float64}
    if (haskey(record, key) == true && record[key] !== nothing)
        return Float64(record[key]);
    end
    return nothing;
end

# _parse_greeks: an OptionGreeks from a greeks record, or nothing when the record is nothing -
function _parse_greeks(record)::Union{Nothing,OptionGreeks}
    if (record === nothing)
        return nothing;
    end
    return OptionGreeks(
        _maybe_float(record, :delta),
        _maybe_float(record, :gamma),
        _maybe_float(record, :theta),
        _maybe_float(record, :vega),
        _maybe_float(record, :rho),
    );
end

"""
    _parse_option_snapshot(symbol::AbstractString, record::JSON3.Object) -> OptionSnapshot

Build an `OptionSnapshot` from one snapshot record of an option data endpoint. Each part of the snapshot is optional,
and a missing or null part becomes `nothing`. The `OptionSnapshot` keeps the record in its `raw` field.
"""
function _parse_option_snapshot(symbol::AbstractString, record::JSON3.Object)::OptionSnapshot

    # the latest quote, the latest trade, and the three bars -
    latest_quote = nothing;
    if (haskey(record, :latestQuote) == true && record.latestQuote !== nothing)
        latest_quote = _parse_quote(String(symbol), record.latestQuote);
    end
    latest_trade = nothing;
    if (haskey(record, :latestTrade) == true && record.latestTrade !== nothing)
        latest_trade = _parse_trade(String(symbol), record.latestTrade);
    end
    minute_bar = nothing;
    if (haskey(record, :minuteBar) == true && record.minuteBar !== nothing)
        minute_bar = _parse_bar(String(symbol), record.minuteBar);
    end
    daily_bar = nothing;
    if (haskey(record, :dailyBar) == true && record.dailyBar !== nothing)
        daily_bar = _parse_bar(String(symbol), record.dailyBar);
    end
    previous_daily_bar = nothing;
    if (haskey(record, :prevDailyBar) == true && record.prevDailyBar !== nothing)
        previous_daily_bar = _parse_bar(String(symbol), record.prevDailyBar);
    end

    # the implied volatility and the greeks -
    implied_volatility = nothing;
    if (haskey(record, :impliedVolatility) == true && record.impliedVolatility !== nothing)
        implied_volatility = Float64(record.impliedVolatility);
    end
    greeks = nothing;
    if (haskey(record, :greeks) == true && record.greeks !== nothing)
        greeks = _parse_greeks(record.greeks);
    end

    # build the snapshot -
    return OptionSnapshot(String(symbol), latest_quote, latest_trade, minute_bar, daily_bar, previous_daily_bar,
        implied_volatility, greeks, record);
end

"""
    _legacy_by_symbol(body::String, key::Symbol, element_type::Type, parser::Function) -> Dict{String,Vector{element_type}}

Parse the records of one page of a historical bars, quotes, or trades response. The records sit under `key`, in one
list for each symbol. A missing or null `key` object is an empty result.

### Arguments
- `body::String`: the response body of one page.
- `key::Symbol`: the key of the response object that holds the records, e.g., `:bars`.
- `element_type::Type`: the type that `parser` returns, e.g., `Bar`.
- `parser::Function`: the function that builds one `element_type` from a symbol and a record, e.g., `_parse_bar`.

### Returns
- A `Dict{String,Vector{element_type}}` keyed by symbol.
"""
function _legacy_by_symbol(body::String, key::Symbol, element_type::Type, parser::Function)

    # read the page, and start with an empty result -
    resp = JSON3.read(body);
    out = Dict{String,Vector{element_type}}();

    # skip a missing or null object, otherwise parse the records of each symbol -
    if (haskey(resp, key) == true && resp[key] !== nothing)
        for (symbol, records) in pairs(resp[key])
            bucket = get!(out, String(symbol), element_type[]);
            for record in records
                push!(bucket, parser(String(symbol), record));
            end
        end
    end
    return out;
end

"""
    _legacy_latest_by_symbol(body::String, key::Symbol, element_type::Type, parser::Function) -> Dict{String,element_type}

Parse the response of a latest bars, quotes, or trades endpoint. The records sit under `key`, one record for each
symbol. A missing or null `key` object is an empty result.

### Arguments
- `body::String`: the response body.
- `key::Symbol`: the key of the response object that holds the records, e.g., `:bars`.
- `element_type::Type`: the type that `parser` returns, e.g., `Bar`.
- `parser::Function`: the function that builds one `element_type` from a symbol and a record, e.g., `_parse_bar`.

### Returns
- A `Dict{String,element_type}` keyed by symbol.
"""
function _legacy_latest_by_symbol(body::String, key::Symbol, element_type::Type, parser::Function)

    # read the response, and start with an empty result -
    resp = JSON3.read(body);
    out = Dict{String,element_type}();

    # skip a missing or null object, otherwise parse the record of each symbol -
    if (haskey(resp, key) == true && resp[key] !== nothing)
        for (symbol, record) in pairs(resp[key])
            out[String(symbol)] = parser(String(symbol), record);
        end
    end
    return out;
end

# _legacy_handler: /stocks/bars returns the bars of each symbol -
function _legacy_handler(model::Type{MyStockBarsEndpointModel}, body::String)::Dict{String,Vector{Bar}}
    return _legacy_by_symbol(body, :bars, Bar, _parse_bar);
end

# _legacy_handler: /options/bars returns the bars of each option symbol -
function _legacy_handler(model::Type{MyOptionBarsEndpointModel}, body::String)::Dict{String,Vector{Bar}}
    return _legacy_by_symbol(body, :bars, Bar, _parse_bar);
end

# _legacy_handler: /stocks/quotes returns the quotes of each symbol -
function _legacy_handler(model::Type{MyStockQuotesEndpointModel}, body::String)::Dict{String,Vector{Quote}}
    return _legacy_by_symbol(body, :quotes, Quote, _parse_quote);
end

# _legacy_handler: /stocks/trades returns the trades of each symbol -
function _legacy_handler(model::Type{MyStockTradesEndpointModel}, body::String)::Dict{String,Vector{Trade}}
    return _legacy_by_symbol(body, :trades, Trade, _parse_trade);
end

# _legacy_handler: /options/trades returns the trades of each option symbol -
function _legacy_handler(model::Type{MyOptionTradesEndpointModel}, body::String)::Dict{String,Vector{Trade}}
    return _legacy_by_symbol(body, :trades, Trade, _parse_trade);
end

# _legacy_handler: the latest stock bar returns the parsed JSON value. The legacy function builds the Bar from it -
function _legacy_handler(model::Type{MyStockLatestBarEndpointModel}, body::String)
    return JSON3.read(body);
end

# _legacy_handler: the latest stock quote returns the parsed JSON value. The legacy function builds the Quote from it -
function _legacy_handler(model::Type{MyStockLatestQuoteEndpointModel}, body::String)
    return JSON3.read(body);
end

# _legacy_handler: the latest stock trade returns the parsed JSON value. The legacy function builds the Trade from it -
function _legacy_handler(model::Type{MyStockLatestTradeEndpointModel}, body::String)
    return JSON3.read(body);
end

# _legacy_handler: /stocks/snapshots returns the parsed JSON value, keyed by symbol -
function _legacy_handler(model::Type{MyStockSnapshotsEndpointModel}, body::String)
    return JSON3.read(body);
end

# _legacy_handler: /options/quotes/latest returns the latest Quote of each option symbol -
function _legacy_handler(model::Type{MyOptionLatestQuoteEndpointModel}, body::String)::Dict{String,Quote}
    return _legacy_latest_by_symbol(body, :quotes, Quote, _parse_quote);
end

# _legacy_handler: /options/trades/latest returns the latest Trade of each option symbol -
function _legacy_handler(model::Type{MyOptionLatestTradeEndpointModel}, body::String)::Dict{String,Trade}
    return _legacy_latest_by_symbol(body, :trades, Trade, _parse_trade);
end

# _legacy_handler: /options/snapshots returns one OptionSnapshot for each option symbol. The endpoint either wraps
# the snapshots under the snapshots key or does not -
function _legacy_handler(model::Type{MyOptionSnapshotsEndpointModel}, body::String)::Dict{String,OptionSnapshot}
    resp = JSON3.read(body);
    out = Dict{String,OptionSnapshot}();
    snapshots = get(resp, :snapshots, resp);
    for (symbol, record) in pairs(snapshots)
        out[String(symbol)] = _parse_option_snapshot(String(symbol), record);
    end
    return out;
end

# _legacy_handler: /options/snapshots/{underlying} returns one OptionSnapshot for each option symbol on the page.
# A missing or null snapshots object is an empty result -
function _legacy_handler(model::Type{MyOptionChainEndpointModel}, body::String)::Dict{String,OptionSnapshot}
    resp = JSON3.read(body);
    out = Dict{String,OptionSnapshot}();
    snapshots = get(resp, :snapshots, nothing);
    if (snapshots !== nothing)
        for (symbol, record) in pairs(snapshots)
            out[String(symbol)] = _parse_option_snapshot(String(symbol), record);
        end
    end
    return out;
end
"""
    _watchlist_table(body::String) -> DataFrame

Build the table of one watchlist from a response body. The table has one row for each asset of the watchlist.
The columns are `watchlist_id` and `watchlist_name`, then the columns of `_assets_table`.
A watchlist with no assets gives zero rows with the same columns.
"""
function _watchlist_table(body::String)::DataFrame

    # parse the watchlist, and read its identifier, its name, and its assets -
    watchlist = JSON3.read(body);
    watchlist_id = _string_or_missing(watchlist, :id);
    watchlist_name = _string_or_missing(watchlist, :name);
    assets = Any[];
    if (haskey(watchlist, :assets) == true && watchlist[:assets] !== nothing)
        for asset in watchlist[:assets]
            push!(assets, asset);
        end
    end

    # the assets table, with the watchlist columns in front -
    table = _assets_table(assets);
    number_of_assets = size(table, 1);
    insertcols!(table, 1, :watchlist_id => fill(watchlist_id, number_of_assets), :watchlist_name => fill(watchlist_name, number_of_assets));
    return table;
end

"""
    _default_handler(model::Type{MyWatchlistsEndpointModel}, body::String) -> DataFrame

Process the response of the `/watchlists` endpoint.
The table has one row for each watchlist, with the columns `id`, `account_id`, `name`, `created_at`, and `updated_at`.
"""
function _default_handler(model::Type{MyWatchlistsEndpointModel}, body::String)::DataFrame
    return _records_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{T}, body::String) -> DataFrame

Process the response of a watchlist endpoint that answers with one watchlist, `T` being `MyWatchlistEndpointModel`,
`MyCreateWatchlistEndpointModel`, `MyUpdateWatchlistEndpointModel`, `MyAddWatchlistAssetEndpointModel`, or
`MyRemoveWatchlistAssetEndpointModel`. The table is the one that `_watchlist_table` builds.
"""
function _default_handler(model::Type{MyWatchlistEndpointModel}, body::String)::DataFrame
    return _watchlist_table(body);
end

function _default_handler(model::Type{MyCreateWatchlistEndpointModel}, body::String)::DataFrame
    return _watchlist_table(body);
end

function _default_handler(model::Type{MyUpdateWatchlistEndpointModel}, body::String)::DataFrame
    return _watchlist_table(body);
end

function _default_handler(model::Type{MyAddWatchlistAssetEndpointModel}, body::String)::DataFrame
    return _watchlist_table(body);
end

function _default_handler(model::Type{MyRemoveWatchlistAssetEndpointModel}, body::String)::DataFrame
    return _watchlist_table(body);
end

"""
    _default_handler(model::Type{MyDeleteWatchlistEndpointModel}, body::String) -> DataFrame

Process the response of the delete watchlist endpoint, which has no body. The result is an empty table.
"""
function _default_handler(model::Type{MyDeleteWatchlistEndpointModel}, body::String)::DataFrame
    return _empty_table(body);
end

"""
    _default_handler(model::Type{MyUpdateAccountConfigurationsEndpointModel}, body::String) -> DataFrame

Process the response of the change account settings endpoint.
The table has one row, with one column for each setting.
"""
function _default_handler(model::Type{MyUpdateAccountConfigurationsEndpointModel}, body::String)::DataFrame
    return _records_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{MyReplaceOrderEndpointModel}, body::String) -> DataFrame

Process the response of the replace order endpoint.
The table has one row, with the columns of `_orders_table`.
"""
function _default_handler(model::Type{MyReplaceOrderEndpointModel}, body::String)::DataFrame
    return _orders_table(_json_records(body, String[]));
end

"""
    _default_handler(model::Type{T}, body::String) -> DataFrame

Process the response of an option exercise endpoint, `T` being `MyExerciseOptionEndpointModel` or
`MyDoNotExerciseOptionEndpointModel`. The endpoint has no body, so the result is an empty table.
"""
function _default_handler(model::Type{MyExerciseOptionEndpointModel}, body::String)::DataFrame
    return _empty_table(body);
end

function _default_handler(model::Type{MyDoNotExerciseOptionEndpointModel}, body::String)::DataFrame
    return _empty_table(body);
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
