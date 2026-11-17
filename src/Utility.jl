const DEFAULT_DATA_URL         = "https://data.alpaca.markets/v2"
const DEFAULT_OPTIONS_DATA_URL = "https://data.alpaca.markets/v1beta1"

function _derive_options_url(data_url::AbstractString)
    s = String(data_url)
    # data.alpaca.markets/v2 → data.alpaca.markets/v1beta1
    endswith(s, "/v2")  && return s[1:end - length("/v2")]  * "/v1beta1"
    occursin("/v2/", s) && return replace(s, "/v2/" => "/v1beta1/")
    # For mocks / custom bases with no v2 segment, reuse the same host.
    return s
end

"""
    load_client(path="conf/apidata.toml";
                section="Credentials",
                data_url=DEFAULT_DATA_URL,
                options_data_url=nothing)

Load credentials from a TOML file. The file must contain a table named
`section` (default `"Credentials"`) with `endpoint`, `key`, and `secret`
fields. Use `section` to target a specific Alpaca account when the file
contains multiple named credential blocks, e.g. one for paper research
and one for paper production:

```toml
[paper_research]
endpoint = "https://paper-api.alpaca.markets"
key = "..."
secret = "..."

[paper_production]
endpoint = "https://paper-api.alpaca.markets"
key = "..."
secret = "..."
```

```julia
client = load_client("credentials.toml"; section = "paper_research")
```

`options_data_url` defaults to the v1beta1 options host derived from
`data_url` (override only if Alpaca moves the endpoint).
"""
function load_client(path::AbstractString = joinpath("conf", "apidata.toml");
                     section::AbstractString = "Credentials",
                     data_url::AbstractString = DEFAULT_DATA_URL,
                     options_data_url::Union{AbstractString,Nothing} = nothing)
    isfile(path) || throw(ArgumentError("credentials file not found: $path"))
    cfg = TOML.parsefile(path)
    creds = get(cfg, section, nothing)
    creds === nothing && throw(ArgumentError(
        "missing [$section] table in $path " *
        "(available tables: $(collect(keys(cfg))))"))
    endpoint = rstrip(String(creds["endpoint"]), '/')
    data     = rstrip(String(data_url), '/')
    options  = options_data_url === nothing ? _derive_options_url(data) :
                                                rstrip(String(options_data_url), '/')
    return AlpacaClient(endpoint, data, options,
                        String(creds["key"]), String(creds["secret"]))
end

# ---- parsing helpers used across resource modules ----

_parse_float(x::Nothing) = nothing
_parse_float(x::Number)  = Float64(x)
_parse_float(x::AbstractString) = isempty(x) ? nothing : parse(Float64, x)

_parse_float_default(x, default = 0.0) =
    (v = _parse_float(x); v === nothing ? default : v)

_parse_int(x::Nothing) = nothing
_parse_int(x::Integer) = Int(x)
_parse_int(x::AbstractString) = isempty(x) ? nothing : parse(Int, x)

function _parse_rfc3339(x::Nothing)
    return nothing
end
_parse_date_maybe(x::Nothing) = nothing
_parse_date_maybe(x::AbstractString) = isempty(x) ? nothing : Date(String(x))

function _parse_rfc3339(x::AbstractString)
    isempty(x) && return nothing
    s = String(x)
    # Strip trailing "Z" and fractional seconds beyond millisecond precision.
    s = replace(s, r"Z$" => "")
    # Drop fractional seconds entirely — Dates.DateTime ISO parser is picky.
    s = replace(s, r"\.\d+" => "")
    # Drop timezone offset like +00:00 if present.
    s = replace(s, r"[+-]\d{2}:\d{2}$" => "")
    return DateTime(s)
end

_symbols_param(s::AbstractString) = s
_symbols_param(s::AbstractVector) = join(s, ",")

_fmt_ts(x::AbstractString) = String(x)
_fmt_ts(x::DateTime) = Dates.format(x, dateformat"yyyy-mm-ddTHH:MM:SSZ")
_fmt_ts(x::Date)     = string(x)
