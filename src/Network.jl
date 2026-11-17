# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
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

# Legacy request function. It builds the URL and sends the request through _http_call,
# then parses the JSON body. An empty body returns nothing.
function _request(client::AlpacaClient, method::AbstractString,
                  base::AbstractString, path::AbstractString;
                  query::Union{Nothing,AbstractDict} = nothing,
                  body::Any = nothing)

    # build the URL from the base, the path, and the query -
    request_url = _build_url(base, path, query)

    # send the request, and read the response body as a String -
    response_string = _http_call(client, String(method), request_url; body = body)

    # an empty body has nothing to parse -
    if isempty(response_string)
        return nothing
    end

    # parse the JSON text and return the result -
    return JSON3.read(response_string)
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

# The handler of api when the caller does not pass one. This generic function has no methods here.
# The handler methods are added in Handler.jl.
function _default_handler end

# This function sends one HTTP request with the headers of the client and returns the response body as a String.
# A 429 status code (rate limit) is retried with an increasing wait. Any other status outside 200-299 throws an AlpacaError.
function _http_call(client::AlpacaClient, method::String, request_url::String; body = nothing)::String

    # the headers carry the credentials of the client, and the format that we want back -
    headers = _auth_headers(client)

    # a request body is sent as JSON text -
    payload = UInt8[]
    if body !== nothing
        push!(headers, "Content-Type" => "application/json")
        payload = Vector{UInt8}(JSON3.write(body))
    end

    # send the request. We handle the status code on our own, so HTTP.jl does NOT throw for it, and does NOT retry -
    response = nothing
    for attempt in 1:_MAX_RETRIES
        response = HTTP.request(method, request_url, headers, payload;
                                status_exception = false, retry = false)

        # a 429 status code means that we are rate limited: wait, and try again -
        if response.status == 429 && attempt < _MAX_RETRIES
            wait_secs = _INITIAL_BACKOFF * 2^(attempt - 1)
            @warn "Rate limited (429), retrying in $(wait_secs)s (attempt $attempt/$(_MAX_RETRIES))"
            sleep(wait_secs)
            continue
        end
        break
    end

    # the body of the response as a String -
    response_string = String(response.body)

    # a status code from 200 to 299 is a successful call -
    if 200 <= response.status < 300
        return response_string
    end

    # otherwise, read the error code and message from the JSON body, when the body has them -
    error_code = nothing
    error_message = response_string
    try
        parsed = JSON3.read(response_string)
        if parsed isa JSON3.Object
            if haskey(parsed, :code)
                error_code = Int(parsed.code)
            end
            if haskey(parsed, :message)
                error_message = String(parsed.message)
            end
        end
    catch
        # the body is not JSON, so the error message stays the raw body -
    end
    throw(AlpacaError(response.status, error_code, error_message, response_string))
end

# This function reads the next_page_token key of a page body.
# It returns nothing when the key is missing, null, or an empty string.
function _next_page_token(body::String)::Union{Nothing,String}

    # parse the page body -
    parsed = JSON3.read(body)
    if !(parsed isa JSON3.Object)
        return nothing
    end

    # a missing key, or a null value, means that there is no next page -
    if !haskey(parsed, :next_page_token) || parsed[:next_page_token] === nothing
        return nothing
    end

    # an empty token means that there is no next page -
    token = String(parsed[:next_page_token])
    if isempty(token)
        return nothing
    end
    return token
end

# --- _merge: combine the handler results of two pages, in page order -----------------------------------------
# A table page is appended to the rows of the earlier pages -
function _merge(a::DataFrame, b::DataFrame)
    return vcat(a, b; cols = :union)
end

# A dictionary of vectors appends the vector of each key, in page order -
function _merge(a::Dict{String,Vector{T}}, b::Dict{String,Vector{T}}) where T
    merged = Dict{String,Vector{T}}()
    for (key, value) in a
        merged[key] = copy(value)
    end
    for (key, value) in b
        if haskey(merged, key)
            append!(merged[key], value)
        else
            merged[key] = copy(value)
        end
    end
    return merged
end

# A dictionary of single values lets the later page overwrite the key -
function _merge(a::Dict{String,T}, b::Dict{String,T}) where T
    merged = Dict{String,T}()
    for (key, value) in a
        merged[key] = value
    end
    for (key, value) in b
        merged[key] = value
    end
    return merged
end

# A vector is concatenated -
function _merge(a::Vector, b::Vector)
    return vcat(a, b)
end

# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #

# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
"""
    api(client::AlpacaClient, model::AbstractAlpacaEndpointModel;
        handler::Function = _default_handler)

Make the HTTP call for an endpoint model and process the response body with a handler.
A paginated endpoint is called once for each page, and the handler results are merged in page order.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `model::AbstractAlpacaEndpointModel`: the endpoint model that describes the request.
- `handler::Function`: the function that receives the type of the model and the body of a page as a `String`.

### Returns
- The result of the handler. A paginated endpoint returns the merged result of all pages.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
"""
function api(client::AlpacaClient, model::AbstractAlpacaEndpointModel;
    handler::Function = _default_handler)

    # the URL of the first page -
    first_url = url(client, model)
    request_url = first_url
    result = nothing

    # get a page, process it, and follow the page token until there are no more pages -
    while true
        body = _http_call(client, "GET", request_url)
        page = handler(typeof(model), body)

        # the first page starts the result. Later pages are merged into it -
        if result === nothing
            result = page
        else
            result = _merge(result, page)
        end

        # only a paginated endpoint has a next page -
        if !_is_paginated(model)
            break
        end
        token = _next_page_token(body)
        if token === nothing
            break
        end
        request_url = first_url * "&page_token=" * URIs.escapeuri(token)
    end
    return result
end
# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #
