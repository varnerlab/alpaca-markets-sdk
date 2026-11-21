# =============================================================================
# Factory: the url(...) methods and the helpers that build the request URLs
# =============================================================================
# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #

"""
    url(base::String, model::MyAccountEndpointModel) -> String

Build the URL string for the Alpaca `/account` endpoint.
An HTTP GET call to this URL returns the account of the client: cash, buying power, and status.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAccountEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAccountEndpointModel)::String


    # build the URL string: base + path -
    url_string = "$(base)/account";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyClockEndpointModel) -> String

Build the URL string for the Alpaca `/clock` endpoint.
An HTTP GET call to this URL returns the market clock: whether the market is open and when it next opens or closes.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyClockEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyClockEndpointModel)::String


    # build the URL string: base + path -
    url_string = "$(base)/clock";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyPositionsEndpointModel) -> String

Build the URL string for the Alpaca `/positions` endpoint.
An HTTP GET call to this URL returns every open position of the account.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyPositionsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyPositionsEndpointModel)::String


    # build the URL string: base + path -
    url_string = "$(base)/positions";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCalendarEndpointModel) -> String

Build the URL string for the Alpaca `/calendar` endpoint.
An HTTP GET call to this URL returns the market calendar: the trading days and their open and close times.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyCalendarEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCalendarEndpointModel)::String

    # get data from the model -
    start = model.start;
    finish = model.finish;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["start", "end"];
    query_values = Any[_time_value(start), _time_value(finish)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/calendar" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyAssetsEndpointModel) -> String

Build the URL string for the Alpaca `/assets` endpoint.
An HTTP GET call to this URL returns the assets that match a status and an asset class.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAssetsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAssetsEndpointModel)::String

    # get data from the model -
    status = model.status;
    asset_class = model.asset_class;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["status", "asset_class"];
    query_values = Any[_query_value(status), _query_value(asset_class)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/assets" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyAssetEndpointModel) -> String

Build the URL string for the Alpaca `/assets/{symbol}` endpoint.
An HTTP GET call to this URL returns one asset, by symbol or asset identifier.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAssetEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAssetEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;

    # build the URL string: base + path -
    url_string = "$(base)/assets/$(URIs.escapeuri(symbol))";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyPositionEndpointModel) -> String

Build the URL string for the Alpaca `/positions/{symbol}` endpoint.
An HTTP GET call to this URL returns the open position of one symbol.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyPositionEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyPositionEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;

    # build the URL string: base + path -
    url_string = "$(base)/positions/$(URIs.escapeuri(symbol))";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOrdersEndpointModel) -> String

Build the URL string for the Alpaca `/orders` endpoint.
An HTTP GET call to this URL returns the orders of the account that match a status.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyOrdersEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOrdersEndpointModel)::String

    # get data from the model -
    status = model.status;
    limit = model.limit;
    after = model.after;
    until = model.until;
    direction = model.direction;
    symbols = model.symbols;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["status", "limit", "after", "until", "direction", "symbols"];
    query_values = Any[_query_value(status), _query_value(limit), _query_value(after), _query_value(until), _query_value(direction), _symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/orders" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOrderEndpointModel) -> String

Build the URL string for the Alpaca `/orders/{id}` endpoint, or for `/orders:by_client_order_id` when the model holds a client order identifier.
An HTTP GET call to this URL returns one order, by order identifier or by client order identifier.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyOrderEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOrderEndpointModel)::String

    # get data from the model -
    id = model.id;
    client_order_id = model.client_order_id;

    # the model holds one identifier: build the path for that identifier -
    if (id !== nothing)
        return "$(base)/orders/$(id)";
    end
    return "$(base)/orders:by_client_order_id" * _query_string(["client_order_id"], Any[client_order_id]);
end

"""
    url(base::String, model::MyOptionContractsEndpointModel) -> String

