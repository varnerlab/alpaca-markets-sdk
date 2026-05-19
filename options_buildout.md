# Options Buildout: SDK + Simple Paper-Trade Exercise

**Status:** brainstorm / design doc. Not yet implemented.
**Date:** 2026-05-17
**Sibling doc:** `constrained_cobb_douglas.md` (parallel stock-allocator track that this options exercise will eventually merge with).

---

## TL;DR

Build the multi-leg order capability into `varnerlab/alpaca-markets-sdk` and run a small paper-trade exercise: vertical credit spreads (bull put on high-γ names, bear call on low-γ names) sized off the same γ vector that the stock track will use. **No simulation.** Hand-picked names from the bandit-selected basket, gated by liquidity / earnings calendar / IV rank. Event-driven entry and exit only — no clock-driven cadence. Goal is to validate the operational pipeline (order submission, lifecycle tracking, P&L attribution) and the strategy logic together, in the cheapest way that touches real options data.

---

## 1. Track scope: why options is a parallel track now

The constrained-CD MPC stock track and the options buildout are **independent dependencies** of the eventual combined strategy. Doing them in parallel:

- **Decouples failure modes.** The stock strategy can fail because the constrained-CD MPC backtest comes out unfavorable; the options track can fail because the SDK patch is harder than estimated or because the chosen spread structure doesn't survive real fills. Either failure leaves the other track usable.
- **Avoids compounding two unknowns.** Trying to simulate options + a new allocator + an unproven MPC discipline simultaneously is what the original `long_short_portfolio.md` proposed, and it was too much to ship in a single phase.
- **Reflects the actual learning need.** We don't yet know what real spread fills look like on the broker, or how the operational tooling behaves with multi-leg orders. The cheapest way to learn that is to actually trade spreads, not to simulate them.

**Out of scope for this track:** the full Phase-A heston-driven backtest of credit-spread overlays. That research artifact remains valuable but is not required for the next step. The first paper trade is small, defensible by simple rules, and chosen to be educational.

---

## 2. SDK buildout: multi-leg orders in `varnerlab/alpaca-markets-sdk`

### 2.1 Current state

The SDK supports single-leg equity orders via `submit_order(client, symbol, qty, side; type, time_in_force)`. There is no multi-leg / spread support. Alpaca's REST API supports multi-leg orders via a `legs::Array` field on the order body; the SDK does not surface this.

### 2.2 The patch

Two new types and one new function:

```julia
struct OrderLeg
    symbol::String           # OSI option symbol (or underlying for stock leg)
    ratio_qty::Int           # contracts per spread (typically 1)
    side::String             # "buy" or "sell"
    position_intent::String  # "buy_to_open", "sell_to_open", "buy_to_close", "sell_to_close"
end
```

Extend the existing `Order` struct with `legs::Union{Vector{OrderLeg}, Nothing}`.

```julia
function submit_spread_order(client, legs::Vector{OrderLeg};
                              order_class::String = "mleg",
                              type::String = "limit",
                              time_in_force::String = "day",
                              limit_price::Union{Float64, Nothing} = nothing)
    # POST /v2/orders with body containing the legs array.
    # Validates: even number of legs (typically 2 for verticals), all same expiry,
    # all same underlying.
end
```

### 2.3 Tests

- Smoke test against Alpaca paper: open a 1-contract bull put spread on SPY at the closest 30Δ / 45 DTE pair, close it the next session, confirm both legs filled and the net premium tracks the spread's mid quote.
- Cancel-before-fill test: submit at a far-from-market limit price, cancel, confirm both legs canceled together.
- Multi-leg query test: confirm `list_orders` returns the spread as a parent order with leg children populated.

### 2.4 Scope estimate

50-150 LOC plus tests. The PR target is `varnerlab/alpaca-markets-sdk` upstream once green. The new repo for this strategy work depends on the SDK at a pinned commit / tag once the patch lands.

### 2.5 Operational tooling that lives alongside the SDK

