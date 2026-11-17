# Lab-standard redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the public API of `Alpaca.jl` on the CHEME 5800 L13 pattern (endpoint models plus the verbs `url`, `api`, `submit`, `cancel`, `close`, `roll`), and keep every legacy name working as a deprecated wrapper over the new code.

**Architecture:** Read endpoints become `My*EndpointModel` types. `url(base, model)` builds the request URL, and `api(client, model; handler)` sends it, follows pages, and returns a `DataFrame` by default. Trading uses order models (`MyEquityOrderModel`, `MyOptionLegModel`, `MyMixedOrderModel`) and the verbs `submit`, `cancel`, `close` (methods on `Base.close`), and `roll`. Every legacy function moves to `src/Legacy.jl`, emits `Base.depwarn`, and calls the new layer with a private handler that returns the legacy value.

**Tech Stack:** Julia ≥ 1.10, HTTP.jl, JSON3.jl, URIs.jl, TOML, Dates, DataFrames.jl (new), Test, Documenter.

**Spec:** `docs/superpowers/specs/2026-11-17-lab-standard-redesign-design.md`. Read it before starting any task. Section numbers (§) below refer to it.

## Global Constraints

- Julia `1.10` and later. CI runs `1.10` and the latest stable release.
- Package dependencies: `HTTP`, `JSON3`, `URIs`, `TOML`, `Dates`, plus `DataFrames` with compat `"1"`. Do not add `JSON` or any other package.
- Code style in `src/` (§8), except `src/streaming.jl`, which stays unchanged: each public function has a docstring with `### Arguments`, `### Returns`, `### Throws`; each type has `### Fields` and `### Constructors`; models are `mutable struct` types with keyword constructors; files use the `# --- PUBLIC METHODS BELOW HERE ---` / `# --- PRIVATE METHODS BELOW HERE ---` banners; explicit loops and `if` blocks with a comment on each step; no inner or nested functions, closures, `do` blocks, ternary chains, or `x || throw(...)` / `x && return` one-liners; private names start with `_`. Tests may use `do` blocks and closures.
- Legacy calls send the same requests and return the same values as `v0.3.1`. The golden test (Task 1) and the unchanged test files prove it.
- The existing files in `test/` are never edited. The only exceptions are new `include` lines in `test/runtests.jl` and new entries in `test/Project.toml`.
- New test files define their payload constants with the prefix `_N_`, so they never collide with the `const` names in the existing test files (`_BAR_1`, `_ORDER_PAYLOAD`, ...).
- Every legacy function body starts with `Base.depwarn(msg, :name)`, where `msg` has the form ``"`get_bars` is deprecated, use `api(client, MyStockBarsEndpointModel(...))` instead"``. Every legacy docstring opens with a `!!! warning "Deprecated"` admonition that names the replacement from §6. A legacy wrapper never calls another legacy name.
- `close` methods are defined as `function Base.close(client::AlpacaClient, ...)`. There is no separate `Alpaca.close`.
- Numeric and date query fields store the value as the caller gave it (`Union{Nothing,Real}`, `Union{Nothing,Date,String}`), and `url` writes it with `string(x)`, so `strike_price_gte = 140` still sends `140`, not `140.0`.
- macOS has a case-insensitive file system. Rename `src/types.jl` to `src/Types.jl` in two steps: `git mv src/types.jl src/Types_tmp.jl && git mv src/Types_tmp.jl src/Types.jl`.
- Work on the branch `lab-standard-redesign`. Commit after each task. Never push or tag. The version becomes `0.4.0`.
- Test command: `julia --project=. -e 'using Pkg; Pkg.test()'`. Expected: every testset passes, and the live tests report `skipping live integration tests`.

## Review Focus

1. **Empty responses.** A read that matches nothing (no bars, no orders) returns a 0-row `DataFrame` with the endpoint's full column list, not a 0-column `DataFrame`. Test in Task 6 (bars) and Task 5 (orders).
2. **Timestamps with an offset.** Alpaca's clock sends times such as `2026-11-18T09:30:00-05:00`. The new handlers convert the time to UTC (`DateTime(2026,11,18,14,30)`). The legacy `_parse_rfc3339` keeps its current behavior. Test in Task 5.
3. **Closing a partly filled order.** `close(client, order)` on an order whose status is not `"filled"` (including `"partially_filled"`) raises an `ArgumentError` that tells the caller to `cancel` first. Test in Task 10.
4. **Invalid legs.** `MyOptionLegModel` with a `side` other than `"buy"` or `"sell"`, or a `ratio` below `1`, raises an `ArgumentError` in the constructor. Test in Task 9.
5. **Empty page token.** `api` stops following pages when `next_page_token` is missing, `null`, or `""`. Test in Task 4.

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `src/Alpaca.jl` | module: imports, exports, includes | 2, then each task adds exports |
| `src/Types.jl` | `AlpacaClient`, `AlpacaError`, abstract types, read models, order models, `AlpacaSequenceError`, legacy response structs | 2, 3, 9, 11 |
| `src/Utility.jl` | `load_client`, `_derive_options_url`, parse and format helpers | 2, 5 |
| `src/Factory.jl` | `url(...)` methods, `_base_url`, `_is_paginated` | 3 |
| `src/Network.jl` | `_http_call`, `api`, `_merge`, `_next_page_token`; the legacy `_request` until Task 12 | 2, 4 |
| `src/Handler.jl` | `_default_handler` (DataFrames), `_legacy_handler` (legacy values), struct parsers | 5, 6, 7, 8 |
| `src/Trading.jl` | `submit`, `cancel`, `Base.close`, `roll`, private order functions, fill polling | 9, 10, 11 |
| `src/Legacy.jl` | every deprecated name | 7, 8, 12 |
| `src/streaming.jl` | unchanged | — |
| `test/golden/` | fixtures, canonical form, golden calls, capture script, `golden-v0.3.1.jsonl` | 1 |
| `test/test_golden.jl` | compares legacy outputs and requests to the golden file | 1 |
| `test/test_models_url.jl`, `test_api.jl`, `test_handlers_trading.jl`, `test_handlers_marketdata.jl`, `test_trading_submit.jl`, `test_trading_close_roll.jl`, `test_trading_mixed.jl`, `test_deprecations.jl`, `test_integration_verbs.jl` | new tests | 3–14 |

Files deleted along the way: `src/client.jl` (Task 2); `src/account.jl`, `src/clock.jl`, `src/assets.jl` (Task 7); `src/marketdata.jl`, `src/options.jl`, `src/historical.jl` (Task 8); `src/orders.jl`, `src/positions.jl` (Task 12).

---

### Task 1: Branch and golden outputs of v0.3.1

The golden file records what every legacy call returns and sends today. It must be captured before any file in `src/` changes.

**Files:**
- Create: `test/golden/fixtures.jl`, `test/golden/canonical.jl`, `test/golden/calls.jl`, `test/golden/capture.jl`, `test/golden/golden-v0.3.1.jsonl`, `test/test_golden.jl`
- Modify: `test/runtests.jl` (add `include("test_golden.jl")` after `include("test_integration.jl")`)
- Commit also: the spec and this plan.

**Interfaces:**
- Produces: `golden_handler(req::HTTP.Request)::HTTP.Response`; `golden_canonical(x)`; `GOLDEN_CALLS::Vector{Tuple{String,Function}}` where each function takes the client; `run_golden_call(f)::Tuple{Any,Vector}` returning `(canonical_result, canonical_requests)`.

- [ ] **Step 1: Create the branch and commit the spec and plan**

```bash
git checkout -b lab-standard-redesign
git add docs/superpowers/specs/2026-11-17-lab-standard-redesign-design.md docs/superpowers/plans/2026-11-17-lab-standard-redesign.md
git commit -m "Add design and plan for the lab-standard redesign"
```

- [ ] **Step 2: Write `test/golden/fixtures.jl`**

`golden_handler` routes by method and path and returns deterministic JSON. Requirements:
- Every path that a legacy function calls has a route.
- Every paginated route (`/stocks/bars`, `/stocks/quotes`, `/stocks/trades`, `/options/bars`, `/options/quotes`, `/options/trades`, `/options/contracts`, `/options/snapshots/{underlying}`) returns two pages: without `page_token` it returns page 1 with `"next_page_token" => "p2"`, and with `page_token=p2` it returns page 2 with `"next_page_token" => nothing`. Page 1 and page 2 both carry data for the same symbol, so page merging is exercised.
- Optional fields appear both present and absent across records (`n`/`vw` on bars, `filled_at` on orders, greeks on one option snapshot and not on another).
- The latest stock bar, quote, and trade responses omit `symbol`, as the existing test mocks do.
- `POST /orders` returns `_N_`-style order JSON; when the request body's `symbol` is `"FAIL"`, it returns status `422` with `{"code": 40010001, "message": "qty must be positive"}`. A multi-leg request (`order_class == "mleg"`) returns a parent order with two `legs`.
- `/clock` returns times with a `-05:00` offset.

- [ ] **Step 3: Write `test/golden/canonical.jl`**