Build the URL string for the Alpaca `/options/contracts` endpoint.
An HTTP GET call to this URL returns the option contracts that match the filters.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyOptionContractsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionContractsEndpointModel)::String

    # get data from the model -
    underlying_symbols = model.underlying_symbols;
    status = model.status;
    expiration_date = model.expiration_date;
    expiration_date_gte = model.expiration_date_gte;
    expiration_date_lte = model.expiration_date_lte;
    strike_price_gte = model.strike_price_gte;
    strike_price_lte = model.strike_price_lte;
    type = model.type;
    style = model.style;
    limit = model.limit;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["underlying_symbols", "status", "expiration_date", "expiration_date_gte", "expiration_date_lte", "strike_price_gte", "strike_price_lte", "type", "style", "limit"];
    query_values = Any[_symbols_value(underlying_symbols), _query_value(status), _query_value(expiration_date), _query_value(expiration_date_gte), _query_value(expiration_date_lte), _query_value(strike_price_gte), _query_value(strike_price_lte), _query_value(type), _query_value(style), _query_value(limit)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/contracts" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionContractEndpointModel) -> String

Build the URL string for the Alpaca `/options/contracts/{symbol}` endpoint.
An HTTP GET call to this URL returns one option contract, by symbol or contract identifier.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyOptionContractEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionContractEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;

    # build the URL string: base + path -
    url_string = "$(base)/options/contracts/$(URIs.escapeuri(symbol))";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockBarsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/bars` endpoint.
An HTTP GET call to this URL returns historical stock bars.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockBarsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    timeframe = model.timeframe;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    adjustment = model.adjustment;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "timeframe", "start", "end", "limit", "adjustment", "feed"];
    query_values = Any[_symbols_value(symbols), _query_value(timeframe), _time_value(start), _time_value(finish), _query_value(limit), _query_value(adjustment), _query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/quotes` endpoint.
An HTTP GET call to this URL returns historical stock quotes.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockQuotesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit", "feed"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit), _query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/quotes" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockTradesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/trades` endpoint.
An HTTP GET call to this URL returns historical stock trades.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockTradesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit", "feed"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit), _query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockLatestBarEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{symbol}/bars/latest` endpoint.
An HTTP GET call to this URL returns the latest stock bar of one symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestBarEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestBarEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["feed"];
    query_values = Any[_query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/$(symbol)/bars/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockLatestQuoteEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{symbol}/quotes/latest` endpoint.
An HTTP GET call to this URL returns the latest stock quote of one symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestQuoteEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestQuoteEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["feed"];
    query_values = Any[_query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/$(symbol)/quotes/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockLatestTradeEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{symbol}/trades/latest` endpoint.
An HTTP GET call to this URL returns the latest stock trade of one symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestTradeEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestTradeEndpointModel)::String

    # get data from the model -
    symbol = model.symbol;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["feed"];
    query_values = Any[_query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/$(symbol)/trades/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockSnapshotsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/snapshots` endpoint.
An HTTP GET call to this URL returns the snapshots of several stocks.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockSnapshotsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockSnapshotsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    feed = model.feed;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "feed"];
    query_values = Any[_symbols_value(symbols), _query_value(feed)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/snapshots" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionBarsEndpointModel) -> String

Build the URL string for the Alpaca `/options/bars` endpoint.
An HTTP GET call to this URL returns historical option bars.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionBarsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    timeframe = model.timeframe;
    start = model.start;
    finish = model.finish;
    limit = model.limit;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "timeframe", "start", "end", "limit"];
    query_values = Any[_symbols_value(symbols), _query_value(timeframe), _time_value(start), _time_value(finish), _query_value(limit)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionTradesEndpointModel) -> String

Build the URL string for the Alpaca `/options/trades` endpoint.
An HTTP GET call to this URL returns historical option trades.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionTradesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionLatestQuoteEndpointModel) -> String

Build the URL string for the Alpaca `/options/quotes/latest` endpoint.
An HTTP GET call to this URL returns the latest option quote of several option contracts.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionLatestQuoteEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionLatestQuoteEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/quotes/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionLatestTradeEndpointModel) -> String

Build the URL string for the Alpaca `/options/trades/latest` endpoint.
An HTTP GET call to this URL returns the latest option trade of several option contracts.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionLatestTradeEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionLatestTradeEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/trades/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionSnapshotsEndpointModel) -> String

Build the URL string for the Alpaca `/options/snapshots` endpoint.
An HTTP GET call to this URL returns the snapshots of several option contracts.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionSnapshotsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionSnapshotsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/snapshots" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionChainEndpointModel) -> String

Build the URL string for the Alpaca `/options/snapshots/{underlying}` endpoint.
An HTTP GET call to this URL returns the option chain snapshots of one underlying stock.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionChainEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionChainEndpointModel)::String

    # get data from the model -
    underlying = model.underlying;
    type = model.type;
    strike_price_gte = model.strike_price_gte;
    strike_price_lte = model.strike_price_lte;
    expiration_date = model.expiration_date;
    expiration_date_gte = model.expiration_date_gte;
    expiration_date_lte = model.expiration_date_lte;
    limit = model.limit;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["type", "strike_price_gte", "strike_price_lte", "expiration_date", "expiration_date_gte", "expiration_date_lte", "limit"];
    query_values = Any[_query_value(type), _query_value(strike_price_gte), _query_value(strike_price_lte), _query_value(expiration_date), _query_value(expiration_date_gte), _query_value(expiration_date_lte), _query_value(limit)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/options/snapshots/$(URIs.escapeuri(underlying))" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyAccountConfigurationsEndpointModel) -> String

Build the URL string for the Alpaca `/account/configurations` endpoint.
An HTTP GET call to this URL returns the settings of the account.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAccountConfigurationsEndpointModel`: the endpoint model of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAccountConfigurationsEndpointModel)::String
    return "$(base)/account/configurations";
end

"""
    url(base::String, model::MyAccountActivitiesEndpointModel) -> String

Build the URL string for the Alpaca `/account/activities/{activity_type}` endpoint when the model holds `activity_type`,
and for `/account/activities` otherwise. An HTTP GET call to this URL returns the account activities that match the filters.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.
The `category` field is sent only on the `/account/activities` path.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAccountActivitiesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAccountActivitiesEndpointModel)::String

    # get data from the model -
    activity_type = model.activity_type;

    # the path names one activity type, or the query lists the types and the category -
    path = "/account/activities";
    query_keys = String[];
    query_values = Any[];
    if (activity_type !== nothing)
        path = "/account/activities/$(URIs.escapeuri(activity_type))";
    else
        push!(query_keys, "activity_types");
        push!(query_values, _symbols_value(model.activity_types));
        push!(query_keys, "category");
        push!(query_values, _query_value(model.category));
    end

    # the remaining fields, in the order of the model; a nothing value is left out -
    append!(query_keys, String["date", "after", "until", "direction", "page_size", "page_token", "order_id"]);
    append!(query_values, Any[_time_value(model.date), _time_value(model.after), _time_value(model.until), _query_value(model.direction),
        _query_value(model.page_size), _query_value(model.page_token), _query_value(model.order_id)]);
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)$(path)" * query_string;
end

"""
    url(base::String, model::MyPortfolioHistoryEndpointModel) -> String

Build the URL string for the Alpaca `/account/portfolio/history` endpoint.
An HTTP GET call to this URL returns the equity and the profit and loss of the account over a period.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.
The field `finish` is sent as `end`.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyPortfolioHistoryEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyPortfolioHistoryEndpointModel)::String

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["period", "timeframe", "intraday_reporting", "start", "end", "pnl_reset", "extended_hours", "cashflow_types"];
    query_values = Any[_query_value(model.period), _query_value(model.timeframe), _query_value(model.intraday_reporting),
        _time_value(model.start), _time_value(model.finish), _query_value(model.pnl_reset), _query_value(model.extended_hours),
        _symbols_value(model.cashflow_types)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)/account/portfolio/history" * query_string;
