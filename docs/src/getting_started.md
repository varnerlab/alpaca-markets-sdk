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

Create `conf/apiidata.toml` (this path is git-ignored by default) from the
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
Never commit this file — a template lives at `conf/apiidata.example.toml`.

## First call

```julia
using Alpaca

client = load_client()                 # default path: conf/apiidata.toml
# or: load_client("conf/my_other_creds.toml")

acct = get_account(client)
println("cash: ", acct.cash, " ", acct.currency)
```

## Market data feeds

The market-data functions default to `feed = "iex"`, which is free on every
Alpaca account. If you have a paid data subscription, pass `feed = "sip"` to
[`get_bars`](@ref), [`get_quotes`](@ref), [`get_trades`](@ref), and the
`get_latest_*` helpers for consolidated tape data.

## Error handling

Any non-2xx REST response raises an [`AlpacaError`](@ref):

```julia
try
    submit_order(client, "NOPE", 1, "buy")
catch e
    e isa AlpacaError || rethrow()
    @warn "order rejected" status=e.status code=e.code message=e.message
end
```
