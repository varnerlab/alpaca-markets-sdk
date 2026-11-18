# Getting Started

## Installation

While this package is pre-release, clone it and use the local project:

```julia
julia> ] activate .
(Alpaca) pkg> instantiate
```

Once it's published to a registry (or served from GitHub) you'll be able to do:

```julia
julia> ] add https://github.com/jeffreyvarner/Alpaca.jl
```

## Credentials

Create `conf/apidata.toml` (this path is git-ignored by default) from the
template:

```toml
[Credentials]
# Paper trading:  https://paper-api.alpaca.markets/v2
# Live trading:   https://api.alpaca.markets/v2
endpoint = "https://paper-api.alpaca.markets/v2"
key      = "YOUR_ALPACA_KEY_ID"
secret   = "YOUR_ALPACA_SECRET_KEY"
```

Get a free paper-trading key pair from the
[Alpaca dashboard](https://app.alpaca.markets/paper/dashboard/overview).
Never commit this file — a template lives at `conf/apidata.example.toml`.

## First call

```julia
using Alpaca

client = load_client()                 # default path: conf/apidata.toml
# or: load_client("conf/my_other_creds.toml")

account = api(client, MyAccountEndpointModel())
println("cash: ", account.cash[1], " ", account.currency[1])
```

`api` returns a `DataFrame`. An endpoint that returns one record, such as the account, gives a `DataFrame` with one row.

## Market data feeds

The stock data models have the field `feed`, which defaults to `"iex"`. The `"iex"` feed is free on every Alpaca account. If you have a paid data subscription, set `feed = "sip"` in the model for consolidated tape data:

```julia
model = MyStockQuotesEndpointModel(symbols = "AAPL", start = "2025-01-02", feed = "sip")
```

## Error handling

A non-2xx REST response raises an [`AlpacaError`](@ref):

```julia
try
    submit(client, MyEquityOrderModel(symbol = "NOPE", side = "buy", qty = 1))
catch e
    if e isa AlpacaError
        @warn "order rejected" status=e.status code=e.code message=e.message
    else
        rethrow()
    end
end
```