`golden_canonical(x)` turns any value into nested arrays and strings, so `JSON3.write` output is deterministic:
- `nothing` → `nothing`; a leaf (`Number`, `Bool`, `String`, `Symbol`, `Date`, `DateTime`, `Time`) → `[string(typeof(x)), string(x)]`;
- `JSON3.Object` / `JSON3.Array` → `["JSON3", JSON3.write(x)]`;
- `AbstractVector` → `["Vector", string(eltype(x)), [golden_canonical(v) for v in x]]`; a `Tuple` → `["Tuple", [golden_canonical(v) for v in x]]`;
- `AbstractDict` → `["Dict", string(typeof(x)), sorted [[string(k), golden_canonical(v)] ...]]`;
- `Exception` and any struct → `["struct", string(nameof(typeof(x))), [[string(f), golden_canonical(getfield(x, f))] for f in fieldnames(typeof(x))]]`.

A recorded request becomes `[method, path, sort(split(query, '&')), body_canonical]`, where `body_canonical` is `nothing` for an empty body and `golden_canonical(JSON3.read(body))` otherwise. Sorting the query pairs makes a change in parameter order invisible, and any other change visible.

- [ ] **Step 4: Write `test/golden/calls.jl`**

`GOLDEN_CALLS` holds one entry per call below. `run_golden_call(f)` starts `with_mock(recording_handler(golden_handler)...)`, runs `f(client)` under `Logging.NullLogger()`, catches an exception as the result, and returns `(golden_canonical(result), canonical requests)`.

| Name | Call |
|---|---|
| `account` | `get_account(c)` |
| `clock` | `get_clock(c)` |
| `calendar` | `get_calendar(c; start = Date(2026,11,16), finish = Date(2026,11,17))` |
| `calendar_noargs` | `get_calendar(c)` |
| `assets` | `list_assets(c)` |
| `assets_all` | `list_assets(c; tradable_only = false)` |
| `asset` | `get_asset(c, "AAPL")` |
| `positions` | `list_positions(c)` |
| `position` | `get_position(c, "AAPL")` |
| `close_position` | `close_position(c, "AAPL"; qty = 5)` |
| `close_all_positions` | `close_all_positions(c; cancel_orders = true)` |
| `orders` | `list_orders(c; status = "all", symbols = ["AAPL","MSFT"], after = DateTime(2026,1,1))` |
| `order` | `get_order(c, "ord-1")` |
| `order_by_client_id` | `get_order(c, "cid-1"; by_client_order_id = true)` |
| `submit_limit` | `submit_order(c, "AAPL", 10, "buy"; type = "limit", limit_price = 150.25, client_order_id = "cid-9")` |
| `submit_notional` | `submit_order(c, "AAPL", nothing, "buy"; notional = 500)` |
| `submit_option` | `submit_order(c, "SPY261218C00600000", 1, "buy")` |
| `submit_error` | `submit_order(c, "FAIL", 10, "buy")` |
| `submit_mleg` | `submit_multileg_order(c, [OrderLeg("SPY261218P00540000", 1, "sell", "sell_to_open"), OrderLeg("SPY261218P00530000", 1, "buy", "buy_to_open")]; limit_price = -1.25, qty = 2)` |
| `cancel_order` | `cancel_order(c, "ord-1")` |
| `cancel_all_orders` | `cancel_all_orders(c)` |
| `bars` | `get_bars(c, ["AAPL","MSFT"], "1Day"; start = Date(2025,1,2), finish = Date(2025,1,3))` |
| `quotes` | `get_quotes(c, "AAPL"; start = DateTime(2025,1,2,14,30))` |
| `trades` | `get_trades(c, "AAPL"; start = DateTime(2025,1,2,14,30), limit = 5)` |
| `latest_bar` / `latest_quote` / `latest_trade` | `get_latest_bar(c, "AAPL")`, `get_latest_quote(c, "AAPL")`, `get_latest_trade(c, "AAPL"; feed = "sip")` |
| `snapshot` | `get_snapshot(c, ["AAPL","MSFT"])` |
| `download_bars` | `download_bars(c, "AAPL", "1Day"; start = Date(2025,1,1), finish = Date(2025,3,31), chunk_months = 1)` |
| `bars_csv` | write the `bars` result for `"AAPL"` with `write_bars_csv` to a temp file, then return `(read(path, String), read_bars_csv(path))` |
| `option_contracts` | `list_option_contracts(c; underlying_symbols = "SPY", expiration_date_gte = Date(2026,12,1), strike_price_gte = 140, type = "put")` |
| `option_contract` | `get_option_contract(c, "SPY261218P00500000")` |
| `option_bars` / `option_quotes` / `option_trades` | `get_option_bars(c, ["SPY261218P00500000"], "1Day"; start = Date(2026,11,2))`, `get_option_quotes(c, "SPY261218P00500000"; start = Date(2026,11,2))`, `get_option_trades(c, "SPY261218P00500000"; start = Date(2026,11,2), finish = Date(2026,11,3))` |
| `option_latest_bar` / `_quote` / `_trade` | `get_latest_option_bar(c, ["SPY261218P00500000","SPY261218C00600000"])` and the quote and trade versions |
| `option_snapshots` | `get_option_snapshots(c, ["SPY261218P00500000","SPY261218C00600000"])` |
| `option_chain` | `get_option_chain_snapshot(c, "SPY"; type = "call", strike_price_gte = 140, expiration_date = Date(2026,12,18), limit = 2)` |

- [ ] **Step 5: Write `test/golden/capture.jl` and capture**

The script includes `../mock_server.jl`, `fixtures.jl`, `canonical.jl`, and `calls.jl`, runs every call, and writes one line per call to `test/golden/golden-v0.3.1.jsonl`: `JSON3.write([name, result, requests])`.

Run: `julia --project=. test/golden/capture.jl`
Expected: the file has one line per entry of `GOLDEN_CALLS`, and the `bars` line shows two requests to `/stocks/bars`.

- [ ] **Step 6: Write `test/test_golden.jl`**

```julia
@testset "golden: legacy outputs match v0.3.1" begin
    golden = Dict{String,String}()
    for line in readlines(joinpath(@__DIR__, "golden", "golden-v0.3.1.jsonl"))
        entry = JSON3.read(line)
        golden[String(entry[1])] = line
    end
    for (name, f) in GOLDEN_CALLS
        result, requests = run_golden_call(f)
        @test JSON3.write([name, result, requests]) == golden[name]
    end
end
```

`test/test_golden.jl` includes `golden/fixtures.jl`, `golden/canonical.jl`, and `golden/calls.jl` at its top.

- [ ] **Step 7: Run the full suite**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: all testsets pass, including `golden: legacy outputs match v0.3.1`.

- [ ] **Step 8: Commit**

```bash
git add test/golden test/test_golden.jl test/runtests.jl
git commit -m "Capture golden outputs of the v0.3.1 legacy API"
```

---

### Task 2: Lab file layout, no behavior change

**Files:**
- Rename: `src/types.jl` → `src/Types.jl` (two-step `git mv`, see Global Constraints)
- Create: `src/Utility.jl`, `src/Network.jl`
- Delete: `src/client.jl`
- Modify: `src/Alpaca.jl`, `Project.toml`, `test/Project.toml`

**Interfaces:**
- Produces in `src/Types.jl`: `AlpacaClient` (5-field struct and the 4-argument constructor, unchanged) and the abstract types
  `AbstractAlpacaEndpointModel`, `AbstractAlpacaTradingEndpointModel <: AbstractAlpacaEndpointModel`, `AbstractAlpacaStockDataEndpointModel <: AbstractAlpacaEndpointModel`, `AbstractAlpacaOptionDataEndpointModel <: AbstractAlpacaEndpointModel`, `AbstractAlpacaOrderModel`, each with a docstring.
- `src/Utility.jl`: `DEFAULT_DATA_URL`, `DEFAULT_OPTIONS_DATA_URL`, `load_client`, `_derive_options_url`, `_parse_float`, `_parse_float_default`, `_parse_int`, `_parse_rfc3339`, `_parse_date_maybe`, and, moved from `src/marketdata.jl`, `_fmt_ts` and `_symbols_param`.
- `src/Network.jl`: `_auth_headers`, `_join_url`, `_build_url`, `_handle_response`, `_request`, `_MAX_RETRIES`, `_INITIAL_BACKOFF`, `_trading_get`, `_trading_post`, `_trading_delete`, `_data_get`, `_options_data_get`.

- [ ] **Step 1: Move the code**

Move each definition listed above verbatim; do not restyle in this task. `src/Alpaca.jl` imports `DataFrames` (`import DataFrames: DataFrame`) in addition to the current packages, exports the five abstract types, and includes, in order: `Types.jl`, `Utility.jl`, `Network.jl`, `account.jl`, `clock.jl`, `assets.jl`, `orders.jl`, `positions.jl`, `marketdata.jl`, `historical.jl`, `options.jl`, `streaming.jl`.

- [ ] **Step 2: Add `DataFrames`**

Run: `julia --project=. -e 'using Pkg; Pkg.add("DataFrames")'` and `julia --project=test -e 'using Pkg; Pkg.add("DataFrames")'`, then add `DataFrames = "1"` to `[compat]` in `Project.toml`.

- [ ] **Step 3: Run the full suite**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: all testsets pass, including the golden test.

- [ ] **Step 4: Commit**

```bash
git add -A src Project.toml test/Project.toml
git commit -m "Split client.jl into the lab layout: Types, Utility, Network"
```

---

### Task 3: Read models and `url`

**Files:**
- Modify: `src/Types.jl` (26 read models), `src/Alpaca.jl` (include `Factory.jl` after `Network.jl`; export `url` and the models)
- Create: `src/Factory.jl`, `test/test_models_url.jl`
- Modify: `test/runtests.jl` (include `test_models_url.jl`)

**Interfaces:**
- Produces: the 26 models of §5.1, each a `mutable struct` subtype of the abstract type for its base URL. Keyword constructors, fields, and defaults:

| Model | Fields and defaults (no default = required keyword) |
|---|---|
| `MyAccountEndpointModel`, `MyClockEndpointModel`, `MyPositionsEndpointModel` | none |
| `MyCalendarEndpointModel` | `start = nothing`, `finish = nothing` (`Union{Nothing,Date,String}`) |
| `MyAssetsEndpointModel` | `status = "active"`, `asset_class = "us_equity"` |
| `MyAssetEndpointModel`, `MyPositionEndpointModel`, `MyOptionContractEndpointModel` | `symbol` |
| `MyOrdersEndpointModel` | `status = "open"`, `limit = 50`, `after = nothing`, `until = nothing` (`Union{Nothing,String,DateTime}`), `direction = "desc"`, `symbols = nothing` (`Union{Nothing,Vector{String}}`) |
| `MyOrderEndpointModel` | `id = nothing`, `client_order_id = nothing`; exactly one must be set, else `ArgumentError` |
| `MyOptionContractsEndpointModel` | `underlying_symbols`, `status = "active"`, `expiration_date`, `expiration_date_gte`, `expiration_date_lte` (`= nothing`, `Union{Nothing,Date,String}`), `strike_price_gte`, `strike_price_lte` (`= nothing`, `Union{Nothing,Real}`), `type = nothing`, `style = nothing`, `limit = 1000` |
| `MyStockBarsEndpointModel` | `symbols`, `timeframe`, `start`, `finish = nothing`, `limit = 1000`, `adjustment = "raw"`, `feed = "iex"` |
| `MyStockQuotesEndpointModel`, `MyStockTradesEndpointModel` | `symbols`, `start`, `finish = nothing`, `limit = 1000`, `feed = "iex"` |
| `MyStockLatestBarEndpointModel`, `MyStockLatestQuoteEndpointModel`, `MyStockLatestTradeEndpointModel` | `symbol`, `feed = "iex"` |
| `MyStockSnapshotsEndpointModel` | `symbols`, `feed = "iex"` |
| `MyOptionBarsEndpointModel` | `symbols`, `timeframe`, `start`, `finish = nothing`, `limit = 1000` |
| `MyOptionQuotesEndpointModel`, `MyOptionTradesEndpointModel` | `symbols`, `start`, `finish = nothing`, `limit = 1000` |
| `MyOptionLatestBarEndpointModel`, `MyOptionLatestQuoteEndpointModel`, `MyOptionLatestTradeEndpointModel`, `MyOptionSnapshotsEndpointModel` | `symbols` |
| `MyOptionChainEndpointModel` | `underlying`, `type`, `strike_price_gte`, `strike_price_lte`, `expiration_date`, `expiration_date_gte`, `expiration_date_lte` (all `= nothing`), `limit = 1000` |

`symbols`, `underlying_symbols`: the field is `Vector{String}`; the keyword accepts a `String` or a vector of strings. `start`, `finish`: `Union{String,Date,DateTime}` (finish also `Nothing`).

- Produces in `src/Factory.jl`: `url(base::String, model::<each model>)::String`; `url(client::AlpacaClient, model::AbstractAlpacaEndpointModel)::String`; private `_base_url(client, model)::String` (by abstract type: `trading_url`, `data_url`, `options_data_url`); private `_is_paginated(model)::Bool`, `true` only for the stock and option bars, quotes, and trades models, `MyOptionContractsEndpointModel`, and `MyOptionChainEndpointModel`.

URL rules: query parameters appear in the field order of the table, a `nothing` field is left out, the URL has no `?` when no parameter is set, keys and values pass through `URIs.escapeuri`, `start`/`finish` pass through `_fmt_ts` and are sent as `start` and `end`, `after`/`until`/dates/strikes pass through `string`, and `symbols` lists are joined with `,`. Path segments (`symbol`, `id`, `underlying`) are inserted unescaped, as today.

- [ ] **Step 1: Write the failing tests in `test/test_models_url.jl`**

```julia
@testset "url: stock bars" begin
    m = MyStockBarsEndpointModel(symbols = ["AAPL", "MSFT"], timeframe = "1Day",
                                 start = Date(2025, 1, 2), finish = Date(2025, 1, 3))
    @test url("http://h", m) == "http://h/stocks/bars?symbols=AAPL%2CMSFT&timeframe=1Day&start=2025-01-02&end=2025-01-03&limit=1000&adjustment=raw&feed=iex"
    m2 = MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Min", start = DateTime(2025, 1, 2, 14, 30))
    @test url("http://h", m2) == "http://h/stocks/bars?symbols=AAPL&timeframe=1Min&start=2025-01-02T14%3A30%3A00Z&limit=1000&adjustment=raw&feed=iex"
end

@testset "url: trading endpoints" begin
    @test url("http://h", MyAccountEndpointModel()) == "http://h/account"
    @test url("http://h", MyCalendarEndpointModel()) == "http://h/calendar"
    @test url("http://h", MyCalendarEndpointModel(start = Date(2026, 11, 16), finish = Date(2026, 11, 17))) ==
          "http://h/calendar?start=2026-11-16&end=2026-11-17"
    @test url("http://h", MyOrdersEndpointModel(symbols = ["AAPL", "MSFT"])) ==
          "http://h/orders?status=open&limit=50&direction=desc&symbols=AAPL%2CMSFT"
    @test url("http://h", MyOrderEndpointModel(id = "ord-1")) == "http://h/orders/ord-1"
    @test url("http://h", MyOrderEndpointModel(client_order_id = "cid-1")) ==
          "http://h/orders:by_client_order_id?client_order_id=cid-1"
    @test_throws ArgumentError MyOrderEndpointModel()
    @test_throws ArgumentError MyOrderEndpointModel(id = "a", client_order_id = "b")
end

@testset "url: options endpoints" begin
    m = MyOptionChainEndpointModel(underlying = "SPY", type = "call", strike_price_gte = 140,
                                   expiration_date = Date(2026, 12, 18))
    @test url("http://h", m) == "http://h/options/snapshots/SPY?type=call&strike_price_gte=140&expiration_date=2026-12-18&limit=1000"
    @test url("http://h", MyOptionLatestQuoteEndpointModel(symbols = ["A1", "B2"])) ==
          "http://h/options/quotes/latest?symbols=A1%2CB2"
    @test url("http://h", MyStockLatestBarEndpointModel(symbol = "AAPL")) == "http://h/stocks/AAPL/bars/latest?feed=iex"
end

@testset "url: client picks the base URL" begin
    c = Alpaca.AlpacaClient("https://paper-api.alpaca.markets/v2", "https://data.alpaca.markets/v2", "K", "S")
    @test url(c, MyClockEndpointModel()) == "https://paper-api.alpaca.markets/v2/clock"
    @test startswith(url(c, MyStockSnapshotsEndpointModel(symbols = "AAPL")), "https://data.alpaca.markets/v2/stocks/snapshots")
    @test startswith(url(c, MyOptionSnapshotsEndpointModel(symbols = "X")), "https://data.alpaca.markets/v1beta1/options/snapshots")
    @test Alpaca._is_paginated(MyStockBarsEndpointModel(symbols = "A", timeframe = "1Day", start = "2025-01-01")) == true
    @test Alpaca._is_paginated(MyAccountEndpointModel()) == false
end
```

Add one `url` assertion for each remaining model, with the URL derived from the rules above.

- [ ] **Step 2: Run the tests to see them fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: FAIL with `UndefVarError: MyStockBarsEndpointModel`.

- [ ] **Step 3: Implement the models in `src/Types.jl` and the `url` methods in `src/Factory.jl`**

Follow L13b `src/Types.jl` and `src/Factory.jl`: one docstring per model naming its endpoint and fields, one `url` method per model that reads the fields into locals and builds the string. A private `_query_string(keys::Vector{String}, values::Vector{Any})::String` helper skips `nothing` values and escapes the rest, so each `url` method stays a list of fields.

- [ ] **Step 4: Run the tests to see them pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: all testsets pass.

- [ ] **Step 5: Commit**

```bash
git add src test/test_models_url.jl test/runtests.jl
git commit -m "Add the read endpoint models and url methods"
```

---

### Task 4: `api`, pagination, and one HTTP path

