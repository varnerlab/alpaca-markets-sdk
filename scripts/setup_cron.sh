#!/bin/bash
#
# setup_cron.sh — Install crontab entry for the EOD options ladder pull.
#
# Installs ONE entry, tagged [ALPACA-OPTIONS]:
#   30 16 * * 1-5  -- 16:30 system-local time, Mon-Fri
#
# Cron does not know about market holidays — the wrapper gates on
# Alpaca's /calendar endpoint and exits cleanly when today is closed.
#
# Prerequisites:
#   1. `which julia` returns a valid path.
#   2. System timezone is America/New_York. Verify with `date` (output
#      ends in EST or EDT). If not:
#        sudo systemsetup -settimezone America/New_York
#   3. conf/apidata.toml contains valid Alpaca API keys (load_client()
#      reads this by default — no env file needed).
#   4. (macOS only) Grant Full Disk Access to /usr/sbin/cron so it can
#      read the repo and write to data/. System Settings -> Privacy &
#      Security -> Full Disk Access -> add /usr/sbin/cron, then reboot.
#      Without this, fires run but log "Operation not permitted".
#
# Usage:
#   chmod +x scripts/setup_cron.sh scripts/pull_options_eod.sh
#   ./scripts/setup_cron.sh
#
# To remove:
#   crontab -l | grep -v '\[ALPACA-OPTIONS\]' | crontab -

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
JULIA="$(which julia)"

if [ -z "$JULIA" ]; then
    echo "Error: julia not in PATH."
    exit 1
fi

WRAPPER="$SCRIPT_DIR/pull_options_eod.sh"
[ -x "$WRAPPER" ] || chmod +x "$WRAPPER"

CRON_LINE="30 16 * * 1-5 $WRAPPER  # [ALPACA-OPTIONS] eod-pull"

echo "Repo root: $REPO_ROOT"
echo "Wrapper:   $WRAPPER"
echo "Julia:     $JULIA"
echo ""
echo "Installing crontab entry:"
echo "  $CRON_LINE"
echo ""

(crontab -l 2>/dev/null | grep -v '\[ALPACA-OPTIONS\]'; echo "$CRON_LINE") | crontab -

echo "Installed. Current ALPACA-OPTIONS entries:"
crontab -l | grep '\[ALPACA-OPTIONS\]'
echo ""
echo "To remove: crontab -l | grep -v '\[ALPACA-OPTIONS\]' | crontab -"
