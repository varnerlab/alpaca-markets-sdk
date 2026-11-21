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
    url(base::String, model::MyStockLatestBarsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/bars/latest` endpoint.
An HTTP GET call to this URL returns the latest stock bar of each symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestBarsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    feed = model.feed;
    currency = model.currency;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "feed", "currency"];
    query_values = Any[_symbols_value(symbols), _query_value(feed), _query_value(currency)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/bars/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockLatestQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/quotes/latest` endpoint.
An HTTP GET call to this URL returns the latest stock quote of each symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestQuotesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    feed = model.feed;
    currency = model.currency;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "feed", "currency"];
    query_values = Any[_symbols_value(symbols), _query_value(feed), _query_value(currency)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/quotes/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockLatestTradesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/trades/latest` endpoint.
An HTTP GET call to this URL returns the latest stock trade of each symbol.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockLatestTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockLatestTradesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    feed = model.feed;
    currency = model.currency;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "feed", "currency"];
    query_values = Any[_symbols_value(symbols), _query_value(feed), _query_value(currency)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/trades/latest" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockAuctionsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/auctions` endpoint.
An HTTP GET call to this URL returns the historical opening and closing auction prints.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockAuctionsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockAuctionsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    feed = model.feed;
    sort = model.sort;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit", "feed", "sort"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit), _query_value(feed), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/auctions" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockConditionsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/meta/conditions/{ticktype}` endpoint.
An HTTP GET call to this URL returns the map from each condition code to its name.
The tick type is part of the path, and the tape is the query string.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockConditionsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockConditionsEndpointModel)::String

    # get data from the model -
    ticktype = model.ticktype;
    tape = model.tape;

    # build the query keys and values -
    query_keys = String["tape"];
    query_values = Any[_query_value(tape)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    url_string = "$(base)/stocks/meta/conditions/$(URIs.escapeuri(ticktype))" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyStockExchangesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/meta/exchanges` endpoint.
An HTTP GET call to this URL returns the map from each exchange code to the name of the exchange.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v2"`.
- `model::MyStockExchangesEndpointModel`: the endpoint model, which has no fields.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyStockExchangesEndpointModel)::String

    # build the URL string: base + path -
    url_string = "$(base)/stocks/meta/exchanges";

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
    query_values = Any[_date_text(model.start), _date_text(model.finish), _query_value(model.timezone)];
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

"""
    url(base::String, model::MyUpdateAccountConfigurationsEndpointModel) -> String

Build the URL string for the Alpaca `/account/configurations` endpoint.
An HTTP PATCH call to this URL changes the account settings.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyUpdateAccountConfigurationsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyUpdateAccountConfigurationsEndpointModel)::String
    return "$(base)/account/configurations";
end

"""
    url(base::String, model::MyReplaceOrderEndpointModel) -> String

Build the URL string for the Alpaca `/orders/{order_id}` endpoint.
An HTTP PATCH call to this URL replaces an open order.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyReplaceOrderEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyReplaceOrderEndpointModel)::String
    return "$(base)/orders/$(URIs.escapeuri(model.id))";
end

"""
    url(base::String, model::MyExerciseOptionEndpointModel) -> String

Build the URL string for the Alpaca `/positions/{symbol_or_contract_id}/exercise` endpoint.
An HTTP POST call to this URL exercises an option position.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyExerciseOptionEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyExerciseOptionEndpointModel)::String
    return "$(base)/positions/$(URIs.escapeuri(model.symbol))/exercise";
end

"""
    url(base::String, model::MyDoNotExerciseOptionEndpointModel) -> String

Build the URL string for the Alpaca `/positions/{symbol_or_contract_id}/do-not-exercise` endpoint.
An HTTP POST call to this URL tells Alpaca not to exercise an option position.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://paper-api.alpaca.markets/v2"`.
- `model::MyDoNotExerciseOptionEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyDoNotExerciseOptionEndpointModel)::String
    return "$(base)/positions/$(URIs.escapeuri(model.symbol))/do-not-exercise";
end

"""
    url(base::String, model::MyGlobalStockBarsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/bars` endpoint.
