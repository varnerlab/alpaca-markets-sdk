# Options

Options trading support for US-listed equity and ETF option contracts.
Alpaca's paper accounts support options trading — same credentials, same
`AlpacaClient`.

## Architecture note

Options touch two Alpaca bases:

- **Contract metadata & orders** live on the trading API (`trading_url`)
  under `/options/contracts` and, for order submission, on the same
  `/orders` endpoint that stock orders use.
- **Market data** (historical bars / quotes / trades, latest-* endpoints,
  snapshots with greeks) lives on a separate v1beta1 host — the
  [`AlpacaClient`](@ref) stores this in `options_data_url`, which is
  derived automatically from `data_url`.

## Submitting options orders

Single-leg options orders reuse the existing [`submit_order`](@ref)
function — just pass an OCC-encoded option symbol as the `symbol`:

```julia
# Buy 1 AAPL Jan 17 2026 \$150 Call, day order
submit_order(client, "AAPL260117C00150000", 1, "buy";
             type = "limit", time_in_force = "day", limit_price = 12.50)
```

Multi-leg orders (spreads, condors, etc.) are not yet wrapped in this
package; you can still submit them via the raw trading API if you need
them today.

## Discovering contracts

Start with the chain for an underlying, filtered by the criteria you care
about:

```julia
contracts = list_option_contracts(client;
                                  underlying_symbols  = "AAPL",
                                  type                = "call",
                                  expiration_date_gte = Date(2026, 1, 1),
                                  expiration_date_lte = Date(2026, 6, 30),
                                  strike_price_gte    = 140,
                                  strike_price_lte    = 180)

for c in contracts
    println(c.symbol, "  strike=", c.strike_price, "  exp=", c.expiration_date)
end
```

## Live quotes and greeks

For a live view of the whole chain (latest quote/trade, implied
volatility, delta/gamma/theta/vega/rho) use
[`get_option_chain_snapshot`](@ref):

```julia
chain = get_option_chain_snapshot(client, "AAPL";
                                  type                = "call",
                                  expiration_date     = Date(2026, 1, 17))

for (sym, snap) in chain
    println(sym, "  iv=", snap.implied_volatility,
            "  delta=", snap.greeks === nothing ? "—" : snap.greeks.delta)
end
```

For a specific set of contracts you already know, use
[`get_option_snapshots`](@ref) which takes an explicit symbol list.

## Historical data

Same shape as stock market data — OHLCV [`Bar`](@ref) records for bars,
[`Quote`](@ref) / [`Trade`](@ref) for the tick endpoints. Results are
`Dict{String,Vector{Bar}}` keyed by OCC symbol.

```julia
bars = get_option_bars(client, "AAPL260117C00150000", "1Day";
                       start = Date(2025, 10, 1), finish = Date(2026, 1, 17))
```

## Contract discovery

```@docs
list_option_contracts
get_option_contract
```

## Historical market data

```@docs
get_option_bars
get_option_quotes
get_option_trades
```

## Latest market data

```@docs
get_latest_option_bar
get_latest_option_quote
get_latest_option_trade
```

## Snapshots (greeks + IV)

```@docs
get_option_snapshots
get_option_chain_snapshot
```
