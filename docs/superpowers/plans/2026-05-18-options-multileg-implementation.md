# Multi-leg Options Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mleg` multi-leg options order support to `Alpaca.jl` so callers can submit 2–4 leg option spreads, with parent + child legs round-tripping through `submit_multileg_order`, `list_orders`, and `get_order`.

**Architecture:** A new `OrderLeg` input struct describes each leg. `submit_multileg_order(client, legs; ...)` posts `order_class="mleg"` to `/v2/orders`. The existing `Order` struct gains three new fields (`order_class`, `position_intent`, `legs`) and loosens `symbol`/`side` to `Union{String,Nothing}` so mleg parent orders parse without crashing. Client-side validation is shape-and-enum only; semantic checks (same-underlying, expiry rules, spread shape) are left to Alpaca. Tests follow the existing two-tier pattern: mock-server unit tests in `test/test_orders.jl` plus opt-in paper-account smoke tests in `test/test_integration.jl`.

**Tech Stack:** Julia 1.10+, HTTP.jl, JSON3.jl, Test.jl. Existing helpers (`_parse_float`, `_parse_float_default`, `_parse_rfc3339`, `_trading_post`, `with_mock`, `recording_handler`, `json_response`).

**Spec:** `docs/superpowers/specs/2026-05-18-options-multileg-design.md`

---

## File Structure

| File | Role |
|---|---|
| `src/types.jl` | Add `OrderLeg` struct; modify `Order` struct (3 new fields, 2 nullability changes). |
| `src/orders.jl` | Update `_parse_order`; add `_maybe_string`, `_parse_legs`, `_validate_mleg`, `_MLEG_*` constants, `submit_multileg_order`. |
| `src/Alpaca.jl` | Export `OrderLeg`, `submit_multileg_order`. |
| `test/test_orders.jl` | New `@testset` blocks: mleg body shape, validation cases, mleg parent parsing, single-leg regression, list with mleg parent. |
| `test/test_integration.jl` | New smoke tests (gated by `ALPACA_LIVE_TESTS=1`): open & cancel, round-trip, parent/legs visibility. |
| `Project.toml` | Bump `version` to `0.3.0` (breaking struct shape change). |

Total expected diff: ~250 LOC src + ~250 LOC tests.

---

## Task 1: Extend `Order` struct and add response parsing for mleg

Make the existing `Order` type capable of representing both simple and multi-leg orders, and teach `_parse_order` to populate the new fields. This is one task because the struct change and parser change must land together for the module to compile.

**Files:**
- Modify: `src/types.jl` (`Order` struct, lines ~89–107)
- Modify: `src/orders.jl` (`_parse_order`, lines 1–21; add helpers)
- Test:   `test/test_orders.jl` (new mleg fixture + parsing testset)

- [ ] **Step 1: Add the failing mleg-parse test**

Append to `test/test_orders.jl`:

