# Types and errors

The trading verbs `submit`, `close`, and `roll` return an `Order`. A request that Alpaca refuses throws an `AlpacaError`, and a two-order sequence that stops after its first order throws an `AlpacaSequenceError`.

## Orders and errors

```@docs
Order
AlpacaError
AlpacaSequenceError
```

## Abstract types

Each endpoint model is a subtype of one abstract type, and the abstract type selects the base URL of the request: trading, US stock data, non-US stock data, option data, crypto data, or the other market data.

```@docs
AbstractAlpacaEndpointModel
AbstractAlpacaTradingEndpointModel
AbstractAlpacaStockDataEndpointModel
AbstractAlpacaGlobalStockDataEndpointModel
AbstractAlpacaOptionDataEndpointModel
AbstractAlpacaCryptoDataEndpointModel
AbstractAlpacaMarketDataEndpointModel
AbstractAlpacaOrderModel
```
