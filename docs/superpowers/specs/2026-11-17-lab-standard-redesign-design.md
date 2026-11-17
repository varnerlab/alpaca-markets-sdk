# Lab-standard redesign of `Alpaca.jl`

**Status:** design, pending approval
**Date:** 2026-11-17
**Target release:** `0.4.0`
**Reference pattern:** CHEME 5800 L13a (`src/NWS.jl`) and L13b (`src/FRED.jl`), in
`CHEME-5800-CourseRepository-Fall-2026/weeks/week-13/`.

---

## 1. Intent

Rebuild the public API of `Alpaca.jl` on the lab's REST SDK pattern from L13a and L13b. In that
pattern, each endpoint is a model type, and a small set of verbs dispatches on the model type.
Today the SDK exposes about 40 function names (`get_bars`, `get_option_bars`,
`get_latest_option_quote`, `submit_multileg_order`, ...). Jeff wants a small, clean vocabulary
that reads the same way as the course SDKs.

All code written from now on uses the new design. The old names stay available so that the daily
options cron, the backfill script, the IV-model repo, and the options-strategy repo keep working.
The old names are marked as legacy and emit a deprecation warning.

## 2. Goals, non-goals, anti-goals

**Goals**

- The public surface is model types plus six verbs: `url`, `api`, `submit`, `cancel`, `close`,
  and `roll`. `load_client`, the streaming API, `AlpacaClient`, `Order`, and `AlpacaError` stay
  as they are.
- Every legacy name keeps its signature, arguments, and return value, and runs through the new
  code underneath. There is one code path.
- Every legacy name emits `Base.depwarn` and is documented as deprecated, with its replacement.
- All new and rewritten code follows the lab code style in §8.

**Non-goals**

- Fixed income. Alpaca offers Treasuries and corporate bonds only through its Broker API, and
  this SDK uses the Trading API. Bond ETFs (BIL, SHY, IEF, TLT) trade as equities and work with
  every verb.
- Crypto.
- Changes to the streaming API (`AlpacaStream`, `subscribe!`, `on_trade`, ...). Its names are
  already generic. `src/streaming.jl` is not restyled in this release.
- Migrating `examples/` and `scripts/` to the new API. Both stay on the legacy names in `0.4.0`,
  so the cron job also shows that backward compatibility holds.
- Removing any legacy name. Removal is a later decision.
- Strategy logic: sleeve picking, IV-rank gates, lifecycle logs, exit rules, and an OCC
  symbol builder. These belong in the downstream strategy repo.

**Anti-goals**

- Any change in the request that a legacy call sends or the value that a legacy call returns.
  The cron job and the IV-model training data depend on both.
- A call that looks atomic but is not. One `submit`, `close`, or `roll` call that takes a vector
  of option legs sends exactly one atomic order.
- A sequence of equity and option orders that can leave the account short a call without the
  shares that cover it.
- Deprecation warnings in a default session or in the cron logs.

## 3. Constraints

- **Julia 1.10 and later.** CI runs Julia 1.10 and the latest stable release on Ubuntu and macOS.
- **Dependencies.** The SDK keeps `HTTP`, `JSON3`, `URIs`, `TOML`, and `Dates`, and adds
  `DataFrames`. The SDK keeps `JSON3`, not `JSON`, because the legacy structs carry a
  `raw::JSON3.Object` field.
- **Alpaca's multi-leg rules.** An atomic (`mleg`) order holds 2 to 4 option legs and no shares.
- **Alpaca's intent check.** Alpaca rejects a leg with a close intent unless the account holds
  that contract (error `42210000`, found in the May 2026 roll test).
- **Authentication.** Alpaca reads the key and secret from request headers, not from the URL.
  Every call therefore needs the client, which holds the credentials and the three base URLs
  (trading, stock data, options data).
- **Paper trading.** All live tests run against the paper API.
- **Newly exported names.** `0.4.0` exports `url`, `api`, `submit`, `cancel`, and `roll`. No repo
  under `~/Desktop/julia_work` other than this one loads `Alpaca`, and neither
  `VLQuantitativeFinancePackage` nor `VLDataScienceMachineLearningPackage` exports any of these
  names. The L13 course modules export `url` and `api`, so a session that loads a course module
  and `Alpaca` together must write `Alpaca.url` and `Alpaca.api`.

