# Review Findings

Test status: `julia --project=. -e 'using Pkg; Pkg.test()'` passed locally (`228/228`), so the issues below are gaps the current suite does not exercise rather than regressions already caught by CI.

## 1. High: `subscribe!` / `unsubscribe!` do not update a live stream

- `subscribe!` and `unsubscribe!` only mutate in-memory sets in [`src/streaming.jl:110`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L110) and [`src/streaming.jl:125`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L125).
- The websocket task sends a subscribe frame only once, right after authentication, in [`src/streaming.jl:289`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L289).
- There is an unsubscribe helper in [`src/streaming.jl:204`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L204), but nothing ever calls it.

Why this matters: the public docstring says post-`start!` subscription changes are sent immediately, but in practice they are not applied until the socket reconnects. A caller can believe they are subscribed to `AAPL` (or unsubscribed from it) while the server-side subscription never changes.

Recommendation: keep a handle to the live websocket and push subscribe/unsubscribe deltas when the sets change, or queue outbound control messages that the receive loop drains between frames.

## 2. High: `stop!` can hang indefinitely on an idle websocket

- The main receive loop blocks on `receive(ws)` in [`src/streaming.jl:292`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L292).
- `stop!` only flips `running=false` and then waits for the task in [`src/streaming.jl:348`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L348) and [`src/streaming.jl:354`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl#L354).
- No receive timeout or explicit websocket close is configured anywhere in [`src/streaming.jl`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl).

Why this matters: if the market is quiet and no frames arrive, `stop!` can block forever waiting for a task that is still stuck inside `receive(ws)`. That is a bad failure mode for scripts, tests, and shutdown hooks.

Recommendation: store the websocket object on `AlpacaStream` and close it from `stop!`, or use a timed receive / cancellation mechanism so the loop can observe `running=false` promptly.

## 3. Medium: `download_bars(...; chunk_months=...)` drops `DateTime` precision

- `_month_chunks` coerces both ends of the range to `Date` in [`src/historical.jl:69`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/historical.jl#L69) and [`src/historical.jl:70`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/historical.jl#L70).
- Those truncated chunk boundaries are then passed back into `get_bars` in [`src/historical.jl:141`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/historical.jl#L141).
- A quick probe confirms the truncation: `Alpaca._month_chunks(DateTime("2024-01-15T13:45:00"), DateTime("2024-03-02T09:15:00"), 1)` returns `Date`s only.

Why this matters: intraday downloads can silently widen the requested interval. The first chunk starts at midnight instead of the caller's actual start time, and the last chunk ends at the day boundary instead of the requested finish timestamp.

Recommendation: preserve the original `DateTime` on the first and last chunk boundaries, or split with `DateTime` math throughout.

## 4. Medium: the README quick start is out of sync with the shipped API

- The config example in [`README.md:23`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/README.md#L23) uses `[alpaca]`, `api_key`, `api_secret`, `base_url`, and `data_url`.
- `load_client` actually expects `[Credentials]` plus `endpoint`, `key`, and `secret` in [`src/client.jl:76`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/client.jl#L76).
- The example call in [`README.md:47`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/README.md#L47) uses `get_bars(client, "AAPL"; timeframe="1Day", ...)`, but `timeframe` is positional in [`src/marketdata.jl:61`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/marketdata.jl#L61).
- The example call in [`README.md:50`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/README.md#L50) uses keyword `qty` / `side`, but `submit_order` takes them positionally in [`src/orders.jl:36`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/orders.jl#L36).

Why this matters: the first-run path in the repository does not work verbatim, which is likely to create false bug reports before users ever reach the actual implementation.

Recommendation: update the README to match the current public API, or add compatibility overloads if the README reflects the intended calling convention.

## 5. Medium: there is no automated coverage for the streaming module

- The test entrypoint in [`test/runtests.jl:11`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/test/runtests.jl#L11) includes account, clock, assets, orders, positions, market data, historical, options, and integration tests.
- There is no `test/test_streaming.jl` in the repository, and nothing in the current suite exercises [`src/streaming.jl`](/Users/jdv27/Desktop/julia_work/alpaca-markets-sdk/src/streaming.jl).

Why this matters: the two streaming lifecycle issues above ship undetected because the websocket surface has no regression harness at all.

Recommendation: add websocket-backed tests for auth, initial subscribe, post-start subscribe/unsubscribe, reconnect, and `stop!` while the connection is idle.
