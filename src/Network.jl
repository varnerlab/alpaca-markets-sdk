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