An HTTP GET call to this URL returns historical bars of stocks on non-US exchanges.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockBarsEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;
    timeframe = model.timeframe;
    start = model.start;
    finish = model.finish;
    page_size = model.page_size;
    sort = model.sort;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "timeframe", "start", "end", "page_size", "sort"];
    query_values = Any[_symbols_value(symbols), _query_value(timeframe), _time_value(start), _time_value(finish), _query_value(page_size), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/quotes` endpoint.
An HTTP GET call to this URL returns historical quotes of stocks on non-US exchanges.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockQuotesEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    page_size = model.page_size;
    sort = model.sort;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "page_size", "sort"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(page_size), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/quotes" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockTradesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/trades` endpoint.
An HTTP GET call to this URL returns historical trades of stocks on non-US exchanges.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockTradesEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    page_size = model.page_size;
    sort = model.sort;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "page_size", "sort"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(page_size), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockLatestBarsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/latest/bars` endpoint.
An HTTP GET call to this URL returns the latest bar of each of several symbols of stocks on non-US exchanges.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockLatestBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockLatestBarsEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/latest/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockLatestQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/latest/quotes` endpoint.
An HTTP GET call to this URL returns the latest quote of each of several symbols of stocks on non-US exchanges.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockLatestQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockLatestQuotesEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/latest/quotes" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockLatestTradesEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/latest/trades` endpoint.
An HTTP GET call to this URL returns the latest trade of each of several symbols of stocks on non-US exchanges.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockLatestTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockLatestTradesEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/latest/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyGlobalStockSnapshotsEndpointModel) -> String

Build the URL string for the Alpaca `/stocks/{feed}/snapshots` endpoint.
An HTTP GET call to this URL returns the snapshot of each of several symbols of stocks on non-US exchanges.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v3"`.
- `model::MyGlobalStockSnapshotsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyGlobalStockSnapshotsEndpointModel)::String

    # get data from the model -
    feed = model.feed;
    symbols = model.symbols;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the feed is escaped in the path -
    url_string = "$(base)/stocks/$(URIs.escapeuri(feed))/snapshots" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionExchangesEndpointModel) -> String

Build the URL string for the Alpaca `/options/meta/exchanges` endpoint.
An HTTP GET call to this URL returns the map from each option exchange code to its name.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionExchangesEndpointModel`: the endpoint model, which has no fields.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionExchangesEndpointModel)::String

    # build the URL string: base + path -
    url_string = "$(base)/options/meta/exchanges";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyOptionConditionsEndpointModel) -> String

Build the URL string for the Alpaca `/options/meta/conditions/{ticktype}` endpoint.
An HTTP GET call to this URL returns the map from each option condition code to its name.
The tick type is part of the path.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyOptionConditionsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyOptionConditionsEndpointModel)::String

    # build the URL string: base + path; the tick type is escaped in the path -
    url_string = "$(base)/options/meta/conditions/$(URIs.escapeuri(model.ticktype))";

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoBarsEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/bars` endpoint.
An HTTP GET call to this URL returns historical bars of crypto pairs.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoBarsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    timeframe = model.timeframe;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    sort = model.sort;
    loc = model.loc;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "timeframe", "start", "end", "limit", "sort"];
    query_values = Any[_symbols_value(symbols), _query_value(timeframe), _time_value(start), _time_value(finish), _query_value(limit), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/quotes` endpoint.
An HTTP GET call to this URL returns historical quotes of crypto pairs.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoQuotesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    sort = model.sort;
    loc = model.loc;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit", "sort"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/quotes" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoTradesEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/trades` endpoint.
An HTTP GET call to this URL returns historical trades of crypto pairs.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoTradesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    start = model.start;
    finish = model.finish;
    limit = model.limit;
    sort = model.sort;
    loc = model.loc;

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "limit", "sort"];
    query_values = Any[_symbols_value(symbols), _time_value(start), _time_value(finish), _query_value(limit), _query_value(sort)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoLatestBarsEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/latest/bars` endpoint.