**Files:**
- Modify: `src/Network.jl`, `src/Alpaca.jl` (export `api`)
- Create: `test/test_api.jl`; modify `test/runtests.jl`

**Interfaces:**
- Consumes: `url`, `_base_url`, `_is_paginated` (Task 3).
- Produces:
  - `_http_call(client::AlpacaClient, method::String, request_url::String; body = nothing)::String` — sends the auth headers and `Accept: application/json` (plus `Content-Type: application/json` and the `JSON3.write` body when `body` is set), retries `429` with the current backoff (`_MAX_RETRIES = 5`, `_INITIAL_BACKOFF = 2.0`, same `@warn` text), calls `HTTP.request(...; status_exception = false, retry = false)`, returns the body as a `String` on 2xx, and throws `AlpacaError` exactly as `_handle_response` does today.
  - `api(client::AlpacaClient, model::AbstractAlpacaEndpointModel; handler::Function = _default_handler)` — calls `handler(typeof(model), body)` on each page and returns the merged result.
  - `_next_page_token(body::String)::Union{Nothing,String}` — `nothing` when the key is missing, `null`, or `""`.
  - `_merge(a, b)`: `DataFrame` → `vcat(a, b; cols = :union)`; `Dict{String,Vector{T}}` → append each key's vector in page order; `Dict{String,T}` → later page overwrites the key; `Vector` → `vcat`.
  - `_request` (legacy) now calls `_http_call` and then `JSON3.read` (or returns `nothing` for an empty body), so every request goes through one function.
  - `_default_handler` is declared here as a generic function with no methods; Tasks 5 and 6 add its methods.

Page loop: `request_url = url(client, model)`; after each page, if `_is_paginated(model)` and the token is not `nothing`, the next URL is `request_url * "&page_token=" * URIs.escapeuri(token)`.

- [ ] **Step 1: Write the failing tests in `test/test_api.jl`**

```julia
@testset "api: auth headers and custom handler" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict("id" => "x"))
    end
    seen = Any[]
    with_mock(handler) do client
        r = api(client, MyAccountEndpointModel(); handler = (T, body) -> (push!(seen, T); body))
        @test r isa String
    end
    @test seen == [MyAccountEndpointModel]
    @test log[1].headers["APCA-API-KEY-ID"] == "TEST_KEY_ID"
    @test log[1].headers["APCA-API-SECRET-KEY"] == "TEST_SECRET_KEY"
end

@testset "api: follows pages and stops on empty tokens" begin
    for last_token in (nothing, "")
        handler, log = recording_handler() do req
            if occursin("page_token=p2", req.target)
                return json_response(200, Dict("bars" => Dict(), "next_page_token" => last_token))
            end
            return json_response(200, Dict("bars" => Dict(), "next_page_token" => "p2"))
        end
        with_mock(handler) do client
            pages = api(client, MyStockBarsEndpointModel(symbols = "AAPL", timeframe = "1Day", start = "2025-01-01");
                        handler = (T, body) -> [body])
            @test length(pages) == 2
        end
        @test length(log) == 2
    end
end

@testset "api: no page loop for a single-record endpoint" begin
    handler, log = recording_handler() do _req
        return json_response(200, Dict("next_page_token" => "p2"))
    end
    with_mock(handler) do client
        api(client, MyClockEndpointModel(); handler = (T, body) -> body)
    end
    @test length(log) == 1
end

@testset "api: error status raises AlpacaError" begin
    handler = _req -> json_response(403, Dict("code" => 40310000, "message" => "forbidden"))
    err = try
        with_mock(handler) do client
            api(client, MyAccountEndpointModel(); handler = (T, body) -> body)
        end
        nothing
    catch e
        e
    end
    @test err isa AlpacaError
    @test err.status == 403
    @test err.code == 40310000
end
```

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `UndefVarError: api`.

- [ ] **Step 3: Implement the interfaces above in `src/Network.jl`**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass, including the golden test (the legacy `_request` now runs through `_http_call`).

- [ ] **Step 5: Commit**

```bash
git add src test/test_api.jl test/runtests.jl
git commit -m "Add api with pagination; route every request through _http_call"
```

---

### Task 5: DataFrame handlers for the trading reads, and Utility in lab style

**Files:**
- Create: `src/Handler.jl` (included after `Factory.jl`), `test/test_handlers_trading.jl`
- Modify: `src/Utility.jl` (rewrite in lab style, behavior unchanged; add `_parse_utc`)

**Interfaces:**
- Produces: `_parse_utc(x)::Union{Missing,DateTime}` — `nothing` or `""` → `missing`; a trailing `Z` means UTC; an offset `±HH:MM` is subtracted to reach UTC; fractional seconds are kept to the millisecond.
- Produces: `_default_handler(::Type{M}, body::String)::DataFrame` for each trading model `M`, with these columns, in this order:

| Model(s) | Columns |
|---|---|
| Account | `id`, `account_number`, `status`, `currency`, `cash`, `buying_power`, `portfolio_value`, `equity`, `last_equity`, `pattern_day_trader`, `trading_blocked`, `transfers_blocked`, `account_blocked` |
| Clock | `timestamp`, `is_open`, `next_open`, `next_close` |
| Calendar | `date`, `open`, `close`, `session_open`, `session_close` |
| Assets, Asset | `id`, `class`, `exchange`, `symbol`, `name`, `status`, `tradable`, `marginable`, `shortable`, `easy_to_borrow`, `fractionable` |
| Positions, Position | `asset_id`, `symbol`, `exchange`, `asset_class`, `qty`, `side`, `avg_entry_price`, `market_value`, `cost_basis`, `unrealized_pl`, `unrealized_plpc`, `current_price`, `lastday_price`, `change_today` |
| Orders, Order | `id`, `parent_id`, `client_order_id`, `symbol`, `asset_class`, `side`, `type`, `time_in_force`, `order_class`, `position_intent`, `qty`, `filled_qty`, `limit_price`, `stop_price`, `filled_avg_price`, `status`, `created_at`, `submitted_at`, `filled_at` |
| OptionContracts, OptionContract | the fields of `OptionContract` except `raw` |

Column types follow §5.1: optional values are `missing`, timestamps go through `_parse_utc`, prices and quantities are `Float64`. The calendar keeps Alpaca's `HHMM` / `HH:MM` handling (`_parse_cal_time`). An orders table lists each multi-leg parent and then one row per leg, with the leg's `parent_id` set to the parent's `id` (`missing` on top-level rows). A table with no records still has every column.

- [ ] **Step 1: Write the failing tests in `test/test_handlers_trading.jl`**

```julia
@testset "parse: _parse_utc" begin
    @test Alpaca._parse_utc("2026-11-18T09:30:00-05:00") == DateTime(2026, 11, 18, 14, 30)
    @test Alpaca._parse_utc("2026-04-11T20:00:00.123456789Z") == DateTime(2026, 4, 11, 20, 0, 0, 123)
    @test ismissing(Alpaca._parse_utc(nothing))
    @test ismissing(Alpaca._parse_utc(""))
end

@testset "handler: clock in UTC" begin
    body = JSON3.write(Dict("timestamp" => "2026-11-17T10:00:00-05:00", "is_open" => true,
                            "next_open" => "2026-11-18T09:30:00-05:00", "next_close" => "2026-11-17T16:00:00-05:00"))
    df = Alpaca._default_handler(MyClockEndpointModel, body)
    @test names(df) == ["timestamp", "is_open", "next_open", "next_close"]
    @test df[1, :next_open] == DateTime(2026, 11, 18, 14, 30)
end

@testset "handler: orders with legs, and an empty orders table" begin
    df = Alpaca._default_handler(MyOrdersEndpointModel, JSON3.write([_N_MLEG_ORDER]))
    @test size(df, 1) == 3
    @test ismissing(df[1, :parent_id])
    @test df[2, :parent_id] == df[1, :id]
    empty = Alpaca._default_handler(MyOrdersEndpointModel, "[]")
    @test size(empty, 1) == 0
    @test "parent_id" in names(empty)
end

@testset "handler: assets are not filtered" begin
    df = Alpaca._default_handler(MyAssetsEndpointModel, JSON3.write([_N_ASSET_TRADABLE, _N_ASSET_DEAD]))
    @test size(df, 1) == 2
end
```

Define `_N_MLEG_ORDER` (a parent with two legs), `_N_ASSET_TRADABLE`, and `_N_ASSET_DEAD` at the top of the file. Add one column-and-value test for each remaining trading model.

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `UndefVarError: _parse_utc`.

- [ ] **Step 3: Implement `_parse_utc` and the handlers; rewrite `src/Utility.jl` in lab style**

Build each table the way L13b `process_search_response_dataframe` does: one typed vector per column, filled in a loop, then `DataFrame(...)`.

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass, including the golden test.

- [ ] **Step 5: Commit**

```bash
git add src test/test_handlers_trading.jl test/runtests.jl
git commit -m "Add DataFrame handlers for the trading reads; restyle Utility"
```

---

### Task 6: DataFrame handlers for market data

**Files:**
- Modify: `src/Handler.jl`
- Create: `test/test_handlers_marketdata.jl`

