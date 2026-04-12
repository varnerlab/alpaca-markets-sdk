# Streaming

Real-time market data via WebSocket. The stream runs asynchronously in a
background task — call [`start!`](@ref) and continue working in the REPL or
your script.

## Quick example

```julia
using Alpaca

client = load_client()
stream = connect_market_stream(client; feed="iex")

subscribe!(stream, trades=["AAPL", "MSFT"], bars=["SPY"])

on_trade(stream, t -> println("Trade: $(t.symbol) @ $(t.price)"))
on_bar(stream, b -> println("Bar: $(b.symbol) close=$(b.c)"))

start!(stream)  # returns immediately — stream runs in background

# ... do other work, submit orders, etc. ...

stop!(stream)
```

## Connection & lifecycle

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

## Reconnection behavior

The stream automatically reconnects on network failures with exponential
backoff (1 s, 2 s, 4 s, ... up to 30 s). Authentication failures (invalid
API key/secret) are **hard errors** that stop the stream immediately.

## Logging

The stream uses Julia's standard `@info`/`@warn`/`@debug` macros. Route
them to a file with `SimpleLogger`:

```julia
using Logging
io = open("stream.log", "a")
logger = SimpleLogger(io, Logging.Info)
with_logger(logger) do
    start!(stream)
    wait(stream)
end
```