An HTTP GET call to this URL returns the latest bar of each of several crypto pairs.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoLatestBarsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoLatestBarsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    loc = model.loc;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/latest/bars" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoLatestQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/latest/quotes` endpoint.
An HTTP GET call to this URL returns the latest quote of each of several crypto pairs.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoLatestQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoLatestQuotesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    loc = model.loc;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/latest/quotes" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoLatestTradesEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/latest/trades` endpoint.
An HTTP GET call to this URL returns the latest trade of each of several crypto pairs.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoLatestTradesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoLatestTradesEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    loc = model.loc;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/latest/trades" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoLatestOrderbooksEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/latest/orderbooks` endpoint.
An HTTP GET call to this URL returns the latest order book of each of several crypto pairs.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoLatestOrderbooksEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoLatestOrderbooksEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    loc = model.loc;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/latest/orderbooks" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyCryptoSnapshotsEndpointModel) -> String

Build the URL string for the Alpaca `/crypto/{loc}/snapshots` endpoint.
An HTTP GET call to this URL returns the snapshot of each of several crypto pairs.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta3"`.
- `model::MyCryptoSnapshotsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCryptoSnapshotsEndpointModel)::String

    # get data from the model -
    symbols = model.symbols;
    loc = model.loc;

    # build the query keys and values; a nothing value is left out -
    query_keys = String["symbols"];
    query_values = Any[_symbols_value(symbols)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string; the location is escaped in the path -
    url_string = "$(base)/crypto/$(URIs.escapeuri(loc))/snapshots" * query_string;

    # return the URL string -
    return url_string;
end

"""
    url(base::String, model::MyNewsEndpointModel) -> String

Build the URL string for the Alpaca `/news` endpoint.
An HTTP GET call to this URL returns one page of news articles.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyNewsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyNewsEndpointModel)::String

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "start", "end", "sort", "limit", "include_content", "exclude_contentless", "page_token"];
    query_values = Any[_symbols_value(model.symbols), _time_value(model.start), _time_value(model.finish), _query_value(model.sort), _query_value(model.limit), _query_value(model.include_content), _query_value(model.exclude_contentless), _query_value(model.page_token)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)/news" * query_string;
end

"""
    url(base::String, model::MyMostActivesEndpointModel) -> String

Build the URL string for the Alpaca `/screener/stocks/most-actives` endpoint.
An HTTP GET call to this URL returns the most active stocks.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyMostActivesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyMostActivesEndpointModel)::String

    # build the query string -
    query_string = _query_string(String["by", "top"], Any[_query_value(model.by), _query_value(model.top)]);

    # build the URL string: base + path + query string -
    return "$(base)/screener/stocks/most-actives" * query_string;
end

"""
    url(base::String, model::MyMoversEndpointModel) -> String

Build the URL string for the Alpaca `/screener/{market_type}/movers` endpoint.
An HTTP GET call to this URL returns the top gainers and losers.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyMoversEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyMoversEndpointModel)::String

    # build the query string -
    query_string = _query_string(String["top"], Any[_query_value(model.top)]);

    # build the URL string: base + path + query string -
    return "$(base)/screener/$(URIs.escapeuri(model.market_type))/movers" * query_string;
end

"""
    url(base::String, model::MyCorporateActionsEndpointModel) -> String

Build the URL string for the Alpaca `/corporate-actions` endpoint.
An HTTP GET call to this URL returns one page of corporate actions. The base URL of the client for this model ends in `v1`.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1"`.
- `model::MyCorporateActionsEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyCorporateActionsEndpointModel)::String

    # build the query keys and values, in the order of the model; a nothing value is left out -
    query_keys = String["symbols", "cusips", "types", "start", "end", "ids", "limit", "sort", "region", "data_quality"];
    query_values = Any[_symbols_value(model.symbols), _symbols_value(model.cusips), _symbols_value(model.types), _date_text(model.start), _date_text(model.finish), _symbols_value(model.ids), _query_value(model.limit), _query_value(model.sort), _query_value(model.region), _query_value(model.data_quality)];
    query_string = _query_string(query_keys, query_values);

    # build the URL string: base + path + query string -
    return "$(base)/corporate-actions" * query_string;
end

"""
    url(base::String, model::MyLogoEndpointModel) -> String

Build the URL string for the Alpaca `/logos/{symbol}` endpoint.
An HTTP GET call to this URL returns the logo as PNG bytes. The symbol is escaped in the path.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyLogoEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyLogoEndpointModel)::String

    # build the query string -
    query_string = _query_string(String["placeholder"], Any[_query_value(model.placeholder)]);

    # build the URL string: base + path + query string -
    return "$(base)/logos/$(URIs.escapeuri(model.symbol))" * query_string;
end

"""
    url(base::String, model::MyFixedIncomeLatestPricesEndpointModel) -> String

Build the URL string for the Alpaca `/fixed_income/latest/prices` endpoint.
An HTTP GET call to this URL returns the latest price of each bond.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyFixedIncomeLatestPricesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyFixedIncomeLatestPricesEndpointModel)::String

    # build the query string -
    query_string = _query_string(String["isins"], Any[_symbols_value(model.isins)]);

    # build the URL string: base + path + query string -
    return "$(base)/fixed_income/latest/prices" * query_string;
end

"""
    url(base::String, model::MyFixedIncomeLatestQuotesEndpointModel) -> String

Build the URL string for the Alpaca `/fixed_income/latest/quotes` endpoint.
An HTTP GET call to this URL returns the latest quote of each bond.
The query string lists each field that is not `nothing`, in the order of the model, and leaves out the `?` when no field is set.

### Arguments
- `base::String`: the base URL of the API, e.g., `"https://data.alpaca.markets/v1beta1"`.
- `model::MyFixedIncomeLatestQuotesEndpointModel`: the endpoint model that holds the fields of the request.

### Returns
- `String`: the complete URL string.

### Throws
- None: this method builds a string and does not call the network.
"""
function url(base::String, model::MyFixedIncomeLatestQuotesEndpointModel)::String

    # build the query string -
    query_string = _query_string(String["isins", "trade_size"], Any[_symbols_value(model.isins), _query_value(model.trade_size)]);

    # build the URL string: base + path + query string -
    return "$(base)/fixed_income/latest/quotes" * query_string;
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

function _base_url(client::AlpacaClient, model::MyCorporateActionsEndpointModel)::String
    return _versioned_url(client.data_url, "v1");
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

function _is_paginated(model::MyStockAuctionsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyGlobalStockBarsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyGlobalStockQuotesEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyGlobalStockTradesEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyCorporateActionsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyCryptoBarsEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyCryptoQuotesEndpointModel)::Bool
    return true;
end

function _is_paginated(model::MyCryptoTradesEndpointModel)::Bool
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

# _http_method of the account settings, order replacement, and option exercise models -
function _http_method(model::MyUpdateAccountConfigurationsEndpointModel)::String
    return "PATCH";
end

function _http_method(model::MyReplaceOrderEndpointModel)::String
    return "PATCH";
end

function _http_method(model::MyExerciseOptionEndpointModel)::String
    return "POST";
end

function _http_method(model::MyDoNotExerciseOptionEndpointModel)::String
    return "POST";
end

# _request_body of the account settings model: the settings that are set -
function _request_body(model::MyUpdateAccountConfigurationsEndpointModel)::Dict{String,Any}

    # the body holds each setting that is set -
    body = Dict{String,Any}();
    names = ["disable_overnight_trading", "fractional_trading", "max_margin_multiplier", "max_options_trading_level",
        "no_shorting", "ptp_no_exception_entry", "suspend_trade", "trade_confirm_email"];
    for name in names
        value = getfield(model, Symbol(name));
        if (value !== nothing)
            body[name] = value;
        end
    end
    return body;
end

# _request_body of the order replacement model: the order fields that change -
function _request_body(model::MyReplaceOrderEndpointModel)::Dict{String,Any}

    # the body holds each field that is set -
    body = Dict{String,Any}();
    names = ["qty", "time_in_force", "limit_price", "stop_price", "trail", "client_order_id"];
    for name in names
        value = getfield(model, Symbol(name));
        if (value !== nothing)
            body[name] = value;
        end
    end
    return body;
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
