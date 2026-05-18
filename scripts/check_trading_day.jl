# Preflight: exit 0 if today is an NYSE trading day per Alpaca's /calendar
# endpoint, exit 1 otherwise. Used by pull_options_eod.sh to skip holidays.

using Alpaca
using Dates

client = load_client()
today_date = today()
cal = get_calendar(client; start = today_date, finish = today_date)

if isempty(cal) || cal[1].date != today_date
    println("[skip] ", today_date, " is not a trading day")
    exit(1)
else
    d = cal[1]
    println("[ok] ", d.date, " trading session ", d.open, " - ", d.close)
    exit(0)
end
