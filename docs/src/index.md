# Alpaca.jl

Alpaca.jl is a Julia package for the trading and market data APIs of [Alpaca](https://alpaca.markets). With an Alpaca paper account, it reads market data and places orders with simulated money at real market prices.

Every Alpaca endpoint has a model type in this package. A model holds the settings of one request, and the call `api(client, model)` sends the request and returns the result as a `DataFrame`. The trading verbs `submit`, `cancel`, and `close` place and manage orders.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/varnerlab/alpaca-markets-sdk.git")
```

## Where to go next

- [Getting Started](getting_started.md) takes you from a new paper account to a placed and cancelled order.
- The **Endpoints** pages cover every Alpaca endpoint: what each model reads or does, its fields, the columns of its result, and an example.
- The **Reference** pages cover the client, `api` and its pages, the trading verbs, streaming, and errors. The [Legacy API](api/legacy.md) page lists the replacement for each function of versions before 0.4.0.

This package is not affiliated with Alpaca Securities LLC.
