const DEFAULT_DATA_URL         = "https://data.alpaca.markets/v2"
const DEFAULT_OPTIONS_DATA_URL = "https://data.alpaca.markets/v1beta1"

"""
    AlpacaClient(trading_url, data_url, [options_data_url,] key_id, secret_key)

Holds credentials and base URLs for the Alpaca REST APIs. Usually
constructed via [`load_client`](@ref) from a TOML config file.

Fields:

- `trading_url` — trading API base, e.g. `https://paper-api.alpaca.markets/v2`
- `data_url` — stock market data base, e.g. `https://data.alpaca.markets/v2`
- `options_data_url` — options market data base, e.g. `https://data.alpaca.markets/v1beta1`
- `key_id`, `secret_key` — Alpaca API credentials

The four-argument constructor `AlpacaClient(trading_url, data_url, key_id, secret_key)`
is preserved for convenience and derives `options_data_url` from `data_url`
automatically.
"""
struct AlpacaClient
    trading_url::String
    data_url::String
    options_data_url::String
    key_id::String
    secret_key::String
end

function _derive_options_url(data_url::AbstractString)
    s = String(data_url)
    # data.alpaca.markets/v2 → data.alpaca.markets/v1beta1
    endswith(s, "/v2")  && return s[1:end - length("/v2")]  * "/v1beta1"
    occursin("/v2/", s) && return replace(s, "/v2/" => "/v1beta1/")
    # For mocks / custom bases with no v2 segment, reuse the same host.
    return s
end

# Four-arg convenience constructor (backwards compatible).
AlpacaClient(trading_url::AbstractString, data_url::AbstractString,
             key_id::AbstractString, secret_key::AbstractString) =
    AlpacaClient(trading_url, data_url,
                 _derive_options_url(data_url),
                 key_id, secret_key)

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

function _auth_headers(client::AlpacaClient)
    return [
        "APCA-API-KEY-ID" => client.key_id,
        "APCA-API-SECRET-KEY" => client.secret_key,
        "Accept" => "application/json",
    ]
end

_join_url(base::AbstractString, path::AbstractString) =
    startswith(path, "/") ? base * path : base * "/" * path

function _build_url(base::AbstractString, path::AbstractString,
                    query::Union{Nothing,AbstractDict} = nothing)
    url = _join_url(base, path)
    if query !== nothing && !isempty(query)
        parts = String[]
        for (k, v) in query
            v === nothing && continue
            push!(parts, string(URIs.escapeuri(string(k)), "=",
                                URIs.escapeuri(string(v))))
        end
        isempty(parts) || (url = url * "?" * join(parts, "&"))
    end
    return url
end

function _handle_response(resp::HTTP.Response)
    body = String(resp.body)
    if 200 <= resp.status < 300
        return isempty(body) ? nothing : JSON3.read(body)
    end
    code, msg = nothing, body
    try
        parsed = JSON3.read(body)
        if parsed isa JSON3.Object
            code = haskey(parsed, :code) ? Int(parsed.code) : nothing
            msg = haskey(parsed, :message) ? String(parsed.message) : body
        end
    catch
    end
    throw(AlpacaError(resp.status, code, msg, body))
end

const _MAX_RETRIES    = 5
const _INITIAL_BACKOFF = 2.0   # seconds

function _request(client::AlpacaClient, method::AbstractString,
                  base::AbstractString, path::AbstractString;
                  query::Union{Nothing,AbstractDict} = nothing,
                  body::Any = nothing)
    url = _build_url(base, path, query)
    headers = _auth_headers(client)
    payload = UInt8[]
    if body !== nothing
        push!(headers, "Content-Type" => "application/json")
        payload = Vector{UInt8}(JSON3.write(body))
    end
    for attempt in 1:_MAX_RETRIES
        resp = HTTP.request(method, url, headers, payload;
                            status_exception = false, retry = false)
        if resp.status == 429 && attempt < _MAX_RETRIES
            wait_secs = _INITIAL_BACKOFF * 2^(attempt - 1)
            @warn "Rate limited (429), retrying in $(wait_secs)s (attempt $attempt/$(_MAX_RETRIES))"
            sleep(wait_secs)
            continue
        end
        return _handle_response(resp)
    end
end

_trading_get(c, path; query = nothing) =
    _request(c, "GET", c.trading_url, path; query = query)
_trading_post(c, path; body = nothing) =
    _request(c, "POST", c.trading_url, path; body = body)
_trading_delete(c, path; query = nothing) =
    _request(c, "DELETE", c.trading_url, path; query = query)
_data_get(c, path; query = nothing) =
    _request(c, "GET", c.data_url, path; query = query)
_options_data_get(c, path; query = nothing) =
    _request(c, "GET", c.options_data_url, path; query = query)

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