## 4. Approaches considered

1. **New core, with the legacy names as wrappers (chosen).** Each legacy function becomes a short
   wrapper. The wrapper builds a model, calls the new layer, and passes a private handler that
   returns the legacy struct. There is one code path, and all of it follows the lab style. The
   risk is drift in small behaviors, such as page merging or the `tradable_only` filter. The
   unchanged mock-server suite and the golden-output check in §9 guard against that drift.
2. **Freeze the legacy code next to the new code.** The current files move to `src/legacy/`
   untouched, and the new layer is written from scratch. The cron job carries no risk. But the
   retry logic and the URLs live in two places, so every fix has to be made twice, and the legacy
   files never reach the lab style.
3. **Freeze now, migrate later.** This starts as approach 2 and ends as approach 1, with a period
   where both copies are live.

Jeff chose approach 1 because only one code path meets the goal of a clean SDK. Building on a
branch and tagging only after the checks in §9 pass protects the cron job.

## 5. The new public API

### 5.1 Reading data: `url` and `api`

Each read endpoint has a model type. Reading has two steps, as in L13:

```julia
client = load_client()                                     # unchanged

model = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = Date(2025, 1, 1), finish = Date(2025, 6, 30))
url(client, model)          # the request URL of the first page, for inspection
bars = api(client, model)   # a DataFrame with every page
```

- `url(base::String, model)` builds the URL string, exactly as `url` does in L13.
  `url(client, model)` picks the right base URL from the client (trading, stock data, or options
  data) and calls `url(base, model)`. The model's abstract supertype selects the base URL.
- `api(client, model; handler = <default>)` sends the request with the auth headers, follows
  `next_page_token` until the last page, and returns the handler's result.
- The default handler of every read model returns a `DataFrame`. An endpoint that returns one
  record (the account, the clock, one asset, one order, one position, one contract) returns a
  one-row `DataFrame`.
- The `handler` keyword works as it does in L13. A handler is a function of the model type and
  the response body as a `String`: `handler(Type, body)`.
- A handler sees only the response. Any step that needs a value from the request happens outside
  the handler. Today two legacy functions have such a step: `list_assets` applies the
  `tradable_only` filter, and `get_latest_bar`, `get_latest_quote`, and `get_latest_trade` fill in
  the symbol that the caller passed. Their legacy wrappers keep doing those steps after `api`
  returns. The new latest-bar, latest-quote, and latest-trade handlers read the symbol from
  Alpaca's response.
- A missing value is `missing` in a `DataFrame` column. Timestamps are `DateTime` in UTC.
  Prices and sizes are `Float64`. The `raw` JSON is not a column.