```julia
const _MLEG_PAYLOAD = Dict(
    "id"              => "f00dcafe-0000-0000-0000-00000000mleg",
    "client_order_id" => "client-mleg-1",
    "asset_class"     => "us_option",
    "type"            => "limit",
    "time_in_force"   => "day",
    "order_class"     => "mleg",
    "qty"             => "1",
    "filled_qty"      => "0",
    "limit_price"     => "-2.00",
    "stop_price"      => nothing,
    "filled_avg_price"=> nothing,
    "status"          => "accepted",
    "created_at"      => "2026-04-11T14:30:00Z",
    "submitted_at"    => "2026-04-11T14:30:00Z",
    "filled_at"       => nothing,
    # NB: top-level `symbol` and `side` deliberately absent — that is the wire
    # shape Alpaca returns for an mleg parent.
    "legs" => [
        Dict(
            "id"              => "leg-short-put",
            "client_order_id" => "client-mleg-1-leg-1",
            "symbol"          => "SPY250620P00420000",
            "asset_class"     => "us_option",
            "side"            => "sell",
            "type"            => "limit",
            "time_in_force"   => "day",
            "order_class"     => "",
            "position_intent" => "sell_to_open",
            "qty"             => "1",
            "filled_qty"      => "0",
            "limit_price"     => nothing,
            "stop_price"      => nothing,
            "filled_avg_price"=> nothing,
            "status"          => "accepted",
            "created_at"      => "2026-04-11T14:30:00Z",
            "submitted_at"    => "2026-04-11T14:30:00Z",
            "filled_at"       => nothing,
        ),
        Dict(
            "id"              => "leg-long-put",
            "client_order_id" => "client-mleg-1-leg-2",
            "symbol"          => "SPY250620P00415000",
            "asset_class"     => "us_option",
            "side"            => "buy",
            "type"            => "limit",
            "time_in_force"   => "day",
            "order_class"     => "",
            "position_intent" => "buy_to_open",
            "qty"             => "1",
            "filled_qty"      => "0",
            "limit_price"     => nothing,
            "stop_price"      => nothing,
            "filled_avg_price"=> nothing,
            "status"          => "accepted",
            "created_at"      => "2026-04-11T14:30:00Z",
            "submitted_at"    => "2026-04-11T14:30:00Z",
            "filled_at"       => nothing,
        ),
    ],
)

@testset "orders: parse mleg parent with two child legs" begin
    handler = function(_req)
        return json_response(200, _MLEG_PAYLOAD)
    end

    with_mock(handler) do client
        o = get_order(client, _MLEG_PAYLOAD["id"])
        @test o isa Order
        @test o.order_class == "mleg"
        @test o.symbol === nothing
        @test o.side === nothing
        @test o.position_intent === nothing
        @test o.legs !== nothing
        @test length(o.legs) == 2

        short_leg = o.legs[1]
        @test short_leg.symbol == "SPY250620P00420000"
        @test short_leg.side == "sell"
        @test short_leg.position_intent == "sell_to_open"
        @test short_leg.order_class == ""
        @test short_leg.legs === nothing
        @test short_leg.qty == 1.0

        long_leg = o.legs[2]
        @test long_leg.symbol == "SPY250620P00415000"
        @test long_leg.side == "buy"
        @test long_leg.position_intent == "buy_to_open"
    end
end

@testset "orders: simple equity parsing regression" begin
    handler = function(_req)
        return json_response(200, _ORDER_PAYLOAD)
    end

    with_mock(handler) do client
        o = get_order(client, _ORDER_PAYLOAD["id"])
        @test o.symbol == "AAPL"
        @test o.side == "buy"
        @test o.order_class == ""
        @test o.position_intent === nothing
        @test o.legs === nothing
    end
end
```

- [ ] **Step 2: Run the new tests to see them fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -40`

Expected failure: the test file will not even compile, because `Order` does not yet have `order_class`, `position_intent`, or `legs` fields. Error message will mention "type Order has no field order_class" or similar.

- [ ] **Step 3: Update the `Order` struct in `src/types.jl`**

Replace the existing `Order` struct (around lines 89–107) with:

```julia
"""
    Order

A trading order. Returned by [`submit_order`](@ref), [`submit_multileg_order`](@ref),
[`get_order`](@ref), and [`list_orders`](@ref).

Selected fields:

- `id`, `client_order_id`
- `symbol` — `String` for single-leg orders; `nothing` for multi-leg parent orders
  (Alpaca returns no top-level symbol on an `mleg` parent — each leg has its own)
- `asset_class`
- `side` (`"buy"` or `"sell"`) — `nothing` for multi-leg parents (lives on each leg)
- `type`, `time_in_force`, `status`
- `order_class` — `""` for simple orders; `"mleg"`, `"bracket"`, `"oco"`, `"oto"` for compound orders
- `position_intent` — `"buy_to_open"` / `"sell_to_open"` / `"buy_to_close"` / `"sell_to_close"`
  on option legs; `nothing` otherwise
- `qty`, `filled_qty`, `limit_price`, `stop_price`, `filled_avg_price`
- `created_at`, `submitted_at`, `filled_at` (all `DateTime` in UTC, may be `nothing`)
- `legs` — `Vector{Order}` of child legs on a multi-leg parent; `nothing` otherwise
- `raw` — the original `JSON3.Object` payload
"""
struct Order
    id::String
    client_order_id::String
    symbol::Union{String,Nothing}
    asset_class::String
    side::Union{String,Nothing}
    type::String
    time_in_force::String
    order_class::String
    position_intent::Union{String,Nothing}
    qty::Union{Float64,Nothing}
    filled_qty::Float64
    limit_price::Union{Float64,Nothing}
    stop_price::Union{Float64,Nothing}
    filled_avg_price::Union{Float64,Nothing}
    status::String
    created_at::Union{DateTime,Nothing}
    submitted_at::Union{DateTime,Nothing}
    filled_at::Union{DateTime,Nothing}
    legs::Union{Vector{Order},Nothing}
    raw::JSON3.Object
