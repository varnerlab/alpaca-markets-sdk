# =============================================================================
# Network: the api(...) method, which sends the requests of an endpoint model, and the helpers that send one HTTP request
# =============================================================================
# --- PUBLIC METHODS BELOW HERE -------------------------------------------------------------------------------- #
"""
    api(client::AlpacaClient, model::AbstractAlpacaEndpointModel;
        handler::Function = _default_handler, max_pages::Union{Nothing,Int} = nothing)

Make the HTTP call for an endpoint model and process the response body with a handler.
A paginated endpoint is called once for each page, and the handler results are merged in page order.
A model whose HTTP method is not `GET` sends one request, with the JSON body of the model, and is never paginated.

### Arguments
- `client::AlpacaClient`: the client that holds the credentials and the base URLs.
- `model::AbstractAlpacaEndpointModel`: the endpoint model that describes the request.
- `handler::Function`: the function that receives the type of the model and the body of a page as a `String`.
- `max_pages::Union{Nothing,Int}`: the number of pages after which a paginated request stops. `nothing` follows every page. A write model sends one request and never follows pages, but `max_pages = 0` throws before a write too.

### Returns
- The result of the handler. A paginated endpoint returns the merged result of all pages.
- A `DataFrame` result that `max_pages` stopped carries the next page token in its metadata under `"next_page_token"`, which you read with `metadata(df, "next_page_token", nothing)`.

### Throws
- `AlpacaError`: when the response status is not in the range 200 to 299.
- `ArgumentError`: when `max_pages` is less than `1`. The call sends no request.
"""
function api(client::AlpacaClient, model::AbstractAlpacaEndpointModel;
    handler::Function = _default_handler, max_pages::Union{Nothing,Int} = nothing)

    # check the page cap before any request -
    if (max_pages !== nothing && max_pages < 1)
        throw(ArgumentError("max_pages must be at least 1, got $(max_pages)"));
    end

    # the URL of the first page -
    first_url = url(client, model);
    request_url = first_url;
    pages = Any[];
    remaining_token = nothing;

    # a write model sends one request with its own method and body, and returns the result of the handler -
    method = _http_method(model);
    if (method != "GET")
        body = _http_call(client, method, first_url; body = _request_body(model));
        return handler(typeof(model), body);
    end

    # get a page, process it, and follow the page token until there are no more pages -
    while (true)
        body = _http_call(client, "GET", request_url);
        push!(pages, handler(typeof(model), body));

        # only a paginated endpoint has a next page -
        if (_is_paginated(model) == false)
            break;
        end
        token = _next_page_token(body);
        if (token === nothing)
            break;
        end

        # stop at the page cap -
        if (max_pages !== nothing && length(pages) >= max_pages)
            remaining_token = token;
            break;
        end
        request_url = first_url * "&page_token=" * URIs.escapeuri(token);
    end

    # one page is the result. Several pages are merged once, in page order, so a long download is not copied for each page -
    result = pages[1];
    if (length(pages) > 1)
        result = _merge_pages(pages[1], pages);
    end

    # a DataFrame that the page cap stopped carries the next page token. A custom handler result is returned as it is -
    if (remaining_token !== nothing && result isa DataFrame)
        metadata!(result, "next_page_token", remaining_token; style = :note);
    end
    return result;
end
# --- PUBLIC METHODS ABOVE HERE -------------------------------------------------------------------------------- #

# --- PRIVATE METHODS BELOW HERE ------------------------------------------------------------------------------- #
# _auth_headers: the headers that carry the credentials of the client, and the format that we want back -
function _auth_headers(client::AlpacaClient)::Vector{Pair{String,String}}
    return [
        "APCA-API-KEY-ID" => client.key_id,
        "APCA-API-SECRET-KEY" => client.secret_key,
        "Accept" => "application/json",
    ];
end

# _join_url: join a base URL and a path with exactly one slash between them -
function _join_url(base::AbstractString, path::AbstractString)::String
    if (startswith(path, "/"))
        return base * path;
    end
    return base * "/" * path;
end

# _build_url: join a base URL and a path, and append the query. A query value that is nothing is left out -
function _build_url(base::AbstractString, path::AbstractString, query::Union{Nothing,AbstractDict} = nothing)::String
    request_url = _join_url(base, path);
    if (query === nothing || isempty(query))
        return request_url;
    end

    # escape each key and value, and skip a value that is nothing -
    parts = String[];
    for (k, v) in query
        if (v === nothing)
            continue;
        end
        push!(parts, string(URIs.escapeuri(string(k)), "=", URIs.escapeuri(string(v))));
    end
    if (isempty(parts) == false)
        request_url = request_url * "?" * join(parts, "&");
    end
    return request_url;
end

const _MAX_RETRIES    = 5
const _INITIAL_BACKOFF = 2.0   # seconds

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

# --- _merge_pages: combine the handler results of all pages at once, in page order. The first page selects the method ---
# _merge_pages: the table pages are stacked in one vcat, which gives the columns of every page (cols = :union) -
function _merge_pages(first_page::DataFrame, pages::Vector{Any})::DataFrame

    # collect the tables -
    frames = DataFrame[];
    for page in pages
        push!(frames, page);
    end

    # stack the tables once -
    return reduce(vcat, frames; cols = :union);
end

# _merge_pages: a dictionary of vectors appends the vector of each key, in page order -
function _merge_pages(first_page::Dict{String,Vector{T}}, pages::Vector{Any})::Dict{String,Vector{T}} where T

    # copy the vector of a new key, and append to the vector of a key seen on an earlier page -
    merged = Dict{String,Vector{T}}();
    for page in pages
        for (key, value) in page
            if (haskey(merged, key) == true)
                append!(merged[key], value);
            else
                merged[key] = copy(value);
            end
        end
    end
    return merged;
end

# _merge_pages: a dictionary of single values lets a later page overwrite the key -
function _merge_pages(first_page::Dict{String,T}, pages::Vector{Any})::Dict{String,T} where T

    # copy each key, in page order -
    merged = Dict{String,T}();
    for page in pages
        for (key, value) in page
            merged[key] = value;
        end
    end
    return merged;
end

# _merge_pages: the vectors are concatenated. The element type promotes the element types of the pages, as vcat does -
function _merge_pages(first_page::Vector, pages::Vector{Any})::Vector

    # the element type of the result -
    element_type = eltype(first_page);
    for page in pages
        element_type = promote_type(element_type, eltype(page));
    end

    # append each page, in page order -
    merged = element_type[];
    for page in pages
        append!(merged, page);
    end
    return merged;
end

# _merge: combine the handler results of two pages, in page order -
function _merge(a, b)
    return _merge_pages(a, Any[a, b]);
end
# --- PRIVATE METHODS ABOVE HERE ------------------------------------------------------------------------------- #