- Bar, quote, and trade tables use descriptive column names. For bars, the columns are
  `timestamp`, `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, and `vwap`,
  the same names as the header of `write_bars_csv`. A snapshot table has one row per contract,
  with nested objects (the latest quote, the latest trade, the greeks) flattened into prefixed
  columns.

**Read models.** There is one model per endpoint, as in L13. Every model has a keyword
constructor whose keywords and defaults match the Alpaca query parameters that the legacy
function sends.

| Model | Endpoint | Base URL |
|---|---|---|
| `MyAccountEndpointModel` | `GET /account` | trading |
| `MyClockEndpointModel` | `GET /clock` | trading |
| `MyCalendarEndpointModel` | `GET /calendar` | trading |
| `MyAssetsEndpointModel` | `GET /assets` | trading |
| `MyAssetEndpointModel` | `GET /assets/{symbol}` | trading |
| `MyPositionsEndpointModel` | `GET /positions` | trading |
| `MyPositionEndpointModel` | `GET /positions/{symbol}` | trading |
| `MyOrdersEndpointModel` | `GET /orders` | trading |
| `MyOrderEndpointModel` | `GET /orders/{id}` or `GET /orders:by_client_order_id` | trading |
| `MyOptionContractsEndpointModel` | `GET /options/contracts` | trading |
| `MyOptionContractEndpointModel` | `GET /options/contracts/{symbol}` | trading |
| `MyStockBarsEndpointModel` | `GET /stocks/bars` | stock data |
| `MyStockQuotesEndpointModel` | `GET /stocks/quotes` | stock data |
| `MyStockTradesEndpointModel` | `GET /stocks/trades` | stock data |
| `MyStockLatestBarEndpointModel` | `GET /stocks/{symbol}/bars/latest` | stock data |
| `MyStockLatestQuoteEndpointModel` | `GET /stocks/{symbol}/quotes/latest` | stock data |
| `MyStockLatestTradeEndpointModel` | `GET /stocks/{symbol}/trades/latest` | stock data |
| `MyStockSnapshotsEndpointModel` | `GET /stocks/snapshots` | stock data |
| `MyOptionBarsEndpointModel` | `GET /options/bars` | options data |
| `MyOptionQuotesEndpointModel` | `GET /options/quotes` | options data |
| `MyOptionTradesEndpointModel` | `GET /options/trades` | options data |
| `MyOptionLatestBarEndpointModel` | `GET /options/bars/latest` | options data |
| `MyOptionLatestQuoteEndpointModel` | `GET /options/quotes/latest` | options data |
| `MyOptionLatestTradeEndpointModel` | `GET /options/trades/latest` | options data |
| `MyOptionSnapshotsEndpointModel` | `GET /options/snapshots` | options data |
| `MyOptionChainEndpointModel` | `GET /options/snapshots/{underlying}` | options data |

The `tradable_only` filter of `list_assets` is not an Alpaca query parameter, so
`MyAssetsEndpointModel` has no `tradable_only` field. New code filters the `DataFrame` on its
`tradable` column.

### 5.2 Trading: `submit`, `cancel`, `close`, `roll`

**Order models say what to trade. The verb says which direction, and the keywords say how.**

- `MyEquityOrderModel(; symbol, side, qty = nothing, notional = nothing)`. `side` is `"buy"` or
  `"sell"`. Exactly one of `qty` or `notional` is set.
- `MyOptionLegModel(; symbol, side, ratio = 1)`. `symbol` is the OCC contract symbol. `side` is
  `"buy"` (long the contract) or `"sell"` (short the contract). `ratio` is the number of
  contracts in one unit of the structure.
- `MyMixedOrderModel(; equity::MyEquityOrderModel, options::Vector{MyOptionLegModel})`. This
  model is a structure of shares and options, for example a covered call.

A leg has no position intent. The verb supplies the intent: `submit` opens each leg, `close`
reverses each leg, and `roll` closes the old legs and opens the new legs. A vertical spread is
described the way a trader writes it ("short the 540 put, long the 530 put"), and the same
vector of legs is passed to `submit`, `close`, and `roll`.

The order keywords, where they apply, are `qty` (the number of units of an option structure,
default `1`), `type`, `limit_price`, `stop_price`, `trail_price`, `trail_percent`,
`time_in_force`, `extended_hours`, and `client_order_id`. Their defaults match the legacy
functions: `type = "market"` for an equity or single-option order and `type = "limit"` for a
multi-leg order. For a multi-leg order, `limit_price` is the net price of one unit of the
structure (positive is a debit, negative is a credit), as Alpaca defines it.

| Call | What it sends | Returns |
|---|---|---|
| `submit(client, m::MyEquityOrderModel; ...)` | one equity order | `Order` |
| `submit(client, leg::MyOptionLegModel; ...)` | one option order, `*_to_open` | `Order` |
| `submit(client, legs::Vector{MyOptionLegModel}; ...)` | 1 leg: one option order. 2–4 legs: one atomic `mleg` order, every leg `*_to_open`. More than 4 legs: `ArgumentError`, nothing sent | `Order` |
| `submit(client, m::MyMixedOrderModel; ...)` | the equity order, then the option order after the equity order fills (§5.3) | `Vector{Order}` in the sequence sent |
| `cancel(client, order::Order)`, `cancel(client, id::String)` | cancels an order that has not filled | `nothing` |
| `cancel(client; all = true)` | cancels every open order | the per-order cancel status |
| `close(client, symbol::String; qty, percentage)` | Alpaca's liquidate endpoint for one holding, at market | `Order` |
| `close(client; all = true, cancel_orders = false)` | Alpaca's liquidate-all endpoint | the per-position status |
| `close(client, m::MyEquityOrderModel; ...)` | one equity order on the opposite side, same quantity | `Order` |
| `close(client, leg::MyOptionLegModel; ...)` | one option order on the opposite side, `*_to_close` | `Order` |
| `close(client, legs::Vector{MyOptionLegModel}; ...)` | one atomic `mleg` order that reverses every leg, `*_to_close`. Same leg-count rules as `submit` | `Order` |
| `close(client, order::Order; ...)` | the reverse of a filled order that `submit` returned, using the filled quantities. An unfilled order raises an `ArgumentError` that says to use `cancel` | `Order` |
| `close(client, m::MyMixedOrderModel; ...)` | the reverse option order, then the reverse equity order after the option order fills (§5.3) | `Vector{Order}` |
| `roll(client, from, to; ...)` | one atomic `mleg` order: every `from` leg reversed with `*_to_close`, every `to` leg with `*_to_open`. `from` and `to` are each a `MyOptionLegModel` or a `Vector{MyOptionLegModel}`; `from` may also be a filled `Order`. More than 4 legs in total: `ArgumentError`, nothing sent | `Order` |

`roll` covers a single contract (2 legs) and a vertical spread (4 legs). An iron condor needs 8
legs, so it rolls as two `roll` calls, one per wing. The pair of calls is not atomic, and the
docstring says so. `roll` never splits a structure on its own, so one `roll` call always sends
one atomic order. `roll` takes no equity, because rolling applies only to options.

`close` extends `Base.close` with new methods on `AlpacaClient`. A separate `Alpaca.close`
function would clash with `Base.close` for every user who runs `using Alpaca`.

**Orders from an earlier session.** Every read returns a `DataFrame`, including the order
reads, so new code gets an `Order` value only from `submit`, `close`, or `roll` in the same
session. Across sessions, `close` and `roll` take the legs that the strategy layer stored, and
`cancel` takes the order id from the `id` column of an orders `DataFrame`. The methods that take
an `Order` are a convenience for the same session. *(Call made during review: keep one rule for
reads instead of adding an `Order`-returning handler to the public surface.)*

### 5.3 Equity and options together (`MyMixedOrderModel`)

Alpaca cannot fill shares and options in one atomic order, so a mixed structure goes out as two
orders in a fixed sequence. The sequence keeps a short call covered at every step.

- `submit` sends the equity order first. The SDK polls the equity order until it fills, and then
  sends the option order (one leg as a single order, 2–4 legs as one `mleg` order).
- `close` sends the reverse option order first. After the option order fills, the SDK sends the
  reverse equity order.
- The SDK waits only on the first order, because only the first fill protects the account. The
  keyword `fill_timeout` (seconds) bounds that wait. If the first order does not fill in time,
  the SDK cancels the first order, sends nothing else, and throws an error that holds the first
  `Order`.
- The SDK does not wait on the second order. The returned `Vector{Order}` holds the filled first
  order and the second order as Alpaca accepted it, which may still be resting. A resting second
  order leaves the account covered: during `submit` the shares are already held, and during
  `close` the call is already bought back.
- The second order fails when Alpaca rejects the request. The SDK then throws an error that
  holds the filled first `Order` and the `AlpacaError` of the second request, so the caller knows
  which part filled. The account then holds the shares without the short call, which is a
  covered state.
- The equity part trades at market. The `type` and `limit_price` keywords apply to the option
  part. The `qty` keyword multiplies only the option legs. The share quantity is the `qty` field
  of the equity model.

*(Calls made during review: wait only on the first order; the coverage check below.)*

Before sending anything, `submit` checks that the shares cover every short call in the model.
When any option leg sells a call:

- the equity side must be `"buy"`;
- the equity model must set `qty`, not `notional`;
- the share quantity must be at least `100 × qty × ` the sum of the `ratio` values of the short
  call legs, where `100` is the standard contract multiplier.

A model that fails the check raises an `ArgumentError`, and nothing is sent. The check does not
cover short puts, because Alpaca checks the buying power that secures them.

The May 2026 design left equity-and-option combinations to the caller. Jeff asked for
mixed structures in this redesign, so the SDK now provides the sequence.

## 6. Legacy names

Every legacy name stays exported with the same signature and return value. Each one moves to
`src/Legacy.jl`, where its body does three things:

1. It calls `Base.depwarn` with a message that names the replacement call, for example
   ``"`get_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead"``.