**Interfaces:**
- Produces `_default_handler` methods for the 15 stock and option data models, with these columns:

| Model(s) | Columns |
|---|---|
| Stock and option bars, latest bars | `timestamp`, `symbol`, `open`, `high`, `low`, `close`, `volume`, `trade_count`, `vwap` |
| Stock and option quotes, latest quotes | `timestamp`, `symbol`, `bid_price`, `bid_size`, `ask_price`, `ask_size`, `bid_exchange`, `ask_exchange` |
| Stock and option trades, latest trades | `timestamp`, `symbol`, `price`, `size`, `exchange`, `id` |
| Stock snapshots | `symbol`, then the prefixed columns of `latest_trade_`, `latest_quote_`, `minute_bar_`, `daily_bar_`, `prev_daily_bar_` |
| Option snapshots, option chain | the stock snapshot columns, then `implied_volatility`, `delta`, `gamma`, `theta`, `vega`, `rho` |

A prefixed group holds the columns of its own table without `symbol` (for example `latest_quote_timestamp`, `latest_quote_bid_price`, ...). A missing nested object makes every column of its group `missing`. Rows follow the response order: symbols in the order of the JSON object, records in array order. A latest stock bar, quote, or trade reads `symbol` from the response's top-level `symbol` key and stores `missing` when the key is absent.

- [ ] **Step 1: Write the failing tests in `test/test_handlers_marketdata.jl`**

Define at the top of the file, as `Dict{String,Any}` payloads: `_N_BAR_A` (with `n` and `vw`), `_N_BAR_B` (without `n`), `_N_QUOTE`, `_N_SNAP_WITH_GREEKS` (with `latestQuote`, `latestTrade`, `impliedVolatility`, and `greeks`), and `_N_SNAP_NO_GREEKS` (with `latestQuote` only).

```julia
@testset "handler: stock bars" begin
    body = JSON3.write(Dict("bars" => Dict("AAPL" => [_N_BAR_A, _N_BAR_B]), "next_page_token" => nothing))
    df = Alpaca._default_handler(MyStockBarsEndpointModel, body)
    @test names(df) == ["timestamp", "symbol", "open", "high", "low", "close", "volume", "trade_count", "vwap"]
    @test df.symbol == ["AAPL", "AAPL"]
    @test ismissing(df[2, :trade_count])          # _N_BAR_B has no "n"
end

@testset "handler: empty bars response keeps every column" begin
    df = Alpaca._default_handler(MyStockBarsEndpointModel, JSON3.write(Dict("bars" => Dict(), "next_page_token" => nothing)))
    @test size(df) == (0, 9)
    df2 = Alpaca._default_handler(MyStockBarsEndpointModel, JSON3.write(Dict("bars" => nothing)))
    @test size(df2) == (0, 9)
end

@testset "handler: latest quote without symbol" begin
    df = Alpaca._default_handler(MyStockLatestQuoteEndpointModel, JSON3.write(Dict("quote" => _N_QUOTE)))
    @test size(df, 1) == 1
    @test ismissing(df[1, :symbol])
end

@testset "handler: option chain flattens greeks" begin
    body = JSON3.write(Dict("snapshots" => Dict("SPY261218P00500000" => _N_SNAP_WITH_GREEKS,
                                                 "SPY261218C00600000" => _N_SNAP_NO_GREEKS)))
    df = Alpaca._default_handler(MyOptionChainEndpointModel, body)
    @test size(df, 1) == 2
    @test df[1, :delta] == _N_SNAP_WITH_GREEKS["greeks"]["delta"]
    @test ismissing(df[2, :delta])
    @test "latest_quote_bid_price" in names(df)
end
```

Add one test for each remaining market data model.

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `MethodError: no method matching _default_handler(::Type{MyStockBarsEndpointModel}, ::String)`.

- [ ] **Step 3: Implement the handlers**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass.

- [ ] **Step 5: Commit**

```bash
git add src test/test_handlers_marketdata.jl test/runtests.jl
git commit -m "Add DataFrame handlers for stock and option market data"
```

---

### Task 7: Legacy trading reads as deprecated wrappers

**Files:**
- Create: `src/Legacy.jl` (included last, after `streaming.jl`), `test/test_deprecations.jl`
- Modify: `src/Handler.jl`; `src/orders.jl` and `src/positions.jl` (remove the read functions only)
- Delete: `src/account.jl`, `src/clock.jl`, `src/assets.jl`

**Interfaces:**
- Produces: `_legacy_handler(::Type{M}, body::String)` methods that return the legacy values: Account → `Account`; Clock → `MarketClock` (via `_parse_rfc3339`, unchanged); Calendar → `Vector{CalendarDay}`; Assets → `Vector{Asset}` (unfiltered); Asset → `Asset`; Positions → `Vector{Position}`; Position → `Position`; Orders → `Vector{Order}`; Order → `Order`; OptionContracts → `Vector{OptionContract}`; OptionContract → `OptionContract`. The struct parsers (`_parse_account`, `_parse_asset`, `_parse_position`, `_parse_order`, `_parse_legs`, `_parse_option_contract`, `_parse_cal_time`, `_maybe_string`) move to `src/Handler.jl` and are restyled.
- Produces in `src/Legacy.jl`: `get_account`, `get_clock`, `get_calendar`, `list_assets`, `get_asset`, `list_positions`, `get_position`, `list_orders`, `get_order`, `list_option_contracts`, `get_option_contract`, each with its current signature. `list_assets` applies `tradable_only` after `api` returns. Each docstring opens with `!!! warning "Deprecated"` naming the replacement from §6.

- [ ] **Step 1: Write the failing deprecation tests in `test/test_deprecations.jl`**

```julia
@testset "deprecations: trading reads" begin
    with_mock(golden_handler) do c
        @test_deprecated get_account(c)
        @test_deprecated get_clock(c)
        @test_deprecated get_calendar(c)
        @test_deprecated list_assets(c)
        @test_deprecated get_asset(c, "AAPL")
        @test_deprecated list_positions(c)
        @test_deprecated get_position(c, "AAPL")
        @test_deprecated list_orders(c)
        @test_deprecated get_order(c, "ord-1")
        @test_deprecated list_option_contracts(c; underlying_symbols = "SPY")
        @test_deprecated get_option_contract(c, "SPY261218P00500000")
    end
end
```

Include `test_deprecations.jl` in `runtests.jl` after `test_golden.jl`, which loads `golden_handler`.

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL; the calls emit no deprecation warning.

- [ ] **Step 3: Implement the wrappers and legacy handlers; delete the old implementations**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass, including the golden test and the unchanged `test_account.jl`, `test_clock.jl`, `test_assets.jl`, `test_orders.jl`, `test_positions.jl`, `test_options.jl`.

- [ ] **Step 5: Commit**

```bash
git add -A src test/test_deprecations.jl test/runtests.jl
git commit -m "Move legacy trading reads onto api and deprecate them"
```

---

### Task 8: Legacy market data and historical helpers as deprecated wrappers

**Files:**
- Modify: `src/Legacy.jl`, `src/Handler.jl`, `test/test_deprecations.jl`
- Delete: `src/marketdata.jl`, `src/options.jl`, `src/historical.jl`

**Interfaces:**
- Produces `_legacy_handler` methods: stock and option bars, quotes, trades → `Dict{String,Vector{Bar}}` / `Dict{String,Vector{Quote}}` / `Dict{String,Vector{Trade}}`; option latest bar, quote, trade → `Dict{String,Bar}` / `Dict{String,Quote}` / `Dict{String,Trade}`; option snapshots and option chain → `Dict{String,OptionSnapshot}`; stock latest bar, quote, trade and stock snapshots → the parsed `JSON3` value. The parsers `_parse_bar`, `_parse_quote`, `_parse_trade`, `_parse_greeks`, `_parse_option_snapshot`, `_maybe_float` move to `src/Handler.jl`, restyled. `src/streaming.jl` keeps using its own parsers.
- Produces in `src/Legacy.jl`: `get_bars`, `get_quotes`, `get_trades`, `get_latest_bar`, `get_latest_quote`, `get_latest_trade`, `get_snapshot`, `download_bars`, `write_bars_csv`, `read_bars_csv`, `list_option_contracts` (already done), `get_option_bars`, `get_option_trades`, `get_option_quotes`, `get_latest_option_bar`, `get_latest_option_quote`, `get_latest_option_trade`, `get_option_snapshots`, `get_option_chain_snapshot`.
  - `get_latest_bar(client, symbol; feed)` builds the `Bar` from the JSON value with `_parse_bar(symbol, value.bar)`, so the symbol the caller passed fills the field, as today. Same for quote and trade.
  - `download_bars` calls `api` with the legacy bars handler for each chunk (never `get_bars`), keeps `_month_chunks`, `verbose` output, and `save_dir` behavior, and writes CSVs through a private `_write_bars_csv` that `write_bars_csv` also uses.
  - `write_bars_csv` opens the file with `open(path, "w")`, writes in a `try`, and closes in `finally`, with no `do` block. The deprecation message says to write the bars `DataFrame` with a CSV package.