end
```

- [ ] **Step 4: Update `_parse_order` and add helpers in `src/orders.jl`**

Replace the existing `_parse_order` definition (lines 1–21) with:

```julia
_maybe_string(x::Nothing) = nothing
_maybe_string(x) = String(x)

function _parse_legs(v)
    v === nothing && return nothing
    isempty(v)    && return nothing
    return [_parse_order(leg) for leg in v]
end

function _parse_order(o::JSON3.Object)
    return Order(
        String(o.id),
        String(get(o, :client_order_id, "")),
        _maybe_string(get(o, :symbol, nothing)),
        String(get(o, :asset_class, "us_equity")),
        _maybe_string(get(o, :side, nothing)),
        String(o.type),
        String(o.time_in_force),
        String(get(o, :order_class, "")),
        _maybe_string(get(o, :position_intent, nothing)),
        _parse_float(get(o, :qty, nothing)),
        _parse_float_default(get(o, :filled_qty, "0")),
        _parse_float(get(o, :limit_price, nothing)),
        _parse_float(get(o, :stop_price, nothing)),
        _parse_float(get(o, :filled_avg_price, nothing)),
        String(o.status),
        _parse_rfc3339(get(o, :created_at, nothing)),
        _parse_rfc3339(get(o, :submitted_at, nothing)),
        _parse_rfc3339(get(o, :filled_at, nothing)),
        _parse_legs(get(o, :legs, nothing)),
        o,
    )
end
```

- [ ] **Step 5: Run the test suite to confirm parsing tests pass and nothing else regressed**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -40`

Expected: full suite green. The two new testsets pass; existing `test_orders.jl` testsets still pass (they only read `o.symbol`, `o.qty`, `o.id`, `o.status`, `o.limit_price` — all still work).

If anything outside `test_orders.jl` breaks, it will likely be a `Position` or `Order` consumer that did `String(o.symbol)`. Adjust the call site to `o.symbol === nothing ? "" : o.symbol` or similar; do not roll back the struct change.

- [ ] **Step 6: Commit**

```bash
git add src/types.jl src/orders.jl test/test_orders.jl
git commit -m "Extend Order struct for mleg parents with nested child legs

Adds order_class, position_intent, and legs fields. Loosens symbol and side
to Union{String,Nothing} so mleg parent orders parse without crashing.
_parse_order now recursively parses nested legs into child Order values."
```

---

## Task 2: Add `OrderLeg` input struct

Add the input-only struct callers use to describe each leg. Trivial, but warrants its own commit so the diff is reviewable.

**Files:**
- Modify: `src/types.jl` (append after the `Order` struct)
- Test:   `test/test_orders.jl` (one construction testset)

- [ ] **Step 1: Write the failing test**

Append to `test/test_orders.jl`:

```julia
@testset "orders: OrderLeg construction" begin
    leg = OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open")
    @test leg.symbol == "SPY250620P00420000"
    @test leg.ratio_qty == 1
    @test leg.side == "sell"
    @test leg.position_intent == "sell_to_open"
end
```

- [ ] **Step 2: Run the test to see it fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20`

Expected: `UndefVarError: OrderLeg not defined` from the test file at the `OrderLeg(...)` call.

- [ ] **Step 3: Add the struct**

Append to `src/types.jl` (after the `Order` struct):

```julia
"""
    OrderLeg(symbol, ratio_qty, side, position_intent)

Input descriptor for one leg of a multi-leg option order. Pass a
`Vector{OrderLeg}` to [`submit_multileg_order`](@ref).

Fields:

- `symbol` — OCC option symbol (e.g. `"SPY250620P00420000"`)
- `ratio_qty` — number of contracts per spread unit (typically `1`)
- `side` — `"buy"` or `"sell"`
- `position_intent` — `"buy_to_open"`, `"sell_to_open"`, `"buy_to_close"`,
  or `"sell_to_close"`
"""
struct OrderLeg
    symbol::String
    ratio_qty::Int
    side::String
    position_intent::String