2. It builds the matching model.
3. It calls the new layer (`api`, or a private trading function) with a private handler that
   returns the legacy value.

`Base.depwarn` is silent in a default session, so the cron logs stay clean. It prints under
`Pkg.test` and under `julia --depwarn=yes`. Under `--depwarn=error`, every legacy call becomes an
error, which finds the legacy calls left in a downstream repo. This behavior was checked on
Julia 1.12.7.

`submit_multileg_order` accepts `OrderLeg` values with explicit position intents, including the
mixed intents of the 4-leg roll test. The new public models have no intent field, so the legacy
wrapper calls a private multi-leg function that takes explicit intents. `submit`, `close`, and
`roll` call the same private function.

`submit_order` with an option symbol sends no `position_intent` today. The legacy wrapper calls
the private single-order function directly, not `submit(client, ::MyOptionLegModel)`, so the
request stays unchanged.

| Legacy call | Replacement |
|---|---|
| `get_account(client)` | `api(client, MyAccountEndpointModel())` |
| `get_clock(client)` | `api(client, MyClockEndpointModel())` |
| `get_calendar(client; start, finish)` | `api(client, MyCalendarEndpointModel(start = ..., finish = ...))` |
| `list_assets(client; ...)` | `api(client, MyAssetsEndpointModel(...))` |
| `get_asset(client, symbol)` | `api(client, MyAssetEndpointModel(symbol = ...))` |
| `list_positions(client)` | `api(client, MyPositionsEndpointModel())` |
| `get_position(client, symbol)` | `api(client, MyPositionEndpointModel(symbol = ...))` |
| `close_position(client, symbol; qty, percentage)` | `close(client, symbol; qty, percentage)` |
| `close_all_positions(client; cancel_orders)` | `close(client; all = true, cancel_orders)` |
| `list_orders(client; ...)` | `api(client, MyOrdersEndpointModel(...))` |
| `get_order(client, id; by_client_order_id)` | `api(client, MyOrderEndpointModel(...))` |
| `submit_order(client, symbol, qty, side; ...)` | `submit(client, MyEquityOrderModel(...); ...)`, or `submit(client, MyOptionLegModel(...); ...)` for an option symbol |
| `submit_multileg_order(client, legs; ...)` | `submit`, `close`, or `roll` with `MyOptionLegModel` legs |
| `cancel_order(client, id)` | `cancel(client, id)` |
| `cancel_all_orders(client)` | `cancel(client; all = true)` |
| `get_bars`, `get_quotes`, `get_trades` | `api` with `MyStockBarsEndpointModel`, `MyStockQuotesEndpointModel`, `MyStockTradesEndpointModel` |
| `get_latest_bar`, `get_latest_quote`, `get_latest_trade` | `api` with the `MyStockLatest*EndpointModel` types |
| `get_snapshot` | `api(client, MyStockSnapshotsEndpointModel(...))` |
| `download_bars` | `api(client, MyStockBarsEndpointModel(...))`, which follows every page |
| `write_bars_csv`, `read_bars_csv` | No replacement. The bars `DataFrame` can be written with the caller's CSV package |
| `list_option_contracts`, `get_option_contract` | `api` with `MyOptionContractsEndpointModel`, `MyOptionContractEndpointModel` |
| `get_option_bars`, `get_option_quotes`, `get_option_trades` | `api` with `MyOptionBarsEndpointModel`, `MyOptionQuotesEndpointModel`, `MyOptionTradesEndpointModel` |
| `get_latest_option_bar`, `get_latest_option_quote`, `get_latest_option_trade` | `api` with the `MyOptionLatest*EndpointModel` types |
| `get_option_snapshots` | `api(client, MyOptionSnapshotsEndpointModel(...))` |
| `get_option_chain_snapshot` | `api(client, MyOptionChainEndpointModel(...))` |
| `OrderLeg(...)` | `MyOptionLegModel(...)` |