- [ ] **Step 1: Add the failing deprecation tests**

Add a testset `deprecations: market data` to `test/test_deprecations.jl` with one `@test_deprecated` call for each name above, using the arguments from the `GOLDEN_CALLS` table. For `read_bars_csv`, first write a file with `Alpaca._write_bars_csv`.

- [ ] **Step 2: Run the tests to see them fail**

- [ ] **Step 3: Implement the wrappers and legacy handlers; delete the three old files**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass, including the golden test and the unchanged `test_marketdata.jl`, `test_historical.jl`, `test_options.jl`, `test_streaming.jl`.

- [ ] **Step 5: Commit**

```bash
git add -A src test/test_deprecations.jl
git commit -m "Move legacy market data and download helpers onto api and deprecate them"
```

---

### Task 9: Order models, `submit`, and `cancel`

**Files:**
- Create: `src/Trading.jl` (included after `Handler.jl`), `test/test_trading_submit.jl`
- Modify: `src/Types.jl`, `src/Alpaca.jl` (export `submit`, `cancel`, `MyEquityOrderModel`, `MyOptionLegModel`)

**Interfaces:**
- Produces in `src/Types.jl`:
  - `MyEquityOrderModel(; symbol::String, side::String, qty::Union{Nothing,Real} = nothing, notional::Union{Nothing,Real} = nothing) <: AbstractAlpacaOrderModel`. The constructor raises `ArgumentError` unless `side` is `"buy"` or `"sell"` and exactly one of `qty` or `notional` is set.
  - `MyOptionLegModel(; symbol::String, side::String, ratio::Int = 1) <: AbstractAlpacaOrderModel`. The constructor raises `ArgumentError` unless `side` is `"buy"` or `"sell"` and `ratio >= 1`.
- Produces in `src/Trading.jl` (private):
  - `_single_order_body(symbol, qty, side; type, time_in_force, limit_price, stop_price, trail_price, trail_percent, client_order_id, extended_hours, notional, position_intent = nothing)::Dict{String,Any}` — the same keys and string formatting as the legacy `submit_order` body, plus `position_intent` when set.
  - `_validate_mleg(symbols, sides, intents, ratios, type, limit_price)` — the legacy checks and messages from `src/orders.jl`.
  - `_mleg_body(symbols::Vector{String}, sides::Vector{String}, intents::Vector{String}, ratios::Vector{Int}; qty, type, time_in_force, limit_price, client_order_id, extended_hours)::Dict{String,Any}` — the legacy `mleg` body.
  - `_post_order(client, body)::Order`, `_get_order(client, id::String)::Order`, `_cancel_order(client, id::String)::String`.
- Produces (public):
  - `submit(client, m::MyEquityOrderModel; type = "market", time_in_force = "day", limit_price = nothing, stop_price = nothing, trail_price = nothing, trail_percent = nothing, client_order_id = nothing, extended_hours = false)::Order`
  - `submit(client, leg::MyOptionLegModel; qty::Int = 1, type = "market", time_in_force = "day", limit_price = nothing, stop_price = nothing, client_order_id = nothing, extended_hours = false)::Order` — sends `qty * leg.ratio` contracts with `position_intent = leg.side * "_to_open"`.
  - `submit(client, legs::Vector{MyOptionLegModel}; qty::Int = 1, type = "limit", time_in_force = "day", limit_price = nothing, client_order_id = nothing, extended_hours = false)::Order` — 1 leg: calls the single-leg method with the same keywords; 2–4 legs: one `mleg` order with every intent `*_to_open`; more than 4: `ArgumentError`, no request.
  - `cancel(client, order::Order)::Nothing`, `cancel(client, id::String)::Nothing` — `DELETE /orders/{id}`.
  - `cancel(client; all::Bool = false)::DataFrame` — `ArgumentError` unless `all == true`; `DELETE /orders`; columns `id`, `status` from Alpaca's response array.

- [ ] **Step 1: Write the failing tests in `test/test_trading_submit.jl`**

Define `_N_EQUITY_ORDER` at the top of the file: a `Dict{String,Any}` order payload with `"id" => "eq-0"`, `"symbol" => "AAPL"`, `"asset_class" => "us_equity"`, `"side" => "buy"`, `"type" => "market"`, `"time_in_force" => "day"`, `"qty" => "10"`, `"filled_qty" => "0"`, `"status" => "accepted"`, and the timestamps. `_N_MLEG_ORDER` comes from `test/test_handlers_trading.jl` (Task 5).

```julia
@testset "models: invalid order models" begin
    @test_throws ArgumentError MyOptionLegModel(symbol = "X", side = "long")
    @test_throws ArgumentError MyOptionLegModel(symbol = "X", side = "buy", ratio = 0)
    @test_throws ArgumentError MyEquityOrderModel(symbol = "AAPL", side = "buy")
    @test_throws ArgumentError MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 1, notional = 100)
end

@testset "submit: vertical spread is one mleg order with open intents" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    legs = [MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell"),
            MyOptionLegModel(symbol = "SPY261218P00530000", side = "buy")]
    with_mock(handler) do client
        o = submit(client, legs; qty = 2, limit_price = -1.25)
        @test o isa Order
    end
    @test length(log) == 1
    body = JSON3.read(log[1].body)
    @test body.order_class == "mleg"
    @test body.qty == "2"
    @test body.limit_price == "-1.25"
    @test [l.position_intent for l in body.legs] == ["sell_to_open", "buy_to_open"]
    @test [l.side for l in body.legs] == ["sell", "buy"]
end

@testset "submit: more than 4 legs sends nothing" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    legs = [MyOptionLegModel(symbol = "S$(i)", side = "buy") for i in 1:5]
    with_mock(handler) do client
        @test_throws ArgumentError submit(client, legs; limit_price = 1.0)
    end
    @test length(log) == 0
end

@testset "submit: single option leg and equity" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        submit(client, MyOptionLegModel(symbol = "SPY261218C00600000", side = "buy", ratio = 2); qty = 3)
        submit(client, MyEquityOrderModel(symbol = "AAPL", side = "buy", qty = 10); type = "limit", limit_price = 150.25)
    end
    b1 = JSON3.read(log[1].body)
    @test b1.qty == "6"
    @test b1.position_intent == "buy_to_open"
    b2 = JSON3.read(log[2].body)
    @test b2.qty == "10"
    @test b2.limit_price == "150.25"
    @test !haskey(b2, :position_intent)
end

@testset "cancel" begin
    handler, log = recording_handler() do req
        if req.target == "/orders"
            return json_response(207, [Dict("id" => "o1", "status" => 200)])
        end
        return HTTP.Response(204)
    end
    with_mock(handler) do client
        @test cancel(client, "ord-1") === nothing
        df = cancel(client; all = true)
        @test df.id == ["o1"]
        @test_throws ArgumentError cancel(client)
    end
    @test log[1].method == "DELETE"
    @test log[1].path == "/orders/ord-1"
end
```

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `UndefVarError: MyOptionLegModel`.

- [ ] **Step 3: Implement the models and verbs**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass.

- [ ] **Step 5: Commit**

```bash
git add src test/test_trading_submit.jl test/runtests.jl
git commit -m "Add order models, submit, and cancel"
```

---

### Task 10: `close` and `roll`

**Files:**
- Modify: `src/Trading.jl`, `src/Alpaca.jl` (export `roll`)
- Create: `test/test_trading_close_roll.jl`

**Interfaces:**
- Consumes: Task 9's private functions and models.
- Produces (all `Base.close` methods return `Order` unless noted):
  - `Base.close(client, symbol::String; qty = nothing, percentage = nothing)` — `DELETE /positions/{symbol}` with `qty` / `percentage` query parameters when set; parses the response as an `Order`.
  - `Base.close(client; all::Bool = false, cancel_orders::Bool = false)::DataFrame` — `ArgumentError` unless `all == true`; `DELETE /positions?cancel_orders=<bool>`; columns `symbol`, `status`.
  - `Base.close(client, m::MyEquityOrderModel; <submit keywords>)` — opposite side, same `qty` or `notional`.
  - `Base.close(client, leg::MyOptionLegModel; <single-leg submit keywords>)` — opposite side, `position_intent = <opposite side> * "_to_close"`.
  - `Base.close(client, legs::Vector{MyOptionLegModel}; <vector submit keywords>)` — the reverse of every leg in one `mleg` order; same leg-count rules as `submit`.
  - `Base.close(client, order::Order; type = "market", limit_price = nothing, time_in_force = "day")` — `ArgumentError` with the text ``"order <id> has status <status>; use `cancel` for an order that has not filled"`` unless `order.status == "filled"`. Reverses the filled quantities. The order kind comes from the `Order` value: `order.legs !== nothing` is multi-leg, `order.asset_class == "us_option"` is a single option, anything else is equity. Equity → opposite side with `qty = order.filled_qty`; single option → opposite side and `*_to_close`; multi-leg → `qty = Int(order.filled_qty)` units, each leg's ratio from `leg.raw.ratio_qty` when present, else `Int(leg.qty / order.qty)`. A whole-number quantity is sent as an integer string (`"7"`, not `"7.0"`).
  - `roll(client, from, to; qty::Int = 1, type = "limit", time_in_force = "day", limit_price = nothing, client_order_id = nothing)::Order` for `from::Union{MyOptionLegModel,Vector{MyOptionLegModel}}` and `to::Union{MyOptionLegModel,Vector{MyOptionLegModel}}`; plus `roll(client, from::Order, to; qty::Int = Int(from.filled_qty), ...)`, which converts the filled order to legs with a private `_legs_from_order(order)::Vector{MyOptionLegModel}`. One `mleg` order: `from` legs reversed with `*_to_close`, then `to` legs with `*_to_open`. More than 4 legs in total: `ArgumentError`, no request. The docstring says that an iron condor rolls as two `roll` calls, one per wing, and that the two calls are not atomic.