end

"""
    url(base::String, model::MyMarketCalendarEndpointModel) -> String

Build the URL string for the Alpaca `/v3/calendar/{market}` endpoint.
An HTTP GET call to this URL returns the calendar of one market. The base URL is the `v3` base of the trading API.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.
The field `finish` is sent as `end`.

### Arguments
- `base::String`: the `v3` base URL of the trading API, e.g., `"https://paper-api.alpaca.markets/v3"`.
- `model::MyMarketCalendarEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyMarketCalendarEndpointModel)::String

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["start", "end", "timezone"];
    query_values = Any[_time_value(model.start), _time_value(model.finish), _query_value(model.timezone)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)/calendar/$(URIs.escapeuri(model.market))" * query_string;
end

"""
    url(base::String, model::MyMarketClocksEndpointModel) -> String

Build the URL string for the Alpaca `/v3/clock` endpoint.
An HTTP GET call to this URL returns the clocks of the markets. The base URL is the `v3` base of the trading API.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the `v3` base URL of the trading API, e.g., `"https://paper-api.alpaca.markets/v3"`.
- `model::MyMarketClocksEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyMarketClocksEndpointModel)::String

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["markets", "time"];
    query_values = Any[_symbols_value(model.markets), _time_value(model.time)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)/clock" * query_string;
end

"""
    url(client::AlpacaClient, model::AbstractAlpacaEndpointModel) -> String

Build the complete URL string of a model, using the base URL that the client holds for the API of the model.

### Arguments
- `client::AlpacaClient`: the client that holds the trading, stock data, and options data base URLs.
- `model::AbstractAlpacaEndpointModel`: the endpoint model to build the URL for.

### Returns
- `String`: the complete URL string.

### Throws
- `MethodError`: when the model is of an endpoint family that has no base URL.
"""
function url(client::AlpacaClient, model::AbstractAlpacaEndpointModel)::String

    # get the base URL for the API of the model -
    base = _base_url(client, model);

    # build the URL string -
    return url(base, model);
end

"""
    url(base::String, model::MyWatchlistsEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists` endpoint.
