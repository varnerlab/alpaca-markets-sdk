# Types

Return types used throughout the package. Every typed result also exposes a
`raw::JSON3.Object` field so you can reach fields that aren't surfaced
directly on the struct.

## Trading

```@docs
Account
Asset
Order
Position
```

## Market data

```@docs
Bar
Quote
Trade
```

## Clock

```@docs
MarketClock
CalendarDay
```

## Options

```@docs
OptionContract
OptionGreeks
OptionSnapshot
```

## Errors

```@docs
AlpacaError
```