- [ ] **Step 1: Write the failing tests in `test/test_trading_close_roll.jl`**

```julia
const _N_SPREAD = [MyOptionLegModel(symbol = "SPY261218P00540000", side = "sell"),
                   MyOptionLegModel(symbol = "SPY261218P00530000", side = "buy")]

@testset "close: spread reverses every leg in one order" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    with_mock(handler) do client
        close(client, _N_SPREAD; limit_price = 0.40)
    end
    body = JSON3.read(log[1].body)
    @test [l.side for l in body.legs] == ["buy", "sell"]
    @test [l.position_intent for l in body.legs] == ["buy_to_close", "sell_to_close"]
end

@testset "close: an unfilled or partly filled order must be canceled" begin
    for status in ("accepted", "partially_filled")
        payload = merge(_N_EQUITY_ORDER, Dict("status" => status))
        order = Alpaca._parse_order(JSON3.read(JSON3.write(payload)))
        handler, log = recording_handler() do _req
            return json_response(200, _N_EQUITY_ORDER)
        end
        with_mock(handler) do client
            err = try close(client, order); nothing catch e; e end
            @test err isa ArgumentError
            @test occursin("cancel", err.msg)
        end
        @test length(log) == 0
    end
end

@testset "close: a filled equity order is reversed with the filled quantity" begin
    payload = merge(_N_EQUITY_ORDER, Dict("status" => "filled", "filled_qty" => "7"))
    order = Alpaca._parse_order(JSON3.read(JSON3.write(payload)))
    handler, log = recording_handler() do _req
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        close(client, order)
    end
    body = JSON3.read(log[1].body)
    @test body.side == "sell"
    @test body.qty == "7"
end

@testset "close: one holding and all holdings" begin
    handler, log = recording_handler() do req
        if req.target == "/positions?cancel_orders=true"
            return json_response(207, [Dict("symbol" => "AAPL", "status" => 200)])
        end
        return json_response(200, _N_EQUITY_ORDER)
    end
    with_mock(handler) do client
        @test close(client, "AAPL"; qty = 5) isa Order
        @test close(client; all = true, cancel_orders = true).symbol == ["AAPL"]
    end
    @test log[1].method == "DELETE"
    @test log[1].target == "/positions/AAPL?qty=5"
end

@testset "roll: vertical spread is one 4-leg order" begin
    handler, log = recording_handler() do _req
        return json_response(200, _N_MLEG_ORDER)
    end
    far = [MyOptionLegModel(symbol = "SPY270115P00540000", side = "sell"),
           MyOptionLegModel(symbol = "SPY270115P00530000", side = "buy")]
    with_mock(handler) do client
        roll(client, _N_SPREAD, far; limit_price = -0.10)
        condor = vcat(_N_SPREAD, [MyOptionLegModel(symbol = "C1", side = "sell"), MyOptionLegModel(symbol = "C2", side = "buy")])
        @test_throws ArgumentError roll(client, condor, condor; limit_price = 0.0)
    end
    @test length(log) == 1
    body = JSON3.read(log[1].body)
    @test [l.position_intent for l in body.legs] == ["buy_to_close", "sell_to_close", "sell_to_open", "buy_to_open"]
end
```

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `MethodError: no method matching close(::AlpacaClient, ::Vector{MyOptionLegModel})`.

- [ ] **Step 3: Implement `close` and `roll`**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass.

- [ ] **Step 5: Commit**

```bash
git add src test/test_trading_close_roll.jl test/runtests.jl
git commit -m "Add close and roll"
```

---

### Task 11: Equity and options together

**Files:**
- Modify: `src/Types.jl`, `src/Trading.jl`, `src/Alpaca.jl` (export `MyMixedOrderModel`, `AlpacaSequenceError`)
- Create: `test/test_trading_mixed.jl`

**Interfaces:**
- Produces in `src/Types.jl`:
  - `MyMixedOrderModel(; equity::MyEquityOrderModel, options::Vector{MyOptionLegModel}) <: AbstractAlpacaOrderModel`.
  - `AlpacaSequenceError <: Exception` with fields `message::String`, `orders::Vector{Order}` (the orders sent so far, in sequence order), and `cause::Union{Nothing,Exception}`; `Base.showerror` prints the message and each order's `id` and `status`.
- Produces in `src/Trading.jl`:
  - `_check_coverage(m::MyMixedOrderModel, qty::Int)` — when any leg has `side == "sell"` and its symbol is a call (OCC type character `C` at position `length(symbol) - 8`), requires `m.equity.side == "buy"`, `m.equity.qty !== nothing`, and `m.equity.qty >= 100 * qty * <sum of ratio over short call legs>`; otherwise `ArgumentError`. Returns `nothing` when the check passes or the model has no short call.
  - `_wait_for_fill(client, order::Order, fill_timeout::Float64, poll_interval::Float64)::Order` — polls `_get_order` until `status == "filled"` and returns the filled `Order`; stops early on `"canceled"`, `"expired"`, or `"rejected"`; on timeout or early stop, calls `_cancel_order` (ignoring an `AlpacaError` from that cancel) and throws `AlpacaSequenceError` holding the last `Order`.
  - `submit(client, m::MyMixedOrderModel; qty::Int = 1, type = "limit", limit_price = nothing, time_in_force = "day", fill_timeout::Float64 = 30.0, poll_interval::Float64 = 0.5)::Vector{Order}` — `_check_coverage`; equity order at market; `_wait_for_fill`; then the option order (`submit(client, m.options; qty, type, limit_price, time_in_force)`); an `AlpacaError` from the option order becomes `AlpacaSequenceError` holding the filled equity order and the cause. Returns `[filled_equity_order, option_order]`.
  - `Base.close(client, m::MyMixedOrderModel; qty::Int = 1, type = "limit", limit_price = nothing, time_in_force = "day", fill_timeout::Float64 = 30.0, poll_interval::Float64 = 0.5)::Vector{Order}` — reverse option order first (`close(client, m.options; ...)`), `_wait_for_fill`, then the reverse equity order at market; same error handling. Returns `[filled_option_order, equity_order]`.

- [ ] **Step 1: Write the failing tests in `test/test_trading_mixed.jl`**

The mock routes `POST /orders` by the body (`symbol == "F"` → equity payload with id `eq-1`; otherwise an option payload with id `op-1`), `GET /orders/<id>` to a status taken from a test-controlled `Ref`, and `DELETE /orders/<id>` to `204`.

```julia
const _N_COVERED_CALL = MyMixedOrderModel(
    equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
    options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])

@testset "mixed: coverage check" begin
    short_shares = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 50),
                                     options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(short_shares, 1)
    @test_throws ArgumentError Alpaca._check_coverage(_N_COVERED_CALL, 2)
    by_notional = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", notional = 1200),
                                    options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(by_notional, 1)
    selling = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "sell", qty = 100),
                                options = [MyOptionLegModel(symbol = "F261218C00012000", side = "sell")])
    @test_throws ArgumentError Alpaca._check_coverage(selling, 1)
    married_put = MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100),
                                    options = [MyOptionLegModel(symbol = "F261218P00010000", side = "buy")])
    @test Alpaca._check_coverage(married_put, 1) === nothing
end

@testset "mixed: submit sends shares, waits, then the call" begin
    # status Ref returns "filled" for eq-1
    log = run_mixed(status = "filled") do client
        orders = submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 1.0, poll_interval = 0.01)
        @test [o.id for o in orders] == ["eq-1", "op-1"]
    end
    posts = [r for r in log.entries if r.method == "POST"]
    @test JSON3.read(posts[1].body).symbol == "F"
    @test JSON3.read(posts[2].body).position_intent == "sell_to_open"
end

@testset "mixed: unfilled shares are canceled and no call is sold" begin
    log = run_mixed(status = "new") do client
        err = try submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 0.05, poll_interval = 0.01); nothing catch e; e end
        @test err isa AlpacaSequenceError
        @test err.orders[1].id == "eq-1"
    end
    @test count(r -> r.method == "POST", log.entries) == 1
    @test any(r -> r.method == "DELETE" && r.path == "/orders/eq-1", log.entries)
end

@testset "mixed: a rejected call keeps the filled shares in the error" begin
    log = run_mixed(status = "filled", reject_options = true) do client
        err = try submit(client, _N_COVERED_CALL; limit_price = 0.35, fill_timeout = 1.0, poll_interval = 0.01); nothing catch e; e end
        @test err isa AlpacaSequenceError
        @test err.orders[1].id == "eq-1"
        @test err.cause isa AlpacaError
    end
end

@testset "mixed: close buys back the call before selling the shares" begin
    log = run_mixed(status = "filled") do client
        orders = close(client, _N_COVERED_CALL; limit_price = 0.10, fill_timeout = 1.0, poll_interval = 0.01)
        @test [o.id for o in orders] == ["op-1", "eq-1"]
    end
    posts = [r for r in log.entries if r.method == "POST"]
    @test JSON3.read(posts[1].body).position_intent == "buy_to_close"
    @test JSON3.read(posts[2].body).side == "sell"
end
```