An HTTP GET call to this URL lists the watchlists of the account.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyWatchlistsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyWatchlistsEndpointModel)::String
    return "$(base)/watchlists";
end

"""
    url(base::String, model::MyWatchlistEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists/{watchlist_id}` endpoint, or for `/watchlists:by_name` when the model holds a name.
An HTTP GET call to this URL returns one watchlist with its assets.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyWatchlistEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyWatchlistEndpointModel)::String
    return _watchlist_url(base, model.id, model.name);
end

"""
    url(base::String, model::MyCreateWatchlistEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists` endpoint.
An HTTP POST call to this URL creates a watchlist.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyCreateWatchlistEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCreateWatchlistEndpointModel)::String
    return "$(base)/watchlists";
end

"""
    url(base::String, model::MyUpdateWatchlistEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists/{watchlist_id}` endpoint, or for `/watchlists:by_name` when the model holds a name.
An HTTP PUT call to this URL changes the name or the assets of a watchlist.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyUpdateWatchlistEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyUpdateWatchlistEndpointModel)::String
    return _watchlist_url(base, model.id, model.name);
end

"""
    url(base::String, model::MyAddWatchlistAssetEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists/{watchlist_id}` endpoint, or for `/watchlists:by_name` when the model holds a name.
An HTTP POST call to this URL adds one asset to a watchlist.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyAddWatchlistAssetEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyAddWatchlistAssetEndpointModel)::String
    return _watchlist_url(base, model.id, model.name);
end

"""
    url(base::String, model::MyRemoveWatchlistAssetEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists/{watchlist_id}/{symbol}` endpoint.
An HTTP DELETE call to this URL removes one asset from a watchlist. The identifier and the symbol are escaped, so `BTC/USD` becomes `BTC%2FUSD`.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyRemoveWatchlistAssetEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyRemoveWatchlistAssetEndpointModel)::String
    return "$(base)/watchlists/$(URIs.escapeuri(model.id))/$(URIs.escapeuri(model.symbol))";
end

"""
    url(base::String, model::MyDeleteWatchlistEndpointModel) -> String

Build the URL string for the Alpaca `/watchlists/{watchlist_id}` endpoint, or for `/watchlists:by_name` when the model holds a name.
An HTTP DELETE call to this URL deletes a watchlist.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyDeleteWatchlistEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyDeleteWatchlistEndpointModel)::String
    return _watchlist_url(base, model.id, model.name);
end

# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
# _base_url: the base URL of the API that a model calls -
function _base_url(client::AlpacaClient, model::AbstractAlpacaTradingEndpointModel)::String
    return client.trading_url;
end

function _base_url(client::AlpacaClient, model::AbstractAlpacaStockDataEndpointModel)::String
    return client.data_url;
end

function _base_url(client::AlpacaClient, model::AbstractAlpacaOptionDataEndpointModel)::String
    return client.options_data_url;
end

function _base_url(client::AlpacaClient, model::AbstractAlpacaCryptoDataEndpointModel)::String
    return _versioned_url(client.data_url, "v1beta3");
end

function _base_url(client::AlpacaClient, model::AbstractAlpacaGlobalStockDataEndpointModel)::String
    return _versioned_url(client.data_url, "v3");
end

function _base_url(client::AlpacaClient, model::AbstractAlpacaMarketDataEndpointModel)::String
    return client.options_data_url;
end

function _base_url(client::AlpacaClient, model::MyMarketCalendarEndpointModel)::String
    return _versioned_url(client.trading_url, "v3");
end

function _base_url(client::AlpacaClient, model::MyMarketClocksEndpointModel)::String
    return _versioned_url(client.trading_url, "v3");
end

# _http_method: the HTTP method of the request of a model. The default is GET. A write model adds a method -
function _http_method(model::AbstractAlpacaEndpointModel)::String
    return "GET";
end

# _request_body: the body of the request of a model, which api sends as JSON. The default is no body. A write model adds a method -
function _request_body(model::AbstractAlpacaEndpointModel)
    return nothing;
end

# _is_paginated: true when the response of the endpoint holds a next_page_token. The default is false -
function _is_paginated(model::AbstractAlpacaEndpointModel)::Bool
    return false;
end

function _is_paginated(model::MyOptionBarsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyOptionChainEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyOptionContractsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyOptionTradesEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyStockBarsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyStockQuotesEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyStockTradesEndpointModel)::Bool
    return true;
end

"""
    _query_value(x) -> Union{Nothing,String}

Convert a field value to a query value. A value of `nothing` stays `nothing`, and any other value becomes
the string that `string(x)` returns, so `140` stays `"140"`.
"""
function _query_value(x)::Union{Nothing,String}

    # an unset field stays unset -
    if (x === nothing)
        return nothing;
    end

    # write the value as the caller gave it -
    return string(x);
end

"""
    _time_value(x) -> Union{Nothing,String}

Convert a start or finish field (a `String`, `Date`, or `DateTime`) to a query value. A value of `nothing` stays `nothing`.
"""
function _time_value(x)::Union{Nothing,String}

    # an unset field stays unset -
    if (x === nothing)
        return nothing;
    end

    # format the time the way Alpaca expects it -
    return _fmt_ts(x);
end

"""
    _symbols_value(x::Union{Nothing,Vector{String}}) -> Union{Nothing,String}

Convert a symbol vector to one comma-separated query value. A value of `nothing` stays `nothing`.
"""
function _symbols_value(x::Union{Nothing,Vector{String}})::Union{Nothing,String}

    # an unset field stays unset -
    if (x === nothing)
        return nothing;
    end

    # join the symbols with commas -
    return join(x, ",");
end

"""
    _query_string(keys::Vector{String}, values::Vector{Any}) -> String

Build the query string from parallel vectors of keys and values. A `nothing` value is left out,
the rest are escaped. The result starts with `?`, or is empty when no value is set.
"""
function _query_string(keys::Vector{String}, values::Vector{Any})::String

    # collect one key=value pair for each value that is set -
    pairs = String[];
    for i in eachindex(keys)
        if (values[i] !== nothing)
            push!(pairs, "$(URIs.escapeuri(keys[i]))=$(URIs.escapeuri(string(values[i])))");
        end
    end

    # no pair, no question mark -
    if (isempty(pairs) == true)
        return "";
    end
    return "?" * join(pairs, "&");
end
# _watchlist_url: the URL of one watchlist. An identifier goes into the path, and a name goes into the query string of the by-name form -
function _watchlist_url(base::String, id::Union{Nothing,String}, name::Union{Nothing,String})::String

    # an identifier gives the path of the watchlist -
    if (id !== nothing)
        return "$(base)/watchlists/$(URIs.escapeuri(id))";
    end

    # a name gives the by-name form -
    return "$(base)/watchlists:by_name" * _query_string(["name"], Any[name]);
end

# _http_method and _request_body of the watchlist write models -
function _http_method(model::MyCreateWatchlistEndpointModel)::String
    return "POST";
end

function _http_method(model::MyUpdateWatchlistEndpointModel)::String
    return "PUT";
end

function _http_method(model::MyAddWatchlistAssetEndpointModel)::String
    return "POST";
end

function _http_method(model::MyRemoveWatchlistAssetEndpointModel)::String
    return "DELETE";
end

function _http_method(model::MyDeleteWatchlistEndpointModel)::String
    return "DELETE";
end

function _request_body(model::MyCreateWatchlistEndpointModel)::Dict{String,Any}
    body = Dict{String,Any}();
    body["name"] = model.name;
    body["symbols"] = model.symbols;
    return body;
end

function _request_body(model::MyUpdateWatchlistEndpointModel)::Dict{String,Any}

    # the body holds each field that is set -
    body = Dict{String,Any}();
    if (model.new_name !== nothing)
        body["name"] = model.new_name;
    end
    if (model.symbols !== nothing)
        body["symbols"] = model.symbols;
    end
    return body;
end

function _request_body(model::MyAddWatchlistAssetEndpointModel)::Dict{String,Any}
    body = Dict{String,Any}();
    body["symbol"] = model.symbol;
    return body;
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