The legacy return types (`Account`, `Asset`, `Position`, `Bar`, `Quote`, `Trade`, `MarketClock`,
`CalendarDay`, `OptionContract`, `OptionGreeks`, `OptionSnapshot`, `OrderLeg`) stay exported and
unchanged, and their docstrings say they are legacy types. `Order`, `AlpacaError`, and
`AlpacaClient` are part of the new API.

## 7. Source layout

The layout follows L13b. The module file imports the packages, lists the exports, and includes
the files in dependency order.

| File | Contents |
|---|---|
| `src/Alpaca.jl` | the module: imports, exports, includes |
| `src/Types.jl` | `AlpacaClient`, `AlpacaError`, the abstract model types, the read models, the order models, and the response structs |
| `src/Factory.jl` | the `url(...)` methods |
| `src/Network.jl` | the private HTTP call (auth headers, retry with backoff on `429`, error decoding) and the public `api(...)` |
| `src/Handler.jl` | the default handlers that return `DataFrame` values, and the private legacy handlers that return the legacy structs |
| `src/Trading.jl` | `submit`, `cancel`, `close`, `roll`, the private multi-leg function, and the fill polling for mixed structures |
| `src/Utility.jl` | `load_client` and the private parsing helpers (`_parse_rfc3339`, `_parse_float`, ...) |
| `src/Legacy.jl` | every deprecated name |
| `src/streaming.jl` | unchanged |

