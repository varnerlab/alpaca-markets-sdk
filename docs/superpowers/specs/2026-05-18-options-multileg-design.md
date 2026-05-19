# Multi-leg options orders in `Alpaca.jl`

**Status:** design / approved scope. Ready for implementation plan.
**Date:** 2026-05-18
**Parent doc:** `options_buildout.md` §2 (this spec narrows that section to the SDK patch only).

---

## 1. Scope

In scope for this PR:

- New `OrderLeg` input struct.
- New `submit_multileg_order(client, legs; ...)` posting `order_class="mleg"` to `/v2/orders`.
- Extensions to the existing `Order` struct so parent + child legs round-trip through `list_orders` / `get_order` / `submit_multileg_order`.
- Client-side validation of leg-count and enum fields.
- Mock-server unit tests and opt-in paper-account smoke tests.

Out of scope (lives in the downstream strategy repo):

- OSI symbol-builder helper (`(underlying, expiry, strike, right) → OCC string`).
- γ-driven sleeve picker, IV-rank gate, earnings-blackout filter.
- Position lifecycle log, mark-to-market service, exit-rule checker.
- High-level strategy helpers (`submit_vertical_spread`, etc.).
- Stock+option combo *atomicity*. Alpaca's `mleg` is options-only; covered calls / married puts are user-composed via one `submit_order` plus one `submit_multileg_order`. The SDK exposes the wire model honestly, no hidden helper.

---

## 2. Types

### 2.1 New input struct

Added to `src/types.jl`:

```julia
struct OrderLeg
    symbol::String           # OCC option symbol (e.g. "AAPL250620P00200000")
    ratio_qty::Int           # contracts per spread unit (typically 1)
    side::String             # "buy" | "sell"
    position_intent::String  # "buy_to_open" | "sell_to_open" | "buy_to_close" | "sell_to_close"
end
```

Input-only. Responses use the extended `Order` struct (§2.2).

### 2.2 Extensions to `Order`

Three new fields and two nullability changes:

```julia
struct Order
    id::String
    client_order_id::String
    symbol::Union{String,Nothing}            # CHANGED: was String; mleg parent has no top-level symbol
    asset_class::String
    side::Union{String,Nothing}              # CHANGED: was String; mleg parent has no top-level side
    type::String
    time_in_force::String
    order_class::String                      # NEW: "" | "mleg" | "bracket" | "oco" | "oto"
    position_intent::Union{String,Nothing}   # NEW: populated on leg children, nothing on parents
    qty::Union{Float64,Nothing}
    filled_qty::Float64
    limit_price::Union{Float64,Nothing}
    stop_price::Union{Float64,Nothing}
    filled_avg_price::Union{Float64,Nothing}
    status::String
    created_at::Union{DateTime,Nothing}
    submitted_at::Union{DateTime,Nothing}
    filled_at::Union{DateTime,Nothing}
    legs::Union{Vector{Order},Nothing}       # NEW: nested child legs; nothing for single-leg orders
    raw::JSON3.Object
end
```

**Why these changes are necessary:** parsing an mleg parent into the current `Order` crashes on `String(o.symbol)` because Alpaca omits the top-level `symbol` and `side` on parent orders. The new fields surface mleg-specific data (`order_class`, `position_intent`, child `legs`) without forcing consumers to dig into the `raw` payload.

**Backward compatibility:** single-leg orders parse identically to today, just with `order_class=""`, `position_intent=nothing`, `legs=nothing`. Existing consumers that read `o.symbol::String` will need to handle `Nothing` if they ever inspect an mleg parent; the docstring change calls this out.

### 2.3 Exports

Add `OrderLeg` to the type exports in `src/Alpaca.jl`. Add `submit_multileg_order` to the order exports.

---

## 3. `submit_multileg_order`

Added to `src/orders.jl`:

```julia
"""
    submit_multileg_order(client, legs;
                          type="limit", time_in_force="day",
                          limit_price=nothing, qty=1,
                          client_order_id=nothing,
                          extended_hours=false)

Submit a multi-leg options order (Alpaca `order_class="mleg"`).

- `legs::Vector{OrderLeg}`: 2–4 option legs, all on the same underlying.
- `qty`: number of spread units. Each leg's submitted quantity is `qty * leg.ratio_qty`.
- `type`: "market" or "limit". For "limit", `limit_price` is the **net price for one
  spread unit** (positive = debit, negative = credit), per Alpaca's convention.
- `time_in_force`: "day" is the only TIF Alpaca accepts for mleg today.

Returns the parsed parent `Order` with `legs` populated by Alpaca's response.
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

Design choices:

1. **Top-level `qty` for spread count, per-leg `ratio_qty` for shape.** Matches Alpaca's wire format. Lets `qty=5` mean "open 5 verticals" without the user multiplying.
2. **`limit_price` is net.** Alpaca takes a single net price on mleg, not per-leg. Signed: positive = debit, negative = credit. Docstring is explicit because this is the most common mistake.
3. **No `order_class` keyword.** The function always sets `mleg`. Other classes (`bracket`, `oco`, `oto`) are separate concerns — adding a generic switch invites misuse.

`list_orders` / `get_order` / `cancel_order` work unchanged. Their parsed results just gain `order_class` and `legs` fields when the underlying order is multi-leg.

---

## 4. Validation

Philosophy: **shape & enum checks client-side, semantic validation server-side.** Alpaca returns clear errors for spread structure problems; replicating that logic in the SDK is fragile and ages badly.

Private helper added to `src/orders.jl`:

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

**Deliberately not validated client-side:**

| Check | Reason |
|---|---|
| Same underlying across legs | Requires parsing OCC root; format has changed historically (e.g., split-adjusted symbols). Alpaca rejects with a clear message. |
| Same / different expiry across legs | Calendar and diagonal spreads use different expiries; an over-strict check forbids legitimate strategies. |
| Spread shape (vertical / condor / butterfly) | Not the SDK's job. |
| Contract tradability or existence | Broker decides. |
| Mixing equity and option symbols | mleg is options-only by Alpaca's design; mixing rejects server-side. |

---

## 5. Response parsing

`_parse_order` in `src/orders.jl` is updated to:

1. Tolerate missing `symbol` and `side` on mleg parents.
2. Read `order_class` (defaulting to `""`).
3. Read `position_intent` (defaulting to `nothing`).
4. Recursively parse `legs` into nested `Order` values.

```julia
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

_maybe_string(x) = x === nothing ? nothing : String(x)

function _parse_legs(v)
    v === nothing && return nothing
    isempty(v)    && return nothing
    return [_parse_order(leg) for leg in v]
