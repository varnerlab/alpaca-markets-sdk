# Trading

An order model says what to trade, and the verb says what to do with the order. `submit` opens each leg, `close` reverses each leg, and `roll` closes the old legs and opens the new legs. An option leg has no position intent, so the same vector of `MyOptionLegModel` values can be passed to `submit`, `close`, and `roll`.

`close` adds methods to `Base.close` for an `AlpacaClient`, so `using Alpaca` does not clash with `Base.close`.

| Call | What the call sends | Returns |
|---|---|---|
| `submit(client, ::MyEquityOrderModel)` | one equity order | `Order` |
| `submit(client, ::MyOptionLegModel)` | one option order that opens the leg | `Order` |
| `submit(client, ::Vector{MyOptionLegModel})` | one option order for 1 leg, or one multi-leg order for 2 to 4 legs. More than 4 legs raise an `ArgumentError` | `Order` |
| `submit(client, ::MyMixedOrderModel)` | the equity order, then the option order after the equity order fills | `Vector{Order}` |
| `cancel(client, ::Order)`, `cancel(client, ::String)` | a cancel of one order | `nothing` |
| `cancel(client; all = true)` | a cancel of every open order | the cancel status of each order |
| `close(client, symbol::String)` | a liquidation of one holding at market | `Order` |
| `close(client; all = true)` | a liquidation of every position | the status of each position |
| `close(client, ::MyEquityOrderModel)` | one equity order on the opposite side | `Order` |
| `close(client, ::MyOptionLegModel)` | one option order that closes the leg | `Order` |
| `close(client, ::Vector{MyOptionLegModel})` | one multi-leg order that reverses every leg | `Order` |
| `close(client, ::Order)` | the reverse of a filled order | `Order` |
| `close(client, ::MyMixedOrderModel)` | the reverse option order, then the reverse equity order after the option order fills | `Vector{Order}` |
| `roll(client, from, to)` | one multi-leg order that closes the `from` legs and opens the `to` legs | `Order` |

## Covered calls and other mixed orders

Alpaca cannot fill shares and options in one order, so `submit` and `close` send a `MyMixedOrderModel` as two orders in a fixed sequence. The sequence keeps a short call covered at every step.

- `submit` sends the equity order and polls the equity order until it fills. It then sends the option order.
- `close` sends the reverse option order and polls the option order until it fills. It then sends the reverse equity order.
- The keyword `fill_timeout` is the number of seconds to wait for the first order. If the first order does not fill in time, the method cancels the first order, sends nothing else, and throws an [`AlpacaSequenceError`](@ref) that holds the first order.
- The method does not wait on the second order. The returned vector holds the filled first order and the second order as Alpaca accepted it.
- If Alpaca rejects the second order, the method throws an [`AlpacaSequenceError`](@ref) that holds the filled first order. The account then holds the shares without the short call, or the shares without the call that was bought back.

Before `submit` sends anything, the method checks that the shares cover every short call in the model. When any option leg sells a call, the equity side must be `"buy"`, the equity model must set `qty` and not `notional`, and the share quantity must be at least `100 * qty` times the sum of the `ratio` values of the short call legs. A model that fails the check raises an `ArgumentError`, and the method sends no request.

## Orders from an earlier session

The reads return a `DataFrame`, so an `Order` comes only from `submit`, `close`, or `roll`. Across sessions, pass the legs to `close` and `roll`, and pass the order id from the `id` column of an orders `DataFrame` to `cancel`.

## Functions

```@docs
submit(::AlpacaClient, ::MyEquityOrderModel)
submit(::AlpacaClient, ::MyOptionLegModel)
submit(::AlpacaClient, ::Vector{MyOptionLegModel})
submit(::AlpacaClient, ::MyMixedOrderModel)
cancel
Base.close(::AlpacaClient, ::String)
Base.close(::AlpacaClient)
Base.close(::AlpacaClient, ::MyEquityOrderModel)
Base.close(::AlpacaClient, ::MyOptionLegModel)
Base.close(::AlpacaClient, ::Vector{MyOptionLegModel})
Base.close(::AlpacaClient, ::Order)
Base.close(::AlpacaClient, ::MyMixedOrderModel)
roll
```