`run_mixed(f; status, reject_options = false)` is a helper at the top of the file that builds the mock described above, runs `f(client)` in `with_mock`, and returns the `RequestLog`.

- [ ] **Step 2: Run the tests to see them fail**

Expected: FAIL with `UndefVarError: MyMixedOrderModel`.

- [ ] **Step 3: Implement the model, the error type, and the sequence**

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass.

- [ ] **Step 5: Commit**

```bash
git add src test/test_trading_mixed.jl test/runtests.jl
git commit -m "Add mixed equity and option structures with a covered sequence"
```

---

### Task 12: Legacy trading writes as deprecated wrappers

**Files:**
- Modify: `src/Legacy.jl`, `src/Types.jl` (`OrderLeg` inner constructor), `src/Network.jl` (delete `_request`, `_build_url`, `_join_url`, `_handle_response`, and the `_trading_*` / `_data_get` / `_options_data_get` helpers once nothing uses them), `test/test_deprecations.jl`
- Delete: `src/orders.jl`, `src/positions.jl`

**Interfaces:**
- Produces in `src/Legacy.jl`, each with its current signature and return value:
  - `submit_order` — the legacy `qty`/`notional` checks, then `_post_order(client, _single_order_body(...))` with no `position_intent`, so an option symbol still sends none.
  - `submit_multileg_order` — `_validate_mleg` and `_mleg_body` with the explicit intents and ratios from the `OrderLeg` values.
  - `cancel_order` → `nothing`; `cancel_all_orders` → the parsed `JSON3` value; `close_position` → the parsed `JSON3` value; `close_all_positions` → the parsed `JSON3` value. These call private functions in `src/Trading.jl` that return the response body, never the public verbs, so the legacy return values stay raw.
- `OrderLeg` gets an inner constructor `OrderLeg(symbol::AbstractString, ratio_qty::Integer, side::AbstractString, position_intent::AbstractString)` that calls `Base.depwarn` and then `new(String(symbol), Int(ratio_qty), String(side), String(position_intent))`.

- [ ] **Step 1: Add the failing deprecation tests**

Add a testset `deprecations: trading writes` with `@test_deprecated` for `submit_order`, `submit_multileg_order`, `cancel_order`, `cancel_all_orders`, `close_position`, `close_all_positions`, and `OrderLeg("X", 1, "buy", "buy_to_open")`, using the `GOLDEN_CALLS` arguments.

- [ ] **Step 2: Run the tests to see them fail**

- [ ] **Step 3: Implement the wrappers; delete `src/orders.jl`, `src/positions.jl`, and the unused legacy network helpers**

Run `grep -n "_request\|_trading_get\|_data_get\|_options_data_get\|_build_url" src/*.jl` before deleting; the only remaining hits must be in `src/streaming.jl`, if any, and those helpers stay.

- [ ] **Step 4: Run the full suite**

Expected: all testsets pass, including the golden test and the unchanged `test_orders.jl`, `test_positions.jl`, `test_client.jl`, and `test_integration.jl` (skipped offline).

- [ ] **Step 5: Commit**

```bash
git add -A src test/test_deprecations.jl
git commit -m "Move legacy trading writes onto the new core and deprecate them"
```

---

### Task 13: Exports, docs, README, version

**Files:**
- Modify: `src/Alpaca.jl`, `Project.toml` (`version = "0.4.0"`), `README.md`, `docs/make.jl`, `docs/src/index.md`, `docs/src/getting_started.md`, the legacy struct docstrings in `src/Types.jl`
- Create: `docs/src/api/models.md`, `docs/src/api/reading.md`, `docs/src/api/trading.md`, `docs/src/api/legacy.md`
- Delete: `docs/src/api/account.md`, `assets.md`, `clock.md`, `historical.md`, `marketdata.md`, `options.md`, `orders.md`, `positions.md`

**Interfaces:**
- `src/Alpaca.jl` export blocks, in this order, each with a comment: client (`AlpacaClient`, `load_client`); verbs (`url`, `api`, `submit`, `cancel`, `roll`; `close` is a `Base` method); abstract types; read models; order models; errors (`AlpacaError`, `AlpacaSequenceError`, `Order`); streaming (unchanged); legacy functions; legacy types.

- [ ] **Step 1: Write the docs**

- `README.md`: installation (unchanged), credentials (unchanged), then three short examples: a read with `url` and `api`, a vertical spread with `submit`, `close`, and `roll`, and a covered call with `MyMixedOrderModel`. A one-line pointer to the Legacy API page. The features table lists the verbs and models instead of the legacy names.
- `docs/make.jl` pages: Home, Getting Started, then "API Reference" with Client, Models, Reading data, Trading, Streaming, Types, Legacy API. `checkdocs = :exports` stays.
- `docs/src/api/legacy.md`: the table from §6, then `@docs` blocks for every legacy function and legacy type.
- Each legacy struct docstring in `src/Types.jl` starts with ``Legacy type, returned by the deprecated functions. New code uses the `DataFrame` that `api` returns.``

- [ ] **Step 2: Build the docs**

Run: `julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate(); include("docs/make.jl")'`
Expected: the build finishes with no `missing_docs` warning for an exported name, and `deploydocs` skips because `CI` is not set. Do not commit any change that `Pkg.develop` makes to `docs/Project.toml` (for example a `[sources]` section); restore that file with `git checkout docs/Project.toml`.

- [ ] **Step 3: Run the full suite**

Expected: all testsets pass.

- [ ] **Step 4: Commit**

```bash
git add -A src docs README.md Project.toml
git commit -m "Document the new API, mark the legacy API, bump to 0.4.0"
```

---

### Task 14: Live paper tests and final verification

**Files:**
- Create: `test/test_integration_verbs.jl`; modify `test/runtests.jl` (include it after `test_integration.jl`)

**Interfaces:**
- Consumes: everything above; `_LIVE` from `test/test_integration.jl`.

- [ ] **Step 1: Write the live tests**

All three testsets run only when `_LIVE` is true and `api(client, MyClockEndpointModel())[1, :is_open] == true`; otherwise they log `@info "skipping live verb tests (market closed)"`. Each testset cleans up in `finally` with `close(client, <symbol>)` for every symbol it opened, and swallows an `AlpacaError` from that cleanup.

1. **Vertical spread.** Pick SPY puts 30–45 DTE from `api(client, MyOptionChainEndpointModel(underlying = "SPY", type = "put", expiration_date_gte = ..., expiration_date_lte = ...))`, using the same short-and-long selection as `test_integration.jl`. `submit(client, legs; type = "market")`, wait for `"filled"` with `api(client, MyOrderEndpointModel(id = ...))`, then `close(client, legs; type = "market")` and wait for `"filled"`.
2. **Roll.** Open the near spread at market as in step 1. `roll(client, near, far; limit_price = -0.01)` with a far spread 25–35 days later. Assert the roll order is not `"rejected"`, then `cancel(client, roll_order)` after 5 seconds. Close the near spread in `finally`.
3. **Covered call.** Underlying `F`. Pick the first out-of-the-money F call 20–45 DTE. `submit(client, MyMixedOrderModel(equity = MyEquityOrderModel(symbol = "F", side = "buy", qty = 100), options = [MyOptionLegModel(symbol = call, side = "sell")]); type = "market")`, assert two orders with the first `"filled"`, wait for the call to fill, then `close(client, model; type = "market")` and assert the first returned order is `"filled"`.

- [ ] **Step 2: Run the offline suite**

Run: `julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: all testsets pass, and the live tests are skipped.

- [ ] **Step 3: Run the live suite while the market is open**

Run: `ALPACA_LIVE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()'`
Expected: all testsets pass, including the three new live testsets and the existing live tests. If the market is closed, report that and stop here. Do not tag.

- [ ] **Step 4: Check the cron path**

Run: `julia --project=. scripts/check_trading_day.jl`
Expected: the same `[ok]` or `[skip]` line as on `main`, with no deprecation warning printed.

- [ ] **Step 5: Commit**

```bash
git add test/test_integration_verbs.jl test/runtests.jl
git commit -m "Add live paper tests for submit, close, and roll"
```

Report the results to Jeff. Pushing, merging, and tagging `v0.4.0` wait for his go-ahead.