end
```

Simple equity orders are unchanged in behavior: no `legs` key means `legs=nothing`, no `order_class` means `""`, no `position_intent` means `nothing`. Child legs get their per-leg `id`, `filled_qty`, `filled_avg_price`, `status`, and `position_intent` populated — everything downstream tooling needs for fill attribution.

---

## 6. Tests

### 6.1 Unit tests (extend `test/test_orders.jl`)

Use the existing `mock_server.jl` / `recording_handler` pattern. New `@testset` blocks:

| Test | Assertion |
|---|---|
| `submit_multileg_order` posts correct body | `order_class == "mleg"`, top-level `qty` serialized as string, `legs` is a JSON array, each leg has the four expected keys with string values, `limit_price` serialized as string |
| Leg count validation | `ArgumentError` for `length(legs) == 1` and `length(legs) == 5` |
| Enum validation | `ArgumentError` per case: bad `side`, bad `position_intent`, empty `symbol`, `ratio_qty < 1` |
| Limit without price | `ArgumentError` for `type="limit"` and `limit_price=nothing` |
| Parsing: mleg parent with two legs | `parent.order_class == "mleg"`, `parent.symbol === nothing`, `parent.side === nothing`, `length(parent.legs) == 2`, each child has populated `position_intent`, `symbol`, `side`, `filled_qty` |
| Parsing: simple equity regression | Existing `_ORDER_PAYLOAD`-based tests still pass; `order_class == ""`, `legs === nothing`, `position_intent === nothing` |
| `list_orders` returns mleg parent | An `Order` in the parsed array carries a populated `Vector{Order}` in `.legs` |

A new mleg JSON fixture is added inline alongside the existing `_ORDER_PAYLOAD` constant (matches current style in `test_orders.jl`).

### 6.2 Integration smoke tests (extend `test/test_integration.jl`)

Gated by the same credential-presence check the existing integration tests use; skipped in CI without keys.

| Smoke test | Scenario |
|---|---|
| Open & cancel a vertical | Submit a far-from-market 2-leg SPY put spread that won't fill, `cancel_order` on the parent, confirm both child legs report `status == "canceled"` via `get_order`. |
| Round-trip a bull put credit spread | Pick nearest 30–45 DTE expiry on SPY, ~−0.30 delta short put, $5 wider long put (strikes resolved via `get_option_chain_snapshot`); submit, poll `get_order` until both legs `filled`; submit closing mleg with intents flipped to `buy_to_close` / `sell_to_close`; confirm flat in `list_positions`. |
| Parent + legs visible | After fill, `get_order(parent_id)` returns parent with populated `legs`, and the per-leg `id` from the parent matches a `get_order(leg_id)` round-trip. |

Strike selection uses `get_option_chain_snapshot` (already in the SDK) filtered by expiry and `type="put"`, picking the strike whose `greeks.delta` is closest to −0.30. No new helpers introduced for the smoke tests.

---

## 7. File-by-file impact

| File | Change |
|---|---|
| `src/types.jl` | Add `OrderLeg`. Modify `Order`: nullability on `symbol`/`side`; new `order_class`, `position_intent`, `legs` fields. Update docstrings. |
| `src/orders.jl` | Add `submit_multileg_order`, `_validate_mleg`, `_MLEG_*` constants. Update `_parse_order`. Add `_maybe_string`, `_parse_legs`. |
| `src/Alpaca.jl` | Export `OrderLeg`, `submit_multileg_order`. |
| `test/test_orders.jl` | New `@testset` blocks per §6.1. Add mleg fixture payload. |
| `test/test_integration.jl` | New smoke tests per §6.2. |
| `docs/src/...` (if Documenter docs reference order fields) | Update affected pages to mention new fields. Verified during implementation. |

Expected diff size: ~150–250 LOC plus tests, consistent with the `options_buildout.md` §2.4 estimate.

---

## 8. Risks and follow-ups

- **Breaking-shape change on `Order.symbol` / `Order.side`.** Anything that does `String(o.symbol)` or pattern-matches on `o.side::String` will need a `Union{String,Nothing}` update. Search-and-fix is part of the implementation; the SDK's own callers are the only known consumers.
- **Alpaca's mleg endpoint is still flagged "options-trading" beta in their docs.** If they rev the request shape, the body builder and parser are the only two places to update.
- **No OSI symbology helper.** Out of scope for this PR. Downstream strategy code resolves OSI strings via `list_option_contracts` or `get_option_chain_snapshot` until a dedicated helper is decided on.
- **Versioning.** This PR bumps `Project.toml` to `0.3.0` because of the `Order` struct shape change (semver-minor pre-1.0, but breaking for any direct field access).

---

## 9. Out of scope (for this PR)

- OSI symbol builder helper.
- Strategy / sleeve / γ logic.
- Position lifecycle log, MTM service, exit-rule checker.
- `submit_vertical_spread` / `submit_iron_condor` / other named-shape helpers.
- Bracket, OCO, OTO compound orders. Only `mleg` is added.
- Atomic stock+option combo helpers (covered call, married put). Composed by the user from `submit_order` + `submit_multileg_order`.
