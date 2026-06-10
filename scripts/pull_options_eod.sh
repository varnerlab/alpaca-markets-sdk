#!/bin/bash
#
# pull_options_eod.sh — End-of-day options ladder pull for the 31 canonical
# tickers used by the per-ticker NN IV model (see needed_data.md).
#
# Invoked by cron at 16:30 ET on weekdays (see setup_cron.sh). Bails on
# market holidays via Alpaca's /calendar endpoint. One CSV per ticker
# lands in data/options-MM-DD-YY/, full run log in logs/options-MM-DD-YY.log.
#
# Run by hand:
#   ./scripts/pull_options_eod.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT" || exit 1

DATE_TAG=$(date +%m-%d-%y)
LOG="logs/options-${DATE_TAG}.log"
mkdir -p logs

# Cron strips PATH to `/usr/bin:/bin`, so `which julia` returns nothing.
# Prepend juliaup's bin dir before resolving. ALPACA_JULIA_BIN overrides
# (used by the masking-bug verification in the 2026-06-10 fix).
export PATH="$HOME/.juliaup/bin:$PATH"
JULIA="${ALPACA_JULIA_BIN:-$(which julia)}"
if [ -z "$JULIA" ]; then
    echo "[$(date)] error: julia not in PATH" | tee -a "$LOG"
    exit 1
fi

echo "=== pull start $(date) ===" | tee -a "$LOG"

# Preflight: bail cleanly on non-trading days (weekends are already
# excluded by the cron mask, but holidays still slip through).
#
# A julia CRASH is NOT a holiday. Only the check's explicit "[skip]" marker
# may skip the pull; any other non-zero exit aborts LOUDLY (exit 1) so cron
# surfaces it. The old `if ! julia ...` form treated TCC init-crashes as
# non-trading days and silently dropped 06-05→06-10 2026 (4 sessions).
CHECK_OUT="$("$JULIA" --project=. scripts/check_trading_day.jl 2>&1)"
CHECK_RC=$?
printf '%s\n' "$CHECK_OUT" >> "$LOG"
if [ "$CHECK_RC" -ne 0 ]; then
    if printf '%s\n' "$CHECK_OUT" | grep -q '^\[skip\]'; then
        echo "=== pull skipped (non-trading day) $(date) ===" | tee -a "$LOG"
        exit 0
    fi
    echo "=== pull ABORTED: trading-day check died rc=$CHECK_RC — not a holiday verdict $(date) ===" | tee -a "$LOG"
    exit 1
fi

TICKERS=(
    AAPL AMD AVGO GOOG INTC META MSFT MU NVDA QCOM
    ABBV AMGN BMY JNJ LLY MRNA PFE UNH
    BAC GS JPM WFC
    CVX OXY XOM
    TGT UPS WMT
    IWM QQQ SPY
)

failed=()
for t in "${TICKERS[@]}"; do
    echo "--- $t $(date +%H:%M:%S) ---" >> "$LOG"
    if ALPACA_UNDERLYING="$t" "$JULIA" --project=. examples/download_options_dte_ladder.jl >> "$LOG" 2>&1; then
        echo "  ok" >> "$LOG"
    else
        echo "  FAILED" >> "$LOG"
        failed+=("$t")
    fi
done

n_csv=$(ls "data/options-${DATE_TAG}/" 2>/dev/null | wc -l | tr -d ' ')
echo "=== pull done $(date) | csv_count=$n_csv | failures=${#failed[@]} ===" | tee -a "$LOG"
if [ ${#failed[@]} -gt 0 ]; then
    echo "failed: ${failed[*]}" | tee -a "$LOG"
    exit 1
fi
