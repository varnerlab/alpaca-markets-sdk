# Full Endpoint Coverage (0.5.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cover every Alpaca Trading API and Market Data API endpoint that a paper account can call, crypto included, and remove the two read models that call addresses Alpaca does not have.

**Architecture:** Each new endpoint is one `My...EndpointModel` with a `url(base, model)` method and a `_default_handler`, as in 0.4.0. Write endpoints (watchlists, account settings, replace, exercise) are endpoint models too: `api` sends the HTTP method and JSON body that the model declares. New abstract types pick the base URL of each API version.

**Tech Stack:** Julia 1.10+, HTTP.jl, JSON3, URIs, DataFrames, Test, the in-process mock server in `test/mock_server.jl`.

**Spec:** `docs/superpowers/specs/2026-11-17-lab-standard-redesign-design.md` (the 0.4.0 design, still binding for style, layout and verification) plus the Design section below. The endpoint list, parameters and response shapes are in `docs/superpowers/specs/2026-11-21-alpaca-endpoint-inventory.md`, taken from Alpaca's OpenAPI specs on 2026-11-21. Scope approved by Jeff on 2026-11-21: "do 1 -> 3 and add crypto".

## Global Constraints

- Code style is §8 of the 0.4.0 spec: docstrings with `### Arguments`, `### Returns`, `### Throws` (functions) and `### Fields`, `### Constructors` (types); `mutable struct` models with keyword constructors; PUBLIC/PRIVATE banners; explicit loops and `if` blocks with a comment per step; no inner functions, closures, `do` blocks, ternary chains, or `x || throw(...)` / `x && return` one-liners; private names start with `_`.
- Every legacy name except the two removed in Task 2 keeps its request and return value. `test/test_golden.jl` must pass unchanged.
- Existing test files change only where Task 2 removes the dead endpoints. New tests go in new files, included from `test/runtests.jl`.
- Version becomes `0.5.0` in `Project.toml`. Work on branch `endpoints-0.5`. Nothing is pushed or tagged until Jeff says so.
- Live tests run only with `ALPACA_LIVE_TESTS=1`. Live tests that write (orders, watchlists, settings) also need `ALPACA_LIVE_WRITE_TESTS=1`, and they restore what they change.
- Out of scope, from the inventory: short-sale locates (live accounts only), tokenization (minting firms only), crypto wallets and transfers, the two server-sent-event streams, the deprecated `/v2/corporate_actions/announcements` pair, and the single-symbol copies of the multi-symbol stock endpoints (`/v2/stocks/{symbol}/bars`, `/quotes`, `/trades`, `/auctions`, `/snapshot`).

## Design

**D1. Base URLs.** A private `_versioned_url(base::AbstractString, version::AbstractString)::String` generalizes `_derive_options_url`: a trailing `/v2` becomes `/<version>`, an inner `/v2/` becomes `/<version>/`, and a base with no `/v2` segment (the mock server) is returned unchanged. `_derive_options_url(x)` becomes `_versioned_url(x, "v1beta1")`. New abstract types, each with a `_base_url` method in `src/Factory.jl`:

| Abstract type | Base URL | Endpoints |
|---|---|---|
| `AbstractAlpacaCryptoDataEndpointModel` | `_versioned_url(client.data_url, "v1beta3")` | crypto data |
| `AbstractAlpacaGlobalStockDataEndpointModel` | `_versioned_url(client.data_url, "v3")` | stocks on non-US exchanges (Alpaca's "Stock v3") |
| `AbstractAlpacaMarketDataEndpointModel` | `client.options_data_url` (the `v1beta1` base) | news, screener, logos, fixed income |

Two models override `_base_url` for their own type: `MyCorporateActionsEndpointModel` (`_versioned_url(client.data_url, "v1")`), and `MyMarketCalendarEndpointModel` and `MyMarketClocksEndpointModel` (`_versioned_url(client.trading_url, "v3")`). All three new abstract types subtype `AbstractAlpacaEndpointModel` and are exported.

**D2. Writes through `api`.** Two private functions, defined with a fallback for every model: `_http_method(model)::String` returns `"GET"`, and `_request_body(model)` returns `nothing`. Write models add methods for both. `api` sends `_http_method(model)` with `_request_body(model)` through `_http_call`. A model whose method is not `"GET"` is never paginated.

**D3. Empty bodies.** Alpaca answers some writes with no body (exercise, do-not-exercise, delete watchlist). Their handlers return `DataFrame()` without parsing the body.

**D4. Symbols in paths are escaped.** Every symbol, identifier or name placed in a URL path goes through `URIs.escapeuri`, so `BTC/USD` becomes `BTC%2FUSD`. This applies to the existing `MyAssetEndpointModel`, `MyPositionEndpointModel`, `MyOptionContractEndpointModel`, `MyOptionChainEndpointModel`, and to `_close_position` in `src/Trading.jl`. Plain tickers do not change, so the golden outputs do not change.

**D5. Tables.** Prices keep typed tables with descriptive names: `_bars_table`, `_quotes_table`, `_trades_table` and `_snapshots_table` are reused for crypto, non-US stocks and the multi-symbol latest endpoints. Records whose fields differ by type (activities, corporate actions, settings, watchlists, clocks, calendars, fixed income) use one new private helper, `_records_table(records::Vector{Any})::DataFrame`:
- the columns are the union of the record keys, in first-seen order, and a field that a record lacks is `missing`;
- a nested object is flattened one level with the prefix `<key>_` (e.g., `market_acronym`), and an array becomes its JSON text;
- text in a field whose name ends with `_at`, or is `timestamp`, `transaction_time` or `t`, is parsed to a UTC `DateTime` with the SDK's RFC 3339 parser; all other values keep their JSON type (`String`, `Float64` for any number, `Bool`), and `null` is `missing`.

**D6. Pagination.** Paginated (follows `next_page_token`): stock auctions, the three historical non-US stock endpoints, the three historical crypto endpoints, corporate actions. Not paginated: news (one page of at most 50 articles; the model has a `page_token` field so a caller can ask for the next page), account activities (Alpaca pages them by `page_token`, which the model also carries), and everything else.

**D7. Logos.** `MyLogoEndpointModel`'s default handler returns the PNG as `Vector{UInt8}`, the one read model whose default handler does not return a `DataFrame`. Its docstring says so.

**D8. Model names and URLs.** Path and query parameter names, defaults and allowed values follow the inventory appendix. Keyword `finish` is sent as `end`, as in 0.4.0. Query keys appear in the order of the table's keyword list; `nothing` values are left out by `_query_string`.

---

### Task 1: Foundation: base URLs, write requests, escaped paths, the generic table

**Files:**
- Modify: `src/Types.jl` (three abstract types), `src/Utility.jl` (`_versioned_url`), `src/Factory.jl` (`_base_url` methods, escaping in the four existing path models), `src/Network.jl` (`api` uses `_http_method` and `_request_body`), `src/Handler.jl` (`_records_table`, `_empty_table`), `src/Trading.jl` (`_close_position` escaping), `src/Alpaca.jl` (exports)
- Test: `test/test_foundation_v05.jl`

**Interfaces:**
- Produces: `_versioned_url(base, version)::String`; `_http_method(model::AbstractAlpacaEndpointModel)::String` (fallback `"GET"`); `_request_body(model::AbstractAlpacaEndpointModel)` (fallback `nothing`); `_records_table(records::Vector{Any})::DataFrame`; `_empty_table(body::String)::DataFrame` returns `DataFrame()`; the three abstract types of D1.

- [ ] **Step 1: Create the branch.** Run `git checkout -b endpoints-0.5`.
- [ ] **Step 2: Write the failing tests** in `test/test_foundation_v05.jl`:

```julia
@testset "v0.5 foundation: versioned base URLs" begin
    @test Alpaca._versioned_url("https://data.alpaca.markets/v2", "v1beta3") == "https://data.alpaca.markets/v1beta3"
    @test Alpaca._versioned_url("https://paper-api.alpaca.markets/v2", "v3") == "https://paper-api.alpaca.markets/v3"
    @test Alpaca._versioned_url("http://127.0.0.1:8080", "v1") == "http://127.0.0.1:8080"
    @test Alpaca._derive_options_url("https://data.alpaca.markets/v2") == "https://data.alpaca.markets/v1beta1"
end

@testset "v0.5 foundation: symbols in paths are escaped" begin
    @test url("http://h", MyAssetEndpointModel(symbol = "BTC/USD")) == "http://h/assets/BTC%2FUSD"
    @test url("http://h", MyPositionEndpointModel(symbol = "BTC/USD")) == "http://h/positions/BTC%2FUSD"
    @test url("http://h", MyAssetEndpointModel(symbol = "AAPL")) == "http://h/assets/AAPL"
end

@testset "v0.5 foundation: generic records table" begin
    records = Any[JSON3.read("""{"id":"a","qty":"5","transaction_time":"2026-11-20T15:00:00Z","market":{"acronym":"NYSE"}}"""),
                  JSON3.read("""{"id":"b","price":1.5,"symbols":["X","Y"],"flag":true,"note":null}""")]
    df = Alpaca._records_table(records)
    @test names(df) == ["id", "qty", "transaction_time", "market_acronym", "price", "symbols", "flag", "note"]
    @test df[1, :transaction_time] == DateTime(2026, 11, 20, 15)
    @test df[1, :qty] == "5"
    @test ismissing(df[1, :price]) && df[2, :price] == 1.5
    @test df[2, :symbols] == "[\"X\",\"Y\"]"
    @test df[2, :flag] == true && ismissing(df[2, :note])
    @test size(Alpaca._records_table(Any[])) == (0, 0)
end
```

Add `include("test_foundation_v05.jl")` at the end of the `@testset "Alpaca.jl"` block in `test/runtests.jl`.

- [ ] **Step 3: Run and see it fail.** Run `julia --project=test -e 'using Pkg; Pkg.develop(path="."); include("test/runtests.jl")'` (or the repo's usual `Pkg.test()`). Expected: FAIL, `_versioned_url` not defined.
- [ ] **Step 4: Implement D1, D2, D4 and D5** as specified in the Design section. `api` keeps its signature. For a non-GET model, `api` makes exactly one `_http_call(client, _http_method(model), first_url; body = _request_body(model))` and returns the handler's result.
- [ ] **Step 5: Add the write-path test** to the same file. It uses a throwaway write model defined in the test file only. It checks that `api` sends `PATCH` with the JSON body, sends one request even when the response holds a `next_page_token`, and that an empty 204 body reaches `_empty_table`:

```julia
mutable struct _TestPatchModel <: Alpaca.AbstractAlpacaTradingEndpointModel end
Alpaca.url(base::String, m::_TestPatchModel) = base * "/thing"
Alpaca._http_method(m::_TestPatchModel) = "PATCH"
Alpaca._request_body(m::_TestPatchModel) = Dict("a" => 1)
Alpaca._default_handler(::Type{_TestPatchModel}, body::String) = Alpaca._records_table(Any[JSON3.read(body)])

@testset "v0.5 foundation: api sends the model's method and body once" begin
    handler, log = recording_handler(req -> json_response(200, Dict("a" => 1, "next_page_token" => "more")))
    with_mock(handler) do client
        df = api(client, _TestPatchModel())
        @test length(log) == 1
        @test log[1].method == "PATCH" && log[1].path == "/thing"
        @test JSON3.read(log[1].body)[:a] == 1
        @test df[1, :a] == 1.0
    end
end
```

- [ ] **Step 6: Run the full suite.** Expected: PASS, including `test/test_golden.jl`.
- [ ] **Step 7: Commit.** `git add -A src test && git commit -m "Add versioned base URLs, write requests through api, escaped path symbols, and a generic records table"`

### Task 2: Remove the two endpoints that Alpaca does not have

`GET /v1beta1/options/quotes` and `GET /v1beta1/options/bars/latest` return 404 for every request (checked live on 2026-11-21 against a made-up path as control), and neither is in Alpaca's spec.

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Network.jl` (`_is_paginated` method), `src/Legacy.jl`, `src/Alpaca.jl`, `docs/src/api/*.md`, `README.md` if it names them
- Modify tests: `test/test_models_url.jl`, `test/test_handlers_marketdata.jl`, `test/test_deprecations.jl`, `test/test_options.jl`, `test/golden/calls.jl`, `test/golden/golden-v0.3.1.jsonl` (drop the `option_quotes` and `option_latest_bar` lines)

**Interfaces:**
- Produces: `MyOptionQuotesEndpointModel`, `MyOptionLatestBarEndpointModel`, `get_option_quotes`, `get_latest_option_bar` no longer exist.

- [ ] **Step 1: Delete** the two models, their `url`, `_default_handler` and `_is_paginated` methods, the two legacy functions, their exports, and their doc entries. Run `grep -rn -E 'OptionQuotesEndpointModel|OptionLatestBarEndpointModel|get_option_quotes|get_latest_option_bar' src docs README.md examples scripts`. Expected: no hits. If `examples/` or `scripts/` use them, stop and report.
- [ ] **Step 2: Delete only the test lines and golden entries that call them.** Keep every other assertion in those files.
- [ ] **Step 3: Run the full suite.** Expected: PASS.
- [ ] **Step 4: Commit.** `git commit -am "Remove the option quotes and latest option bar models, which call endpoints that Alpaca does not have"`

### Task 3: Trading reads: settings, activities, portfolio history, multi-market calendar and clock

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_trading_v05.jl`

**Interfaces:**
- Consumes: `_records_table`, `_versioned_url` (Task 1).
- Produces (all `<: AbstractAlpacaTradingEndpointModel`):
  - `MyAccountConfigurationsEndpointModel()` → `GET /account/configurations`; one-row `_records_table`.
  - `MyAccountActivitiesEndpointModel(; activity_type = nothing, activity_types = nothing, category = nothing, date = nothing, after = nothing, until = nothing, direction = "desc", page_size = 100, page_token = nothing, order_id = nothing)` → `GET /account/activities/{activity_type}` when `activity_type` is set, else `GET /account/activities` with `activity_types` as a comma list. Setting both throws `ArgumentError`. `category` is sent only on the second path. Handler: `_records_table`.
  - `MyPortfolioHistoryEndpointModel(; period = nothing, timeframe = nothing, intraday_reporting = nothing, start = nothing, finish = nothing, pnl_reset = nothing, extended_hours = nothing, cashflow_types = nothing)` → `GET /account/portfolio/history`. Handler: columns `timestamp` (`DateTime` from Unix seconds), `equity`, `profit_loss`, `profit_loss_pct`, `base_value` (the same value in every row). The `cashflow` object is not a column.
  - `MyMarketCalendarEndpointModel(; market = "NYSE", start = nothing, finish = nothing, timezone = nothing)` → `GET {trading v3}/calendar/{market}`. Handler: `_records_table` of `calendar`, with a first column `market` holding `market.acronym`.
  - `MyMarketClocksEndpointModel(; markets = nothing, time = nothing)` → `GET {trading v3}/clock`, `markets` sent as a comma list. Handler: `_records_table` of `clocks` (so `market_acronym`, `market_name`, ... columns).

- [ ] **Step 1: Write the failing tests.** For each model: one `url("http://h", model)` assertion with every keyword set, e.g.
  `@test url("http://h", MyAccountActivitiesEndpointModel(activity_type = "FILL", date = Date(2026, 11, 20))) == "http://h/account/activities/FILL?date=2026-11-20&direction=desc&page_size=100"`;
  `@test_throws ArgumentError MyAccountActivitiesEndpointModel(activity_type = "FILL", activity_types = ["DIV"])`;
  one base-URL assertion through a real client, `@test url(c, MyMarketClocksEndpointModel(markets = ["NYSE", "XNAS"])) == "https://paper-api.alpaca.markets/v3/clock?markets=NYSE%2CXNAS"`;
  and one handler assertion each on a fixed body (portfolio history: `timestamp = [1763650800]` gives `DateTime(2025, 11, 20, 15)`, `df.equity == [100000.0]`; calendar: first column `market == ["NYSE"]`; clocks: `df[1, :market_acronym] == "NYSE"`, `df[1, :is_market_day] == true`).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement the five models**, their `url` methods, the two `_base_url` overrides, and the handlers.
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add account settings, activities, portfolio history, and the multi-market calendar and clock"`

### Task 4: Watchlists

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_watchlists_v05.jl`

**Interfaces:**
- Consumes: D2 write path, `_records_table`, `_empty_table`, the existing `_assets_table`.
- Produces (all `<: AbstractAlpacaTradingEndpointModel`). "By id or name" models take `id = nothing, name = nothing` and throw `ArgumentError` unless exactly one is set; `id` gives `/watchlists/{id}`, `name` gives `/watchlists:by_name?name=...`.
  - `MyWatchlistsEndpointModel()` → `GET /watchlists`; `_records_table`.
  - `MyWatchlistEndpointModel(; id, name)` → `GET`.
  - `MyCreateWatchlistEndpointModel(; name::String, symbols = String[])` → `POST /watchlists`, body `{"name", "symbols"}`.
  - `MyUpdateWatchlistEndpointModel(; id, name, new_name = nothing, symbols = nothing)` → `PUT`, body holds `name` (from `new_name`) and `symbols`, each only when set; both unset throws `ArgumentError`.
  - `MyAddWatchlistAssetEndpointModel(; id, name, symbol::String)` → `POST`, body `{"symbol"}`.
  - `MyRemoveWatchlistAssetEndpointModel(; id::String, symbol::String)` → `DELETE /watchlists/{id}/{symbol}` (Alpaca has no by-name form).
  - `MyDeleteWatchlistEndpointModel(; id, name)` → `DELETE`; handler `_empty_table`.
  - One private `_watchlist_table(body::String)::DataFrame` for every model that returns one watchlist: one row per asset, columns `watchlist_id`, `watchlist_name`, then the `_assets_table` columns. A watchlist with no assets gives zero rows with the same columns.

- [ ] **Step 1: Write the failing tests**: a `url` assertion per model and form, `@test Alpaca._http_method(MyUpdateWatchlistEndpointModel(id = "w1", symbols = ["AAPL"])) == "PUT"`, `@test Alpaca._request_body(MyCreateWatchlistEndpointModel(name = "tech", symbols = ["AAPL"])) == Dict("name" => "tech", "symbols" => ["AAPL"])`, the `ArgumentError` cases, `_watchlist_table` on a body with two assets and on one with `"assets":[]`, a mock round trip of create (method `POST` and body recorded), and a mock round trip of delete that answers status 204 with no body and gives `size(df) == (0, 0)`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add watchlist reads and writes"`

### Task 5: Account and order writes: settings, replace, exercise

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_writes_v05.jl`

**Interfaces:**
- Produces (all `<: AbstractAlpacaTradingEndpointModel`):
  - `MyUpdateAccountConfigurationsEndpointModel(; disable_overnight_trading = nothing, fractional_trading = nothing, max_margin_multiplier = nothing, max_options_trading_level = nothing, no_shorting = nothing, ptp_no_exception_entry = nothing, suspend_trade = nothing, trade_confirm_email = nothing)` → `PATCH /account/configurations`, body holds the set fields only (`max_margin_multiplier` as text, `max_options_trading_level` in `0:3`); no field set throws `ArgumentError`. Handler: one-row `_records_table`.
  - `MyReplaceOrderEndpointModel(; id::String, qty = nothing, time_in_force = nothing, limit_price = nothing, stop_price = nothing, trail = nothing, client_order_id = nothing)` → `PATCH /orders/{id}`, numbers sent as text the way `_single_order_body` sends them; no change set throws `ArgumentError`. Handler: the existing `_orders_table`.
  - `MyExerciseOptionEndpointModel(; symbol::String)` → `POST /positions/{symbol}/exercise`; `MyDoNotExerciseOptionEndpointModel(; symbol::String)` → `POST /positions/{symbol}/do-not-exercise`. Both: no body, handler `_empty_table`.

- [ ] **Step 1: Write the failing tests**: method, path and body of each model; the `ArgumentError` cases; a mock round trip of replace returning an order JSON (assert `df[1, :id]` and the `PATCH` body `{"limit_price":"101.5"}`); a mock exercise returning status 200 with an empty body gives `size(df) == (0, 0)`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add account settings updates, order replacement, and option exercise instructions"`

### Task 6: Orders: bracket, OCO and OTO classes; crypto orders

**Files:**
- Modify: `src/Types.jl` (`MyCryptoOrderModel`), `src/Trading.jl`, `src/Alpaca.jl`
- Test: `test/test_trading_classes_crypto_v05.jl`

**Interfaces:**
- Produces:
  - `submit(client, m::MyEquityOrderModel; <0.4.0 keywords>..., order_class = nothing, take_profit_limit_price = nothing, stop_loss_stop_price = nothing, stop_loss_limit_price = nothing)::Order`. Rules, checked before any request: `order_class` is `nothing`, `"simple"`, `"bracket"`, `"oco"` or `"oto"`; bracket needs `take_profit_limit_price` and `stop_loss_stop_price`; oco needs both and `type == "limit"`; oto needs exactly one of the two legs; the leg prices are refused when `order_class` is `nothing` or `"simple"`. Body adds `"order_class"`, `"take_profit" => {"limit_price"}`, `"stop_loss" => {"stop_price", "limit_price"?}`, prices as text.
  - `MyCryptoOrderModel(; symbol::String, side::String, qty = nothing, notional = nothing)`, same checks as `MyEquityOrderModel`.
  - `submit(client, m::MyCryptoOrderModel; type = "market", time_in_force = "gtc", limit_price = nothing, stop_price = nothing, client_order_id = nothing)::Order`. `type` in `market`, `limit`, `stop_limit`; `time_in_force` in `gtc`, `ioc`; anything else throws `ArgumentError` before any request. Builds the body with `_single_order_body` and sends it with `_post_order`.

- [ ] **Step 1: Write the failing tests** with the mock server: the recorded body of a bracket order (`order_class == "bracket"`, `take_profit.limit_price == "110"`, `stop_loss.stop_price == "90"`), one `ArgumentError` per rule above, a crypto notional buy (`symbol == "BTC/USD"`, `notional == "25"`, `time_in_force == "gtc"`), and `@test_throws ArgumentError submit(client, MyCryptoOrderModel(symbol = "BTC/USD", side = "buy", qty = 0.001); time_in_force = "day")`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Existing equity calls with no class keywords must send the same body as 0.4.0.
- [ ] **Step 4: Run the full suite.** Expected: PASS, golden included.
- [ ] **Step 5: Commit.** `git commit -am "Add bracket, OCO, and OTO order classes and crypto orders"`

### Task 7: Stock data: latest for many symbols, auctions, condition and exchange codes

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Network.jl` (`_is_paginated`), `src/Alpaca.jl`
- Test: `test/test_endpoints_stocks_v05.jl`

**Interfaces:**
- Produces (all `<: AbstractAlpacaStockDataEndpointModel`):
  - `MyStockLatestBarsEndpointModel(; symbols, feed = "iex", currency = nothing)` → `/stocks/bars/latest`; `_bars_table`. Same for `MyStockLatestQuotesEndpointModel` (`/stocks/quotes/latest`, `_quotes_table`) and `MyStockLatestTradesEndpointModel` (`/stocks/trades/latest`, `_trades_table`).
  - `MyStockAuctionsEndpointModel(; symbols, start = nothing, finish = nothing, limit = 1000, feed = "sip", sort = nothing)` → `/stocks/auctions`, paginated. Handler `_auctions_table`: one row per auction print, columns `timestamp`, `symbol`, `date`, `auction` (`"open"` for records under `o`, `"close"` under `c`), `price`, `size`, `exchange`, `condition`.
  - `MyStockConditionsEndpointModel(; ticktype = "trade", tape = "A")` → `/stocks/meta/conditions/{ticktype}?tape=`; `MyStockExchangesEndpointModel()` → `/stocks/meta/exchanges`. Both use `_codes_table(body)::DataFrame`, columns `code`, `name`, one row per key of the response object.

- [ ] **Step 1: Write the failing tests**: one `url` per model; latest-quotes handler on `{"quotes":{"AAPL":{...},"MSFT":{...}}}` gives `df.symbol == ["AAPL", "MSFT"]`; auctions handler on one day with one opening and two closing prints gives 3 rows and `df.auction == ["open", "close", "close"]`; `_codes_table` on `{"A":"NYSE American","N":"NYSE"}` gives `df.code == ["A", "N"]`; `@test Alpaca._is_paginated(MyStockAuctionsEndpointModel(symbols = "AAPL")) == true`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add latest stock data for many symbols, auctions, and condition and exchange codes"`

### Task 8: Stocks on non-US exchanges

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Network.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_global_stocks_v05.jl`

**Interfaces:**
- Consumes: `_snapshots_table` gains a keyword `snake_case::Bool = false`; when `true` it reads the groups from `latest_trade`, `latest_quote`, `minute_bar`, `daily_bar`, `prev_daily_bar`. Existing calls are unchanged.
- Produces (all `<: AbstractAlpacaGlobalStockDataEndpointModel`; `feed::String` is required and is one of `euroctp`, `xetr`, `xhkg`, `xlon`, `xsau`, else `ArgumentError`; it goes in the path, `/stocks/{feed}/...`):
  - `MyGlobalStockBarsEndpointModel(; feed, symbols, timeframe, start, finish = nothing, page_size = 1000, sort = nothing)` → `/stocks/{feed}/bars`, paginated, `_bars_table`.
  - `MyGlobalStockQuotesEndpointModel(; feed, symbols, start, finish = nothing, page_size = 1000, sort = nothing)` and `MyGlobalStockTradesEndpointModel(...)`, same keywords → `/quotes`, `/trades`, paginated.
  - `MyGlobalStockLatestBarsEndpointModel(; feed, symbols)`, `...LatestQuotes...`, `...LatestTrades...` → `/stocks/{feed}/latest/bars|quotes|trades`.
  - `MyGlobalStockSnapshotsEndpointModel(; feed, symbols)` → `/stocks/{feed}/snapshots`, `_snapshots_table(...; snake_case = true)`.

- [ ] **Step 1: Write the failing tests**: one `url` per model, e.g. `@test url(c, MyGlobalStockLatestQuotesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"])) == "https://data.alpaca.markets/v3/stocks/xetr/latest/quotes?symbols=SAP%3AXETR"`; the feed `ArgumentError`; a latest-quotes body with numbers sent as text (`"bp":"201.5","bs":"10"`) gives `df[1, :bid_price] == 201.5` and `df[1, :bid_size] == 10`; a snake_case snapshot fills `daily_bar_close`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add stock data for non-US exchanges"`

### Task 9: Option codes and crypto data

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Network.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_crypto_v05.jl`

**Interfaces:**
- Produces:
  - `MyOptionExchangesEndpointModel()` → `/options/meta/exchanges`; `MyOptionConditionsEndpointModel(; ticktype = "trade")` → `/options/meta/conditions/{ticktype}`. Both `<: AbstractAlpacaOptionDataEndpointModel`, handler `_codes_table` (Task 7).
  - All `<: AbstractAlpacaCryptoDataEndpointModel`, with `loc::String = "us"` (one of `us`, `us-1`, `us-2`, `eu-1`, `bs-1`, else `ArgumentError`) placed in the path `/crypto/{loc}/...`:
    - `MyCryptoBarsEndpointModel(; symbols, timeframe, start = nothing, finish = nothing, limit = 1000, sort = nothing, loc = "us")` → `/bars`, paginated, `_bars_table`.
    - `MyCryptoQuotesEndpointModel(; symbols, start = nothing, finish = nothing, limit = 1000, sort = nothing, loc = "us")` and `MyCryptoTradesEndpointModel(...)` → `/quotes`, `/trades`, paginated.
    - `MyCryptoLatestBarsEndpointModel(; symbols, loc = "us")`, `...LatestQuotes...`, `...LatestTrades...` → `/latest/bars|quotes|trades`.
    - `MyCryptoLatestOrderbooksEndpointModel(; symbols, loc = "us")` → `/latest/orderbooks`. Handler `_orderbooks_table`: one row per price level, columns `timestamp`, `symbol`, `side` (`"bid"` from `b`, `"ask"` from `a`), `price`, `size`; bids first, in the response order.
    - `MyCryptoSnapshotsEndpointModel(; symbols, loc = "us")` → `/snapshots`, `_snapshots_table(...; snake_case = false)`, no greeks.

- [ ] **Step 1: Write the failing tests**: `@test url(c, MyCryptoBarsEndpointModel(symbols = ["BTC/USD"], timeframe = "1Hour")) == "https://data.alpaca.markets/v1beta3/crypto/us/bars?symbols=BTC%2FUSD&timeframe=1Hour&limit=1000"`; the `loc` `ArgumentError`; an order-book body with 2 bids and 1 ask gives `df.side == ["bid", "bid", "ask"]`; a multi-page crypto bars round trip through the mock gives every row once; the option codes `url`s.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add crypto market data and option condition and exchange codes"`

### Task 10: News, screener, corporate actions, logos, fixed income

**Files:**
- Modify: `src/Types.jl`, `src/Factory.jl`, `src/Handler.jl`, `src/Network.jl`, `src/Alpaca.jl`
- Test: `test/test_endpoints_market_v05.jl`

**Interfaces:**
- Produces (all `<: AbstractAlpacaMarketDataEndpointModel`):
  - `MyNewsEndpointModel(; symbols = nothing, start = nothing, finish = nothing, sort = "desc", limit = 50, include_content = false, exclude_contentless = false, page_token = nothing)` → `/news`, not paginated (D6). Handler `_news_table`: columns `id`, `created_at`, `updated_at`, `headline`, `author`, `source`, `summary`, `url`, `symbols` (comma-joined text), `content` (`missing` unless sent).
  - `MyMostActivesEndpointModel(; by = "volume", top = 10)` → `/screener/stocks/most-actives`; columns `symbol`, `volume`, `trade_count`.
  - `MyMoversEndpointModel(; market_type = "stocks", top = 10)` → `/screener/{market_type}/movers`; columns `direction` (`"gainer"` or `"loser"`), `symbol`, `price`, `change`, `percent_change`; gainers first.
  - `MyCorporateActionsEndpointModel(; symbols = nothing, cusips = nothing, types = nothing, start = nothing, finish = nothing, ids = nothing, limit = 100, sort = nothing, region = nothing, data_quality = nothing)` → `{data v1}/corporate-actions`, paginated. Handler: one row per action, first column `type` (the group key, e.g. `"cash_dividends"`), then `_records_table` columns.
  - `MyLogoEndpointModel(; symbol::String, placeholder = true)` → `/logos/{symbol}`; handler returns `Vector{UInt8}(body)` (D7).
  - `MyFixedIncomeLatestPricesEndpointModel(; isins)` → `/fixed_income/latest/prices`; `MyFixedIncomeLatestQuotesEndpointModel(; isins, trade_size = nothing)` → `/fixed_income/latest/quotes`. Handler: first column `isin`, then `_records_table` of the record under each ISIN (Alpaca's short field names, `t` parsed to `DateTime`).

- [ ] **Step 1: Write the failing tests**: one `url` per model, including `@test url(c, MyCorporateActionsEndpointModel(symbols = ["AAPL"])) == "https://data.alpaca.markets/v1/corporate-actions?symbols=AAPL&limit=100"` and `@test url(c, MyNewsEndpointModel(symbols = ["AAPL"])) == "https://data.alpaca.markets/v1beta1/news?symbols=AAPL&sort=desc&limit=50&include_content=false&exclude_contentless=false"`; `@test Alpaca._is_paginated(MyNewsEndpointModel()) == false`; movers handler order; corporate-actions handler on a body with one dividend and one split gives `df.type == ["cash_dividends", "forward_splits"]`; a mock logo response with bytes `UInt8[0x89, 0x50, 0x4e, 0x47]` round-trips to the same `Vector{UInt8}`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the full suite.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add news, screener, corporate actions, logos, and fixed income prices and quotes"`

### Task 11: Documentation, version, and live checks

**Files:**
- Modify: `docs/src/api/models.md`, `docs/src/api/reading.md`, `docs/src/api/trading.md`, `docs/src/api/types.md`, `README.md` (one short "What the SDK covers" list, by area), `Project.toml` (`version = "0.5.0"`)
- Create: `test/test_live_v05.jl` (included from `runtests.jl`, skipped unless `ALPACA_LIVE_TESTS=1`)

**Interfaces:**
- Consumes: every model from Tasks 1–10.

- [ ] **Step 1: Docs.** Add every new model to the Documenter pages with `@docs` blocks. Run `julia --project=docs docs/make.jl`. Expected: builds with no missing-docstring warning for an exported name.
- [ ] **Step 2: Export audit.** Run a script that lists `names(Alpaca)` and checks each new model from this plan is there. Expected: none missing.
- [ ] **Step 3: Live read test.** In `test/test_live_v05.jl`, for each new read model, one `api` call against the paper account with small arguments (e.g. `MyCryptoLatestOrderbooksEndpointModel(symbols = ["BTC/USD"])`, `MyNewsEndpointModel(symbols = ["AAPL"], limit = 3)`, `MyMarketClocksEndpointModel(markets = ["NYSE", "XLON"])`, `MyGlobalStockLatestTradesEndpointModel(feed = "xetr", symbols = ["SAP:XETR"])`), asserting a `DataFrame` with the documented columns. An endpoint that the paper plan's data subscription refuses (HTTP 403) is recorded as skipped with its message, not failed, and is listed in the final report.
- [ ] **Step 4: Live write test**, inside `if get(ENV, "ALPACA_LIVE_WRITE_TESTS", "") == "1"`: create a watchlist named `sdk-live-<timestamp>`, add and remove a symbol, rename it, delete it; read the account settings and PATCH back the same `trade_confirm_email` value; submit a `gtc` crypto limit buy of `BTC/USD` at 50% of the latest bid, replace its limit price, cancel it. Every step asserts the result, and a `finally` block deletes the watchlist and cancels the order.
- [ ] **Step 5: Run everything.** `ALPACA_LIVE_TESTS=1 ALPACA_LIVE_WRITE_TESTS=1` full suite. Expected: PASS, with any 403 skips listed.
- [ ] **Step 6: Commit.** `git commit -am "Document the 0.5.0 endpoints, add live checks, and set the version to 0.5.0"`. Do not push or tag.

## Review Focus

1. **Crypto pairs in paths.** `BTC/USD` in an asset, position, close or logo path must be escaped. Pinned in Task 1 (asset, position); Task 10 adds `@test url("http://h", MyLogoEndpointModel(symbol = "BTC/USD")) == "http://h/logos/BTC%2FUSD?placeholder=true"`.
2. **Empty write responses.** A 204 or an empty 200 must give `DataFrame()`, never a JSON parse error. Pinned in Task 5 (exercise) and Task 4 (delete watchlist round trip through the mock, 204).
3. **Numbers sent as text.** Non-US stock quotes send prices and sizes as strings. Pinned in Task 8.
4. **A write is sent once.** A write response that holds `next_page_token` must not trigger a second request. Pinned in Task 1.
5. **Mock and real base URLs.** Each new family must reach the right version on the real hosts and stay on the mock host unchanged. Pinned by the real-client `url` assertions in Tasks 3, 8, 9 and 10, and the mock round trips.