- **Position lifecycle log.** Each spread is a single logical position: open date, entry credit, current mark, exit reason, exit P&L. Persisted as JLD2 per-trade and aggregated daily.
- **Mark-to-market service.** On a daily cadence (not 30-min), pull the spread's current mid from Alpaca's option snapshot endpoint and write to the lifecycle log.
- **Exit-rule checker.** Runs once per market open on the daily cadence; evaluates each open spread against §6's exit rules and submits closing orders if triggered.

---

## 3. Strategy: simple γ-driven vertical credit spreads

### 3.1 The two-sleeve structure

| Bucket | γ condition | Sleeve | Direction |
|---|---|---|---|
| High-γ | γ ≥ τ_high | Bull put credit spread | Long-delta, short-vega, theta-positive |
| Low-γ | γ ≤ τ_low | Bear call credit spread | Short-delta, short-vega, theta-positive |
| Mid-γ | τ_low < γ < τ_high | Skip | (no spread on this name this cycle) |

Defaults: `τ_high = +0.5`, `τ_low = −0.3`. The asymmetry is intentional: selling premium on a fading name is more dangerous than on a strengthening one (the existing rationale in `long_short_portfolio.md` §2 holds).

### 3.2 Spread mechanics

| Parameter | Default | Notes |
|---|---|---|
| Short-leg target delta | 30Δ | Bull put: short put at 30Δ; bear call: short call at 30Δ |
| Width (long leg) | 5% of spot | Risk lever; narrower = lower max-loss, lower credit |
| DTE at entry | 30-45 days | Far enough to harvest theta, near enough to skip earnings blackout most cycles |
| Position size | per §3.3 | Sized by max-loss budget |

### 3.3 Sizing rule

Per-spread max loss = `(width × 100) − (credit × 100)` per contract. Cap each spread's max-loss at **0.5% of total account equity**. With $100K paper account and a typical $5 width / $2 credit spread, max-loss is $300/contract → 1 contract per spread is well under cap.

Aggregate per-name notional cap: **5% of equity**. Aggregate option-sleeve max-loss cap: **10% of equity**.

These caps come straight from `long_short_portfolio.md` §4 and are not re-derived here.

---

## 4. Name picking and gating

### 4.1 Filter stack (applied in order)

1. **Universe restriction.** Names must be in the 22-ticker bandit-selected basket from `constrained_cobb_douglas.md` §5. No options on names outside this basket.
2. **γ bucketing.** §3.1: high-γ → bull put candidate, low-γ → bear call candidate, mid-γ → skip.
3. **Liquidity filter.**
   - Short-leg open interest ≥ 100 contracts.
   - Short-leg bid-ask spread ≤ 10% of mid.
   - Daily option volume > 0 on the target expiration.
4. **Earnings blackout.** Skip if the name's next earnings print falls inside the contract life. Use the earnings calendar already maintained in the `heston_implied_volatility_model` repo and the live `eCornell-AI-finance-lectures/data/news` artifacts.
5. **IV rank gate.** Compute IV rank = `(IV_current − IV_min_52w) / (IV_max_52w − IV_min_52w)`. Open new spreads only when `IVR ≥ 30`. Short premium in a low-IV regime pays too little to clear cost; this is the §6 vol-regime gate in `long_short_portfolio.md` made concrete.
6. **Sector concentration cap.** At most `k = 3` open spreads per GICS sector at any time. Prevents the option sleeve from accidentally amplifying a sector concentration the stock sleeve already has.

### 4.2 The first paper-trade exercise

Tighter universe than the full 22. For the very first run:

- **Sub-universe of 10 names** from the bandit basket: top-5 by γ + bottom-5 by γ at the time of the first cycle. (For the first cycle only, to keep the position count small and the operational learning curve manageable.)
- **One vertical spread per name per monthly cycle**, opened on the first market open after a new monthly expiration is selected.
- **No re-entry on a name until the prior spread is closed.** This is the simplest possible discipline that avoids the live engine's failure mode.

Scale to the full 22-name universe once the operational pipeline is proven.

### 4.3 What γ comes from in this exercise

In Phase 1 (this doc, before the stock-track merger), γ is computed on-demand from a fresh SIM fit on the trailing window. The same `compute_preference_weights` function from the lectures repo, no news, run once per monthly cycle. The γ from the stock-track MPC will not be used here yet; that's the convergence step.

---

## 5. Position management: event-driven exits only

**No clock-driven re-evaluation.** Each open spread has four exit conditions:

| Trigger | Rule | Rationale |
|---|---|---|
| Profit-take | Close at 50% of max profit | tastytrade convention; closes early to avoid the late-life gamma risk |
| Time stop | Close at 21 DTE | Inside 3 weeks, gamma risk accelerates |
| Loss stop | Close if mark-to-market loss ≥ 2× entry credit | Caps downside before max-loss is reached |
| Signal stop | Close if γ_i crosses back across entry threshold by more than `δ = 0.10` (hysteresis) | The original thesis went away |

**These conditions are checked once per trading day at market open** by the operational tooling from §2.5. No 30-min cadence. Spreads sit untouched between daily checks.

### 5.1 Roll policy

Initial version: **do not roll.** Close per the rules above and re-evaluate at the next monthly cycle. Future enhancement: roll same-strike to the next monthly if signal still aligned and current spread within profit target.

### 5.2 Assignment management

Skip the 5-DTE window by hard rule (close all spreads with `DTE ≤ 5`). On a paper account assignment behavior is broker-specific and not the learning target of this exercise. The 21-DTE time stop from the table above means most spreads close well before this becomes a concern.

---

## 6. Paper-trade exercise design

### 6.1 What gets measured

Every spread, from open to close:

- **Entry record:** date, ticker, sleeve (bull put / bear call), short-leg strike, long-leg strike, expiry, contracts, entry credit per share, entry credit total.
- **Daily mark:** spread mid each market open.
- **Exit record:** date, exit reason, exit cost per share, realized P&L, holding period, lots created (each leg open + close = one tax lot per leg per spread).
- **Engine snapshot at entry:** γ_i, IV rank, market regime tag.

Daily aggregates: net premium received, mark-to-market unrealized, sleeve-attributed Greeks (sum of position deltas, position vegas, position thetas).

### 6.2 Success criteria for the exercise

This is **not a backtest equivalent**. The exercise validates:

1. **Operational pipeline.** Multi-leg orders submit and fill correctly. Lifecycle tracking is faithful. Mark-to-market is accurate.
2. **Strategy logic.** The filter stack and the exit rules produce a sane number of spreads (target: 4-10 open at any time given the 10-name first-cycle universe), holding periods cluster around 21-30 days, and the win/loss profile resembles the canonical short-premium shape (high win rate, tail-loss asymmetry).
3. **Cost reality.** Real fills tell us what the bid-ask half-spread on actual option chains actually costs us, which the simulated half-spread in any future backtest will need to match.

Numerical P&L over the exercise window is interesting but not the primary criterion. A two-month exercise on a 10-name universe with one spread per name per month is ~20 spreads — far too few for statistical inference on edge. The win/loss distribution shape and the operational behavior are what we're checking.

### 6.3 Exercise duration

Default 8 weeks (two full monthly cycles) starting after the SDK patch lands. Extend if anything breaks operationally.

---

## 7. Convergence with `constrained_cobb_douglas.md`

When both tracks are independently validated:

- The 22-name bandit basket from §5 of the stock doc is shared.
- The γ vector at any time is computed once and consumed by both sleeves: stock allocation in the stock track, sleeve assignment + sleeve sizing in the options track.
- Capital is split: `w_stock ≈ 0.65`, `w_premium ≈ 0.30`, cash buffer `≈ 0.05`. Adjustable per client.
- The MPC trigger from the stock track also informs the options track: when the portfolio band breaks and stock allocation re-fires, the options sleeve is asked whether any open spread is now misaligned with the new γ. Closures (not openings) on the options sleeve can be triggered by the stock-track MPC; new openings remain on the monthly-cycle cadence.

The merged system is described in `long_short_portfolio.md`. This doc and `constrained_cobb_douglas.md` are the prerequisite tracks.

---

## 8. Open questions

1. **OSI option symbology lookup.** Alpaca's option-symbol format is OSI (`AAPL250620C00200000`). The SDK patch needs a helper that, given `(underlying, expiry, strike, right)`, returns the OSI string. Out-of-scope for the SDK patch itself but required infrastructure. Probably 30-line utility.
2. **Strike-by-delta resolution.** The strategy specifies "30Δ short leg." Two ways to resolve:
   (a) Query Alpaca's option snapshot endpoint for the chain and pick the strike whose listed delta is closest to 30Δ.
   (b) Compute delta locally with a BS pricer using the chain's implied vol and pick.
   (a) is operationally simpler and uses the broker's canonical numbers; default to (a) unless the snapshot endpoint is too slow or rate-limited.
3. **IV-rank historical data.** Computing 52-week IV percentile needs a year of historical IV at the target moneyness. Source: either backfill from the heston repo's ladder corpus (limited to its captured names + dates) or pay for a data feed. Document the source; the gate is only as good as the history.
4. **Earnings calendar source.** The lectures repo and the heston repo both consume a Yahoo Finance earnings calendar. Pin this dependency and document the lag (earnings calendars are usually 1-2 days stale).
5. **What happens when a name leaves the bandit basket between exercise cycles.** v1 default: positions opened on a name continue to be managed through their natural exit even if the name leaves the basket. New positions are not opened on a name not in the current basket. Revisit if the basket changes during a paper-trade window (which it shouldn't, since we're freezing the bandit for v1).
6. **Tax treatment of vertical spreads.** Each leg is a separate tax lot. Short-leg buy-to-close generates a closing trade; long-leg sell-to-close generates another. Holding period is the leg's holding period (typically equal for both legs of a vertical), almost always < 365 days → short-term gain/loss. **The options sleeve generates short-term gains by construction; the stock sleeve is where LTCG efficiency lives.**

---

## 9. Out of scope (for this doc)

- Phase-A heston-driven backtest of credit-spread overlays. Possibly revisited later; not blocking.
- Live (non-paper) options trading. Real capital follows successful paper-trade validation.
- Iron condors, butterflies, calendars, ratio spreads. Vertical credit spreads only in v1.
- Roll-the-spread tactics. Initial version closes; rolls are a future enhancement.
- Tax-loss-harvesting tactics across the option sleeve.
- Wash-sale rule modeling (consistent with `constrained_cobb_douglas.md` §6.5).
- Options on indices or futures. U.S. listed equity options only.

---

## 10. References

**Spread mechanics**
- McMillan, L. G. *Options as a Strategic Investment*. Penguin. — Encyclopedia of spread structures.
- Natenberg, S. *Option Volatility and Pricing*. McGraw-Hill. — IV surface, delta-based strike selection.
- Hull, J. C. *Options, Futures, and Other Derivatives*. Pearson. — Pricing theory baseline.

**Management heuristics**
- tastylive research on managing winners (close at 50% profit, 21-DTE exit). Validate independently; don't take as authoritative.

**Infrastructure**
- Alpaca multi-leg order docs: `https://docs.alpaca.markets/docs/options-trading` (verify current URL).
- `varnerlab/alpaca-markets-sdk` — patch target for §2.
- `varnerlab/heston_implied_volatility_model` — IV-rank historical data source candidate, earnings calendar.

**Parent doc**
- `long_short_portfolio.md` (this repo) — the combined long-short strategy this exercise eventually merges into.
- `constrained_cobb_douglas.md` (this repo) — sibling stock-allocator track.

---

## Appendix: Disclaimer

This document is a design proposal for a paper-trading exercise as a stepping stone to a real-money strategy. Credit spreads carry defined but real risk; assignment, early exercise, dividend, and liquidity risks all apply on real accounts. Paper-trading does not replicate live execution slippage perfectly and should not be the sole basis for sizing real capital. The author is not a licensed options professional. Readers should consult primary sources and their own risk tolerance.
