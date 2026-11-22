# Streaming

An `AlpacaStream` receives trades, quotes, and bars over a WebSocket while your code keeps running. Connect to the stream, subscribe to symbols, register a callback for each kind of message, and start the stream. The call [`start!`](@ref) returns at once, and the stream runs in a background task.

## Example

```julia
using Alpaca

client = load_client()
stream = connect_market_stream(client; feed="iex")

subscribe!(stream, trades=["AAPL", "MSFT"], bars=["SPY"])

on_trade(stream, t -> println("Trade: $(t.symbol) @ $(t.price)"))
on_bar(stream, b -> println("Bar: $(b.symbol) close=$(b.c)"))

start!(stream)    # returns at once, and the stream runs in the background

# ... other work, such as placing orders ...

stop!(stream)
```

## Connection and lifecycle

```@docs
AlpacaStream
connect_market_stream
start!
stop!
isrunning
```

## Subscriptions

```@docs
subscribe!
unsubscribe!
```

## Callbacks

```@docs
on_trade
on_quote
on_bar
```

## Callback values

```@docs
Trade
Quote
Bar
```

## Reconnection behavior

After a network failure, the stream reconnects on its own. It waits 1 s before the first try and doubles the wait after each failed try, up to 30 s. When Alpaca does not accept the keys, the stream stops at once with an error.

## Logging

The stream logs with Julia's `@info`, `@warn`, and `@debug` macros. To send the log to a file, use a `SimpleLogger`:

```julia
using Logging
io = open("stream.log", "a")
logger = SimpleLogger(io, Logging.Info)
with_logger(logger) do
    start!(stream)
    wait(stream)
end
```
