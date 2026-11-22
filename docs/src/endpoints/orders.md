# Orders and positions

An order model says what to trade, and the trading verbs on the [Trading](../api/trading.md) page send it. The endpoint models read the orders and the positions of the account, replace an open order, and exercise an option. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyEquityOrderModel`](@ref) | An order for a stock or an ETF |
| [`MyCryptoOrderModel`](@ref) | An order for a crypto pair |
| [`MyOptionLegModel`](@ref) | One leg of an option order |
| [`MyMixedOrderModel`](@ref) | Shares and option legs traded in sequence, such as a covered call |
| [`MyOrdersEndpointModel`](@ref) | The orders of the account, filtered by status |
| [`MyOrderEndpointModel`](@ref) | One order, by id |
| [`MyReplaceOrderEndpointModel`](@ref) | Changes the quantity or the prices of an open order |
| [`MyPositionsEndpointModel`](@ref) | Every open position |
| [`MyPositionEndpointModel`](@ref) | One open position, by symbol |
| [`MyExerciseOptionEndpointModel`](@ref) | Exercises a long option position |
| [`MyDoNotExerciseOptionEndpointModel`](@ref) | Declines the exercise of a long option position at expiration |

## Order models

```@docs
MyEquityOrderModel
MyCryptoOrderModel
MyOptionLegModel
MyMixedOrderModel
```

## Orders

```@docs
MyOrdersEndpointModel
MyOrderEndpointModel
MyReplaceOrderEndpointModel
```

## Positions

```@docs
MyPositionsEndpointModel
MyPositionEndpointModel
MyExerciseOptionEndpointModel
MyDoNotExerciseOptionEndpointModel
```