## 8. Code style

New and rewritten code follows the style of L13b `src/`:

- Each public function has a docstring with `### Arguments`, `### Returns`, and `### Throws`
  sections. Each type has `### Fields` and `### Constructors` sections.
- Endpoint and order models are `mutable struct` types with keyword constructors, as in
  L13b `src/Types.jl`.
- Files use the `# --- PUBLIC METHODS BELOW HERE ---` and `# --- PRIVATE METHODS BELOW HERE ---`
  banners.
- Code uses explicit loops and `if` blocks, with a comment that says what each step does.
- Code has no inner or nested functions, closures, `do` blocks, ternary chains, or
  `x || throw(...)` / `x && return` one-liners.
- Private names start with an underscore.

## 9. Verification

- **Unchanged mock-server suite.** The existing files in `test/` are not edited. Only
  `test/runtests.jl` gains `include` lines for the new test files. The full suite must pass.
- **Golden outputs.** Before any rewrite, a script runs every legacy function against fixed mock
  responses on `v0.3.1` and saves each result. After the rewrite, a test runs the same calls and
  compares the results field by field. This check covers return values that the existing suite
  does not assert.
- **New mock tests.** For every read model, the tests check the URL that `url` builds and the
  columns and values of the `DataFrame` that `api` returns, including a multi-page response. For
  every trading verb, the tests check the request body, including the reversed sides and intents
  of `close` and `roll`, the refusal of more than 4 legs, the coverage check, and the mixed
  sequence: the order of the two requests, the timeout on the first order, and the error after a
  rejection of the second order.
- **Deprecation tests.** One test per legacy name confirms that the name emits a deprecation
  warning (`@test_deprecated`).
- **Live paper tests.** New tests gated by `ALPACA_LIVE_TESTS=1` open and close a vertical spread,
  roll a vertical spread, and open and close a covered call through the new verbs. The existing
  live tests also run. The live tests run only when the market is open.
- **Release.** The work happens on a branch. The version becomes `0.4.0`. Nothing is pushed or
  tagged until Jeff gives the go-ahead, after the mock suite and the live run both pass.

## 10. Documentation

- The README shows only the new API: `load_client`, a read with `url` and `api`, and a spread
  with `submit`, `close`, and `roll`.
- The Documenter site gets pages for the models, for reading data, for trading, for streaming,
  and one "Legacy API" page with the table from §6.
- Each legacy docstring opens with a deprecation notice that names the replacement.

## 11. Left to the builder

- How `api` merges the results of several pages: a handler called once per page with a private
  merge step, or a handler called once on all page bodies. The legacy results must match the
  golden outputs, including order across pages.
- The exact `DataFrame` columns of each endpoint other than bars, within the rules of §5.1.
- The return shapes of `cancel(client; all = true)` and `close(client; all = true)`.
- The polling interval and the default `fill_timeout` for mixed structures.
- How `close(client, order::Order)` recovers each leg's ratio from the `Order` value.
- Whether a deprecation warning in the `OrderLeg` constructor is practical.
- The underlying and the size of the live covered-call test, so the test fits the paper account.
