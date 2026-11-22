# Clock and calendars

These models read whether a market is open and the days and hours it trades. Every example on this page assumes `using Alpaca`, `using Dates`, and `client = load_client()`.

| Model | What it reads or does |
|---|---|
| [`MyClockEndpointModel`](@ref) | Whether the US stock market is open now, and its next open and close |
| [`MyCalendarEndpointModel`](@ref) | The trading days of the US stock market, with their open and close times |
| [`MyMarketCalendarEndpointModel`](@ref) | The trading days of one market, such as `"NYSE"` |
| [`MyMarketClocksEndpointModel`](@ref) | The clocks of several markets at once |

```@docs
MyClockEndpointModel
MyCalendarEndpointModel
MyMarketCalendarEndpointModel
MyMarketClocksEndpointModel
```
