# default base URLs of the Alpaca market data APIs -
const DEFAULT_DATA_URL         = "https://data.alpaca.markets/v2"
const DEFAULT_OPTIONS_DATA_URL = "https://data.alpaca.markets/v1beta1"

# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
"""
    load_client(path::AbstractString = joinpath("conf", "apidata.toml");
        section::AbstractString = "Credentials",
        data_url::AbstractString = DEFAULT_DATA_URL,
        options_data_url::Union{AbstractString,Nothing} = nothing) -> AlpacaClient

Load the credentials from a TOML file and build an `AlpacaClient`. The file must contain a table named
`section` with the fields `endpoint`, `key`, and `secret`. Use `section` to select one account when the file
holds several named credential tables, e.g., one for paper research and one for paper production:

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

### Arguments
- `path::AbstractString`: the path to the TOML credentials file. The default is `conf/apidata.toml`.
- `section::AbstractString`: the name of the table that holds the credentials. The default is `"Credentials"`.
- `data_url::AbstractString`: the base URL of the stock market data API.
- `options_data_url::Union{AbstractString,Nothing}`: the base URL of the options data API. If `nothing`, the URL is
  derived from `data_url` (the `v1beta1` host). Set this only if Alpaca moves the endpoint.

### Returns
- `AlpacaClient`: the client that holds the trading, stock data, and options data base URLs and the credentials.

### Throws
- `ArgumentError`: when the credentials file does not exist, or when it has no table named `section`.
"""
function load_client(path::AbstractString = joinpath("conf", "apidata.toml");
    section::AbstractString = "Credentials",
    data_url::AbstractString = DEFAULT_DATA_URL,
    options_data_url::Union{AbstractString,Nothing} = nothing)::AlpacaClient

    # check that the credentials file exists -
    if (isfile(path) == false)
        throw(ArgumentError("credentials file not found: $path"));
    end

    # read the file, and look up the table with the credentials -
    cfg = TOML.parsefile(path);
    creds = get(cfg, section, nothing);
    if (creds === nothing)
        throw(ArgumentError("missing [$section] table in $path " *
            "(available tables: $(collect(keys(cfg))))"));
    end

    # clean the base URLs: no trailing slash -
    endpoint = rstrip(String(creds["endpoint"]), '/');
    data = rstrip(String(data_url), '/');

    # the options URL: derive it from the data URL unless the caller gave one -
    options = "";
    if (options_data_url === nothing)
        options = _derive_options_url(data);
    else
        options = rstrip(String(options_data_url), '/');
    end

    # build the client -
    return AlpacaClient(endpoint, data, options, String(creds["key"]), String(creds["secret"]));
end
# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
"""
    _derive_options_url(data_url::AbstractString) -> String

Derive the base URL of the options data API from the base URL of the stock data API.
A `/v2` suffix becomes `/v1beta1`. A URL with no `/v2` segment (e.g., a mock server) is returned unchanged.
"""
function _derive_options_url(data_url::AbstractString)::String

    # data.alpaca.markets/v2 becomes data.alpaca.markets/v1beta1 -
    s = String(data_url);
    if (endswith(s, "/v2") == true)
        return s[1:end - length("/v2")] * "/v1beta1";
    end
    if (occursin("/v2/", s) == true)
        return replace(s, "/v2/" => "/v1beta1/");
    end

    # a mock or custom base with no v2 segment keeps the same host -
    return s;
end

# _parse_float: a JSON value as a Float64; nothing and an empty string become nothing -
function _parse_float(x::Nothing)
    return nothing;
end

function _parse_float(x::Number)::Float64
    return Float64(x);
end

function _parse_float(x::AbstractString)::Union{Nothing,Float64}

    # an empty string has no value -
    if (isempty(x) == true)
        return nothing;
    end
    return parse(Float64, x);
end

# _parse_float_default: like _parse_float, but a missing value becomes the default -
function _parse_float_default(x, default = 0.0)

    # parse the value, and use the default when there is none -
    value = _parse_float(x);
    if (value === nothing)
        return default;
    end
    return value;
end

# _parse_int: a JSON value as an Int; nothing and an empty string become nothing -
function _parse_int(x::Nothing)
    return nothing;
end

function _parse_int(x::Integer)::Int
    return Int(x);
end

