# Getting Started

This page takes you from a new paper account to a placed and cancelled order. You need Julia 1.10 or later and an Alpaca paper account.

## 1. Install the package

```julia
using Pkg
Pkg.add(url = "https://github.com/varnerlab/alpaca-markets-sdk.git")
```

## 2. Make a credentials file

Alpaca identifies a program by two keys, an API key ID and a secret key. Generate a pair of paper keys in the API Keys panel of the [Alpaca dashboard](https://app.alpaca.markets). Alpaca shows the secret key only once.

Save the keys in a file named `conf/apidata.toml` in your project folder:

```toml
[Credentials]
endpoint = "https://paper-api.alpaca.markets/v2"
key      = "YOUR_PAPER_KEY_ID"
secret   = "YOUR_PAPER_SECRET_KEY"
```

Anyone with your keys can trade in your account. Keep the keys out of notebooks, and add `conf/apidata.toml` to your `.gitignore` file so that git never commits it.

## 3. Read your account

```julia
using Alpaca
using Dates

client = load_client();
account = api(client, MyAccountEndpointModel());
```

The call `load_client()` reads `conf/apidata.toml`, and `load_client(path)` reads the file at `path`. The `account` table has one row, with the cash, the buying power, and the equity of the account.

## 4. Read prices

```julia
model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
    start = Date(2026, 11, 2), finish = Date(2026, 11, 20));
bars = api(client, model);
quotes = api(client, MyStockLatestQuotesEndpointModel(symbols = ["AAPL", "MSFT"]));
```

The `bars` table has one row for each daily bar of each stock, and the `quotes` table has the latest bid price and ask price of each stock. The [Stock data](endpoints/stocks.md) page lists the columns.

## 5. Place and cancel a paper order

An order model says what to trade, and `submit` sends the order. This buy limit order has a limit price far below the price of SPY, so the order stays open until you cancel it or the trading day ends:

```julia
order = submit(client, MyEquityOrderModel(symbol = "SPY", side = "buy", qty = 1);
    type = "limit", limit_price = 500.0);
open_orders = api(client, MyOrdersEndpointModel(status = "open"));
cancel(client, order);
```

The [Trading](api/trading.md) page lists every verb, and the [Orders and positions](endpoints/orders.md) page covers the order models.

## 6. Handle errors

When Alpaca refuses a request, the call throws an [`AlpacaError`](@ref) with the HTTP status and Alpaca's message:

```julia
try
    api(client, MyAssetEndpointModel(symbol = "NOTASYMBOL"));
catch e
    if e isa AlpacaError
        println(e.status, ": ", e.message);
    else
        rethrow();
    end
end
```

The common statuses are:

- `401`: Alpaca does not accept the keys.
- `403`: the market data plan of the account does not include the data.
- `404`: the symbol, order, or position does not exist.
- `422`: Alpaca rejected the settings of an order.
