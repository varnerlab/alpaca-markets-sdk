# Historical Downloads

Helpers for bulk downloading historical bars and persisting them to CSV
for use in simulators and offline analysis. Built on top of
[`get_bars`](@ref); no extra package dependencies required.

## Example

```julia
using Alpaca, Dates

client = load_client()

# Ten years of daily SPY bars, written to data/daily/SPY_1Day.csv
download_bars(client, "SPY", "1Day";
              start    = Date(2016, 1, 1),
              finish   = Date(2026, 1, 1),
              save_dir = "data/daily",
              verbose  = true)

# Minute bars for Jan 2026 on AAPL + MSFT, chunked monthly so you get
# per-chunk progress on stdout
download_bars(client, ["AAPL", "MSFT"], "1Min";
              start        = Date(2024, 1, 1),
              finish       = Date(2026, 1, 1),
              chunk_months = 1,
              save_dir     = "data/minute",
              verbose      = true)

# Load back into memory without touching CSV.jl
bars = read_bars_csv("data/daily/SPY_1Day.csv")
```

## API

```@docs
download_bars
write_bars_csv
read_bars_csv
```