function _parse_int(x::AbstractString)::Union{Nothing,Int}

    # an empty string has no value -
    if (isempty(x) == true)
        return nothing;
    end
    return parse(Int, x);
end

# _parse_date_maybe: an ISO date string as a Date; nothing and an empty string become nothing -
function _parse_date_maybe(x::Nothing)
    return nothing;
end

function _parse_date_maybe(x::AbstractString)::Union{Nothing,Date}

    # an empty string has no value -
    if (isempty(x) == true)
        return nothing;
    end
    return Date(String(x));
end

# _parse_rfc3339: an RFC 3339 timestamp as a DateTime; nothing and an empty string become nothing.
# The fraction and the offset are dropped, so the result is the wall-clock time of the string -
function _parse_rfc3339(x::Nothing)
    return nothing;
end

function _parse_rfc3339(x::AbstractString)::Union{Nothing,DateTime}

    # an empty string has no value -
    if (isempty(x) == true)
        return nothing;
    end

    # strip the trailing "Z" -
    s = replace(String(x), r"Z$" => "");

    # drop the fractional seconds; the DateTime ISO parser is picky about them -
    s = replace(s, r"\.\d+" => "");

    # drop a timezone offset like +00:00, if present -
    s = replace(s, r"[+-]\d{2}:\d{2}$" => "");
    return DateTime(s);
end

# _symbols_param: a symbol or a vector of symbols as one comma-separated string -
function _symbols_param(s::AbstractString)
    return s;
end

function _symbols_param(s::AbstractVector)::String
    return join(s, ",");
end

# _fmt_ts: a timestamp argument as the string that Alpaca expects in a query -
function _fmt_ts(x::AbstractString)::String
    return String(x);
end

function _fmt_ts(x::DateTime)::String
    return Dates.format(x, dateformat"yyyy-mm-ddTHH:MM:SSZ");
end

function _fmt_ts(x::Date)::String
    return string(x);
end

# _to_symbol_vector: a symbol keyword (a String or a vector of strings) as a Vector{String}; nothing stays nothing -
function _to_symbol_vector(x::Nothing)
    return nothing;
end

function _to_symbol_vector(x::String)::Vector{String}
    return String[x];
end

function _to_symbol_vector(x::AbstractVector{<:AbstractString})::Vector{String}

    # copy each symbol into a new Vector{String} -
    symbols = String[];
    for symbol in x
        push!(symbols, String(symbol));
    end
    return symbols;
end

"""
    _parse_utc(x) -> Union{Missing,DateTime}

Parse an RFC 3339 timestamp into a UTC `DateTime`. A trailing `Z` means the time is already UTC.
An offset `±HH:MM` is subtracted to reach UTC. Fractional seconds are kept to the millisecond.
A value of `nothing` or an empty string becomes `missing`.

### Arguments
- `x`: the timestamp as a `String`, e.g., `"2026-11-18T09:30:00-05:00"`, or `nothing`.

### Returns
- `Union{Missing,DateTime}`: the time in UTC, or `missing` when there is no value.
"""
function _parse_utc(x)::Union{Missing,DateTime}

    # no value, no time -
    if (x === nothing)
        return missing;
    end
    s = String(x);
    if (isempty(s) == true)
        return missing;
    end

    # the offset at the end of the string, e.g., -05:00. A trailing Z has no offset -
    offset = Dates.Millisecond(0);
    offset_match = match(r"([+-])(\d{2}):(\d{2})$", s);
    if (offset_match !== nothing)
        offset_ms = (parse(Int, offset_match.captures[2]) * 60 + parse(Int, offset_match.captures[3])) * 60 * 1000;
        if (offset_match.captures[1] == "-")
            offset_ms = -offset_ms;
        end
        offset = Dates.Millisecond(offset_ms);
        s = s[1:(offset_match.offset - 1)];
    end
    s = replace(s, r"Z$" => "");

    # the fraction: keep the first three digits (milliseconds), padded with zeros -
    milliseconds = 0;
    fraction_match = match(r"\.(\d+)$", s);
    if (fraction_match !== nothing)
        digits = rpad(fraction_match.captures[1], 3, '0');
        milliseconds = parse(Int, digits[1:3]);
        s = s[1:(fraction_match.offset - 1)];
    end

    # the local time minus the offset is UTC -
    local_time = DateTime(s) + Dates.Millisecond(milliseconds);
    return local_time - offset;
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