end
```

- [ ] **Step 4: Export `OrderLeg`**

In `src/Alpaca.jl`, find the line:

```julia
export Account, Order, Position, Asset, Bar, Quote, Trade, MarketClock,
       CalendarDay, AlpacaError,
       OptionContract, OptionGreeks, OptionSnapshot
```

Replace with:

```julia
export Account, Order, OrderLeg, Position, Asset, Bar, Quote, Trade, MarketClock,
       CalendarDay, AlpacaError,
       OptionContract, OptionGreeks, OptionSnapshot
```

- [ ] **Step 5: Run the test to confirm it passes**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: full suite green.

- [ ] **Step 6: Commit**

```bash
git add src/types.jl src/Alpaca.jl test/test_orders.jl
git commit -m "Add OrderLeg input struct for multi-leg option orders"
```

---

## Task 3: Add `_validate_mleg` and constants

Pure validation helper — no HTTP. Test-drive each `ArgumentError` case.

**Files:**
- Modify: `src/orders.jl` (append before `submit_order`)
- Test:   `test/test_orders.jl` (one testset, multiple `@test_throws`)

- [ ] **Step 1: Write the failing tests**

Append to `test/test_orders.jl`:

```julia
@testset "orders: _validate_mleg" begin
    good = [
        OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
        OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
    ]

    # Happy path: 2 legs, type=limit, limit_price set
    @test Alpaca._validate_mleg(good, "limit", -2.0) === nothing

    # Happy path: 2 legs, type=market, no limit_price
    @test Alpaca._validate_mleg(good, "market", nothing) === nothing

    # Leg count: 1 leg
    @test_throws ArgumentError Alpaca._validate_mleg(good[1:1], "limit", -2.0)

    # Leg count: 5 legs (build by duplication)
    too_many = vcat(good, good, good[1:1])
    @test length(too_many) == 5
    @test_throws ArgumentError Alpaca._validate_mleg(too_many, "limit", -2.0)

    # Limit without price
    @test_throws ArgumentError Alpaca._validate_mleg(good, "limit", nothing)

    # Bad type
    @test_throws ArgumentError Alpaca._validate_mleg(good, "stop", nothing)

    # Bad side
    bad_side = [
        OrderLeg("SPY250620P00420000", 1, "shrt", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_side, "limit", -2.0)

    # Bad position_intent
    bad_intent = [
        OrderLeg("SPY250620P00420000", 1, "sell", "open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_intent, "limit", -2.0)

    # ratio_qty < 1
    bad_ratio = [
        OrderLeg("SPY250620P00420000", 0, "sell", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(bad_ratio, "limit", -2.0)

    # Empty symbol
    empty_sym = [
        OrderLeg("", 1, "sell", "sell_to_open"),
        good[2],
    ]
    @test_throws ArgumentError Alpaca._validate_mleg(empty_sym, "limit", -2.0)
end
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20`

Expected: `UndefVarError: _validate_mleg not defined` (the test reaches it via `Alpaca._validate_mleg` since it's not exported).

- [ ] **Step 3: Implement the validator**

Append to `src/orders.jl`:

```julia
const _MLEG_SIDES   = ("buy", "sell")
const _MLEG_INTENTS = ("buy_to_open", "sell_to_open", "buy_to_close", "sell_to_close")
const _MLEG_TYPES   = ("market", "limit")

function _validate_mleg(legs::Vector{OrderLeg},
                        type::AbstractString,
                        limit_price::Union{Real,Nothing})
    n = length(legs)
    (n in 2:4) || throw(ArgumentError(
        "multi-leg order requires 2–4 legs, got $n"))

    type in _MLEG_TYPES || throw(ArgumentError(
        "type must be one of $(_MLEG_TYPES), got \"$type\""))

    if type == "limit" && limit_price === nothing
        throw(ArgumentError("limit_price is required when type=\"limit\""))
    end

    for (i, l) in pairs(legs)
        l.side in _MLEG_SIDES || throw(ArgumentError(
            "leg $i: side must be \"buy\" or \"sell\", got \"$(l.side)\""))
        l.position_intent in _MLEG_INTENTS || throw(ArgumentError(
            "leg $i: position_intent must be one of $(_MLEG_INTENTS), got \"$(l.position_intent)\""))
        l.ratio_qty >= 1 || throw(ArgumentError(
            "leg $i: ratio_qty must be ≥ 1, got $(l.ratio_qty)"))
        isempty(l.symbol) && throw(ArgumentError("leg $i: symbol is empty"))
    end
    return nothing
end
```

- [ ] **Step 4: Run the tests to confirm pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: full suite green.

- [ ] **Step 5: Commit**

```bash
git add src/orders.jl test/test_orders.jl
git commit -m "Add _validate_mleg with shape and enum checks for multi-leg orders

Validates leg count (2-4), side, position_intent, ratio_qty, symbol
non-emptiness, type/limit_price coherence. Semantic checks (same
underlying, expiry rules) left to Alpaca's server-side validation."
```

---

## Task 4: Add `submit_multileg_order`

The actual SDK entry point. Asserts request body shape via the mock server.

**Files:**
- Modify: `src/orders.jl` (append after `submit_order`)
- Modify: `src/Alpaca.jl` (add export)
- Test:   `test/test_orders.jl` (body-shape testset)

- [ ] **Step 1: Write the failing test**

Append to `test/test_orders.jl`:

```julia
@testset "orders: submit_multileg_order body shape" begin
    handler, log = recording_handler() do _req
        return json_response(200, _MLEG_PAYLOAD)
    end

    legs = [
        OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
        OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
    ]

    with_mock(handler) do client
        o = submit_multileg_order(client, legs;
                                  type = "limit",
                                  limit_price = -2.00,
                                  qty = 1,
                                  client_order_id = "client-mleg-1")
        @test o isa Order
        @test o.order_class == "mleg"
        @test length(o.legs) == 2
    end

    req = log[1]
    @test req.method == "POST"
    @test req.path == "/orders"

    body = JSON3.read(req.body)
    @test body.order_class == "mleg"
    @test body.qty == "1"
    @test body.type == "limit"
    @test body.time_in_force == "day"
    @test body.limit_price == "-2.0"
    @test body.client_order_id == "client-mleg-1"
    @test length(body.legs) == 2

    leg1 = body.legs[1]
    @test leg1.symbol          == "SPY250620P00420000"
    @test leg1.ratio_qty       == "1"
    @test leg1.side            == "sell"
    @test leg1.position_intent == "sell_to_open"

    leg2 = body.legs[2]
    @test leg2.symbol          == "SPY250620P00415000"
    @test leg2.ratio_qty       == "1"
    @test leg2.side            == "buy"
    @test leg2.position_intent == "buy_to_open"
end

@testset "orders: submit_multileg_order market order omits limit_price" begin
    handler, log = recording_handler() do _req
        return json_response(200, _MLEG_PAYLOAD)
    end

    legs = [
        OrderLeg("SPY250620P00420000", 1, "buy",  "buy_to_close"),
        OrderLeg("SPY250620P00415000", 1, "sell", "sell_to_close"),
    ]

    with_mock(handler) do client
        submit_multileg_order(client, legs; type = "market", qty = 2)
    end

    body = JSON3.read(log[1].body)
    @test body.type == "market"
    @test body.qty  == "2"
    @test !haskey(body, :limit_price)
    @test !haskey(body, :client_order_id)
end

@testset "orders: submit_multileg_order rejects bad input before HTTP" begin
    # Handler intentionally returns 500 so any HTTP call would fail loudly;
    # validation should short-circuit before we get there.
    handler = function(_req)
        return plain_response(500, "should not reach server")
    end

    with_mock(handler) do client
        @test_throws ArgumentError submit_multileg_order(
            client,
            [OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open")];
            type = "limit", limit_price = -2.0,
        )

        legs = [
            OrderLeg("SPY250620P00420000", 1, "sell", "sell_to_open"),
            OrderLeg("SPY250620P00415000", 1, "buy",  "buy_to_open"),
        ]
        @test_throws ArgumentError submit_multileg_order(client, legs; type = "limit")
    end
end
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -20`

Expected: `UndefVarError: submit_multileg_order not defined`.

- [ ] **Step 3: Implement `submit_multileg_order`**

Append to `src/orders.jl`:

```julia
"""
    submit_multileg_order(client, legs;
                          type="limit", time_in_force="day",
                          limit_price=nothing, qty=1,
                          client_order_id=nothing,
                          extended_hours=false)

Submit a multi-leg options order (Alpaca `order_class="mleg"`).

- `legs::Vector{OrderLeg}`: 2–4 option legs, all on the same underlying.
- `qty`: number of spread units. Each leg's submitted quantity is
  `qty * leg.ratio_qty`.
- `type`: `"market"` or `"limit"`. For `"limit"`, `limit_price` is the **net
  price for one spread unit** (positive = debit, negative = credit), per
  Alpaca's convention.
- `time_in_force`: `"day"` is the only TIF Alpaca currently accepts for mleg.

Returns the parsed parent [`Order`](@ref) with `legs` populated from Alpaca's
response.

Stock+option combos (covered calls, married puts, collars-with-shares) are
not supported as a single mleg order by Alpaca; submit the equity side via
[`submit_order`](@ref) and the option side via this function.
"""
function submit_multileg_order(client::AlpacaClient,
                                legs::Vector{OrderLeg};
                                type::AbstractString = "limit",
                                time_in_force::AbstractString = "day",
                                limit_price::Union{Real,Nothing} = nothing,
                                qty::Integer = 1,
                                client_order_id::Union{AbstractString,Nothing} = nothing,
                                extended_hours::Bool = false)
    _validate_mleg(legs, type, limit_price)

    body = Dict{String,Any}(
        "order_class"    => "mleg",
        "qty"            => string(qty),
        "type"           => type,
        "time_in_force"  => time_in_force,
        "extended_hours" => extended_hours,
        "legs"           => [
            Dict(
                "symbol"          => l.symbol,
                "ratio_qty"       => string(l.ratio_qty),
                "side"            => l.side,
                "position_intent" => l.position_intent,
            ) for l in legs
        ],
    )
    limit_price     === nothing || (body["limit_price"]     = string(limit_price))
    client_order_id === nothing || (body["client_order_id"] = client_order_id)

    return _parse_order(_trading_post(client, "/orders"; body = body))
end
```

- [ ] **Step 4: Export `submit_multileg_order`**

In `src/Alpaca.jl`, find the line:

```julia
export submit_order, list_orders, get_order, cancel_order, cancel_all_orders
```

Replace with:

```julia
export submit_order, submit_multileg_order,
       list_orders, get_order, cancel_order, cancel_all_orders
```

- [ ] **Step 5: Run the tests to confirm pass**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: full suite green, including the three new mleg testsets.

- [ ] **Step 6: Commit**

```bash
git add src/orders.jl src/Alpaca.jl test/test_orders.jl
git commit -m "Add submit_multileg_order for Alpaca mleg option spreads

Posts order_class=mleg with a legs array to /v2/orders. Net limit_price
follows Alpaca's debit-positive / credit-negative convention. Validates
legs and type/limit_price coherence before the HTTP round-trip."
```

---

## Task 5: `list_orders` round-trip with an mleg parent

Confirm the existing `list_orders` works with mleg parents in the response — pure parsing test, no SDK changes needed. This guards the parser against regressions when Alpaca returns mixed simple + mleg parents in a list response.

**Files:**
- Test: `test/test_orders.jl` (one testset)

- [ ] **Step 1: Write the test**

Append to `test/test_orders.jl`:

```julia
@testset "orders: list_orders returns mleg parent with child legs" begin
    handler, log = recording_handler() do req
        uri = HTTP.URI(req.target)
        if req.method == "GET" && uri.path == "/orders"
            return json_response(200, [_ORDER_PAYLOAD, _MLEG_PAYLOAD])
        end
        return plain_response(404, "not mocked")
    end

    with_mock(handler) do client
        orders = list_orders(client; status = "open")
        @test length(orders) == 2

        simple = orders[1]
        @test simple.symbol == "AAPL"
        @test simple.order_class == ""
        @test simple.legs === nothing

        mleg = orders[2]
        @test mleg.order_class == "mleg"
        @test mleg.symbol === nothing
        @test mleg.legs !== nothing
        @test length(mleg.legs) == 2
        @test mleg.legs[1].symbol == "SPY250620P00420000"
    end

    @test occursin("status=open", log[1].query)
end
```

- [ ] **Step 2: Run to confirm it already passes (no implementation needed)**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: green. The parser changes from Task 1 already handle this; this test pins the behavior so future refactors can't quietly break the list path.

- [ ] **Step 3: Commit**

```bash
git add test/test_orders.jl
git commit -m "Pin list_orders behavior when responses mix simple and mleg parents"
```

---

## Task 6: Integration smoke tests (gated)

Live tests against Alpaca paper. Gated by `ALPACA_LIVE_TESTS=1` like the existing integration tests so CI without credentials still passes.

**Files:**
- Modify: `test/test_integration.jl`

- [ ] **Step 1: Replace the `if _LIVE` block in `test/test_integration.jl` with the version below**

The existing file is a single `if _LIVE ... else ... end` around one testset. Replace the entire block so it contains both the original `integration (live paper API)` testset and the new `integration: multi-leg options (live paper API)` testset, with the same `else` branch unchanged. Result:

```julia
if _LIVE
    @testset "integration (live paper API)" begin
        creds_path = get(ENV, "ALPACA_CREDS", joinpath(dirname(@__DIR__), "conf", "apiidata.toml"))
        @test isfile(creds_path)

        client = load_client(creds_path)
        acct = get_account(client)
        @test acct.status == "ACTIVE"
        @test acct.currency == "USD"
        @test acct.cash >= 0

        clk = get_clock(client)
        @test clk isa MarketClock

        q = get_latest_quote(client, "AAPL")
        @test q.symbol == "AAPL"
        @test q.bid_price > 0 || q.ask_price > 0
    end

    @testset "integration: multi-leg options (live paper API)" begin
        creds_path = get(ENV, "ALPACA_CREDS",
                         joinpath(dirname(@__DIR__), "conf", "apiidata.toml"))
        client = load_client(creds_path)

        # Find the nearest monthly expiry 30-45 DTE out.
        today  = Date(get_clock(client).timestamp)
        window_start = today + Day(30)
        window_end   = today + Day(45)

        chain = get_option_chain_snapshot(client, "SPY";
                                          type = "put",
                                          expiration_date_gte = window_start,
                                          expiration_date_lte = window_end,
                                          limit = 1000)

        @test !isempty(chain) "expected at least one SPY put in the 30-45 DTE window"

        # Group snapshots by expiry date parsed out of the OCC symbol
        # (positions 5:10 of an OCC symbol are YYMMDD after the root).
        function _occ_expiry(sym::AbstractString, root::AbstractString = "SPY")
            yymmdd = sym[length(root)+1 : length(root)+6]
            return Date("20" * yymmdd, dateformat"yyyymmdd")
        end

        by_exp = Dict{Date,Vector{OptionSnapshot}}()
        for (sym, snap) in chain
            d = _occ_expiry(sym)
            push!(get!(by_exp, d, OptionSnapshot[]), snap)
        end
        nearest_exp = minimum(keys(by_exp))
        puts_on_exp = by_exp[nearest_exp]

        # Short leg: closest |delta| to 0.30.
        scored = [(snap, abs(snap.greeks === nothing ? 1.0 :
                             (snap.greeks.delta === nothing ? 1.0 : snap.greeks.delta) + 0.30))
                  for snap in puts_on_exp if snap.greeks !== nothing && snap.greeks.delta !== nothing]
        @test !isempty(scored) "expected at least one put with delta available"
        sort!(scored, by = x -> x[2])
        short_snap = scored[1][1]
        # Long leg: $5 OTM further (lower strike for a put).
        # Look up short strike from its OCC symbol (last 8 digits / 1000).
        function _occ_strike(sym::AbstractString)
            return parse(Int, sym[end-7:end]) / 1000
        end
        short_strike = _occ_strike(short_snap.symbol)
        long_target  = short_strike - 5.0
        long_snap = argmin(s -> abs(_occ_strike(s.symbol) - long_target), puts_on_exp)

        @info "smoke test selections" short = short_snap.symbol long = long_snap.symbol

        # --- Smoke 1: open & cancel a far-from-market spread ---
        legs = [
            OrderLeg(short_snap.symbol, 1, "sell", "sell_to_open"),
            OrderLeg(long_snap.symbol,  1, "buy",  "buy_to_open"),
        ]
        # Wildly-low credit so it won't fill.
        parent = submit_multileg_order(client, legs;
                                       type = "limit",
                                       limit_price = -0.01,
                                       qty = 1)
        @test parent.order_class == "mleg"
        @test parent.legs !== nothing
        @test length(parent.legs) == 2

        cancel_order(client, parent.id)
        sleep(2)
        after = get_order(client, parent.id)
        @test after.legs !== nothing
        @test all(l -> l.status in ("canceled", "pending_cancel", "accepted"),
                  after.legs) "all legs should be canceling/canceled, got $(map(l -> l.status, after.legs))"
    end
else
    @info "skipping live integration tests (set ALPACA_LIVE_TESTS=1 to enable)"
end
```

The round-trip-with-fill test is intentionally omitted from this PR — fills on a real paper account depend on market state, time-of-day, and aren't deterministic. The open-and-cancel smoke covers the request/response wire path, which is what we actually need to verify in CI-ish conditions. A separate manual smoke run (documented in `examples/` later) can exercise the full fill cycle.

- [ ] **Step 2: Locally verify the smoke runs (only if you have paper creds)**

Run: `ALPACA_LIVE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -60`

Expected: both integration testsets pass against your paper account. If you don't have creds set up, skip — CI without `ALPACA_LIVE_TESTS=1` will not execute these.

- [ ] **Step 3: Confirm the unit suite is still green without the env var**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: green, with the `@info` line "skipping live integration tests" present.

- [ ] **Step 4: Commit**

```bash
git add test/test_integration.jl
git commit -m "Add gated paper-API smoke test for mleg open & cancel"
```

---

## Task 7: Bump version and update README features table

Documents the new function in the surfaced features list and bumps the version since `Order`'s shape changed.

**Files:**
- Modify: `Project.toml`
- Modify: `README.md` (Features table)

- [ ] **Step 1: Bump version**

In `Project.toml`, change:

```toml
version = "0.2.0"
```

to:

```toml
version = "0.3.0"
```

- [ ] **Step 2: Update the Features table in `README.md`**

Find the row:

```markdown
| **Orders** | `submit_order`, `list_orders`, `get_order`, `cancel_order`, `cancel_all_orders` |
```

Replace with:

```markdown
| **Orders** | `submit_order`, `submit_multileg_order`, `list_orders`, `get_order`, `cancel_order`, `cancel_all_orders` |
```

- [ ] **Step 3: Run the suite once more to make sure nothing else slipped**

Run: `julia --project=. -e 'using Pkg; Pkg.test()' 2>&1 | tail -10`

Expected: green.

- [ ] **Step 4: Commit**

```bash
git add Project.toml README.md
git commit -m "Bump to 0.3.0 and document submit_multileg_order in README

Order struct shape changed (symbol/side now nullable; new order_class,
position_intent, legs fields), so this is a minor-version bump
under pre-1.0 semver."
```

---

## Verification checklist

After all tasks land:

- [ ] `julia --project=. -e 'using Pkg; Pkg.test()'` is green
- [ ] `git log --oneline` shows seven new commits with the messages above
- [ ] `julia --project=. -e 'using Alpaca; println(names(Alpaca))'` includes `OrderLeg` and `submit_multileg_order`
- [ ] Manual sanity: construct an `OrderLeg`, call `submit_multileg_order` with a deliberately bad arg, see an `ArgumentError`
- [ ] If paper credentials available: `ALPACA_LIVE_TESTS=1 julia --project=. -e 'using Pkg; Pkg.test()'` also green
