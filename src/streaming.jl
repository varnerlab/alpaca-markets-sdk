# Real-time market data streaming via Alpaca WebSocket API.
# Endpoint: wss://stream.data.alpaca.markets/v2/{feed}
# Docs: https://docs.alpaca.markets/docs/streaming-market-data

import HTTP.WebSockets: open as ws_open, send, receive

const DEFAULT_STREAM_URL = "wss://stream.data.alpaca.markets/v2"

# ── Reconnect configuration ─────────────────────────────────────────────

const _RECONNECT_BASE_SEC    = 1.0
const _RECONNECT_MAX_SEC     = 30.0
const _RECONNECT_MULTIPLIER  = 2.0

# ── AlpacaStream ─────────────────────────────────────────────────────────

"""
    AlpacaStream

Manages a WebSocket connection to the Alpaca real-time market data stream.
Create one via [`connect_market_stream`](@ref), register callbacks with
[`on_trade`](@ref), [`on_quote`](@ref), [`on_bar`](@ref), add subscriptions
with [`subscribe!`](@ref), then call [`start!`](@ref) to begin streaming in
the background.

The stream automatically reconnects on network failures with exponential
backoff. Authentication failures are treated as hard errors.
"""
mutable struct AlpacaStream
    client::AlpacaClient
    feed::String
    stream_url::String

    # Subscriptions (mutable sets — can change while running)
    trade_symbols::Set{String}
    quote_symbols::Set{String}
    bar_symbols::Set{String}

    # Callbacks
    trade_callbacks::Vector{Any}
    quote_callbacks::Vector{Any}
    bar_callbacks::Vector{Any}

    # State
    task::Union{Task,Nothing}
    running::Bool
    authenticated::Bool
    # Live websocket handle; set while connected, nothing otherwise.
    # Used by stop! to unblock the receive loop and by subscribe!/unsubscribe!
    # to push deltas on an already-running stream.
    ws::Any

    function AlpacaStream(client::AlpacaClient, feed::String, stream_url::String)
        return new(
            client, feed, stream_url,
            Set{String}(), Set{String}(), Set{String}(),
            [], [], [],
            nothing, false, false, nothing,
        )
    end
end

"""
    connect_market_stream(client; feed="iex", stream_url=DEFAULT_STREAM_URL)

Create an [`AlpacaStream`](@ref) for real-time market data. Does **not**
open the connection — call [`start!`](@ref) to begin streaming.

`feed` selects the data feed: `"iex"` (free) or `"sip"` (requires
subscription).
"""
function connect_market_stream(client::AlpacaClient;
                               feed::AbstractString = "iex",
                               stream_url::AbstractString = DEFAULT_STREAM_URL)
    url = rstrip(String(stream_url), '/') * "/" * feed
    return AlpacaStream(client, String(feed), url)
end

# ── Callbacks ────────────────────────────────────────────────────────────

"""
    on_trade(stream, callback)

Register a callback invoked for each incoming [`Trade`](@ref).
`callback` receives a single `Trade` argument.
"""
on_trade(s::AlpacaStream, cb) = (push!(s.trade_callbacks, cb); s)

"""
    on_quote(stream, callback)

Register a callback invoked for each incoming [`Quote`](@ref).
`callback` receives a single `Quote` argument.
"""
on_quote(s::AlpacaStream, cb) = (push!(s.quote_callbacks, cb); s)

"""
    on_bar(stream, callback)

Register a callback invoked for each incoming [`Bar`](@ref).
`callback` receives a single `Bar` argument.
"""
on_bar(s::AlpacaStream, cb) = (push!(s.bar_callbacks, cb); s)

# ── Subscriptions ────────────────────────────────────────────────────────

"""
    subscribe!(stream; trades=[], quotes=[], bars=[])

Add symbols to the stream subscription. Can be called before or after
[`start!`](@ref). If the stream is already running and authenticated, the
incremental subscribe frame is pushed to the server immediately; otherwise
the new symbols are sent on the next connect.
"""
function subscribe!(s::AlpacaStream;
                    trades::AbstractVector{<:AbstractString} = String[],
                    quotes::AbstractVector{<:AbstractString} = String[],
                    bars::AbstractVector{<:AbstractString}   = String[])
    new_trades = setdiff(trades, s.trade_symbols)
    new_quotes = setdiff(quotes, s.quote_symbols)
    new_bars   = setdiff(bars,   s.bar_symbols)
    union!(s.trade_symbols, trades)
    union!(s.quote_symbols, quotes)
    union!(s.bar_symbols, bars)
    # If we're live and authenticated, push the delta now so the server-side
    # subscription stays in sync with the in-memory sets.
    if s.authenticated && s.ws !== nothing &&
       !(isempty(new_trades) && isempty(new_quotes) && isempty(new_bars))
        try
            _send_subscribe_delta(s.ws, new_trades, new_quotes, new_bars)
        catch e
            @warn "Failed to push subscribe delta" exception = (e, catch_backtrace())
        end
    end
    return s
end

"""
    unsubscribe!(stream; trades=[], quotes=[], bars=[])

Remove symbols from the stream subscription. If the stream is running and
authenticated, the unsubscribe frame is pushed to the server immediately.
"""
function unsubscribe!(s::AlpacaStream;
                      trades::AbstractVector{<:AbstractString} = String[],
                      quotes::AbstractVector{<:AbstractString} = String[],
                      bars::AbstractVector{<:AbstractString}   = String[])
    drop_trades = intersect(trades, s.trade_symbols)
    drop_quotes = intersect(quotes, s.quote_symbols)
    drop_bars   = intersect(bars,   s.bar_symbols)
    setdiff!(s.trade_symbols, trades)
    setdiff!(s.quote_symbols, quotes)
    setdiff!(s.bar_symbols, bars)
    if s.authenticated && s.ws !== nothing &&
       !(isempty(drop_trades) && isempty(drop_quotes) && isempty(drop_bars))
        try
            _send_unsubscribe(s.ws, drop_trades, drop_quotes, drop_bars)
        catch e
            @warn "Failed to push unsubscribe delta" exception = (e, catch_backtrace())
        end
    end
    return s
end

# ── Message parsing ──────────────────────────────────────────────────────

function _parse_stream_trade(o)
    return Trade(
        String(o.S),
        _parse_rfc3339(String(o.t)),
        Float64(get(o, :p, 0.0)),
        Float64(get(o, :s, 0.0)),
        String(get(o, :x, "")),
        haskey(o, :i) ? Int(o.i) : nothing,
    )
end

function _parse_stream_quote(o)
    return Quote(
        String(o.S),
        _parse_rfc3339(String(o.t)),
        Float64(get(o, :bp, 0.0)),
        Float64(get(o, :bs, 0.0)),
        Float64(get(o, :ap, 0.0)),
        Float64(get(o, :as, 0.0)),
        String(get(o, :bx, "")),
        String(get(o, :ax, "")),
    )
end

function _parse_stream_bar(o)
    return Bar(
        String(o.S),
        _parse_rfc3339(String(o.t)),
        Float64(o.o),
        Float64(o.h),
        Float64(o.l),
        Float64(o.c),
        Float64(o.v),
        haskey(o, :n)  ? Int(o.n)     : nothing,
        haskey(o, :vw) ? Float64(o.vw) : nothing,
    )
end

# ── Internal helpers ─────────────────────────────────────────────────────

function _send_auth(ws, client::AlpacaClient)
    msg = JSON3.write(Dict(
        "action" => "auth",
        "key"    => client.key_id,
        "secret" => client.secret_key,
    ))
    @debug "Sending auth message"
    send(ws, msg)
end

function _send_subscribe(ws, s::AlpacaStream)
    trades = collect(s.trade_symbols)
    quotes = collect(s.quote_symbols)
    bars   = collect(s.bar_symbols)
    if isempty(trades) && isempty(quotes) && isempty(bars)
        return
    end
    msg = JSON3.write(Dict(
        "action" => "subscribe",
        "trades" => trades,
        "quotes" => quotes,
        "bars"   => bars,
    ))
    @debug "Sending subscribe" trades quotes bars
    send(ws, msg)
end

function _send_unsubscribe(ws, trades, quotes, bars)
    msg = JSON3.write(Dict(
        "action" => "unsubscribe",
        "trades" => collect(trades),
        "quotes" => collect(quotes),
        "bars"   => collect(bars),
    ))
    @debug "Sending unsubscribe" trades quotes bars
    send(ws, msg)
end

# Send only the incremental subscribe frame (for live deltas after start!).
function _send_subscribe_delta(ws, trades, quotes, bars)
    msg = JSON3.write(Dict(
        "action" => "subscribe",
        "trades" => collect(trades),
        "quotes" => collect(quotes),
        "bars"   => collect(bars),
    ))
    @debug "Sending subscribe delta" trades quotes bars
    send(ws, msg)
end

function _dispatch_message(s::AlpacaStream, o)
    T = String(o.T)
    if T == "t"
        trade = _parse_stream_trade(o)
        for cb in s.trade_callbacks
            try
                cb(trade)
            catch e
                @warn "Trade callback error" exception = (e, catch_backtrace())
            end
        end
    elseif T == "q"
        quote_val = _parse_stream_quote(o)
        for cb in s.quote_callbacks
            try
                cb(quote_val)
            catch e
                @warn "Quote callback error" exception = (e, catch_backtrace())
            end
        end
    elseif T == "b"
        bar = _parse_stream_bar(o)
        for cb in s.bar_callbacks
            try
                cb(bar)
            catch e
                @warn "Bar callback error" exception = (e, catch_backtrace())
            end
        end
    elseif T == "success"
        msg_text = String(get(o, :msg, ""))
        if msg_text == "connected"
            @info "WebSocket connected to Alpaca stream"
        elseif msg_text == "authenticated"
            s.authenticated = true
            @info "Authenticated with Alpaca stream"
        end
    elseif T == "subscription"
        @info "Subscription confirmed" trades = get(o, :trades, []) quotes = get(o, :quotes, []) bars = get(o, :bars, [])
    elseif T == "error"
        code = Int(get(o, :code, 0))
        msg_text = String(get(o, :msg, "unknown error"))
        @error "Alpaca stream error" code msg_text
        # Auth failures (codes 401-403) are hard errors
        if code in (401, 402, 403)
            throw(AlpacaError(code, code, msg_text, msg_text))
        end
    else
        @debug "Unhandled message type" T o
    end
end

function _run_stream(s::AlpacaStream)
    backoff = _RECONNECT_BASE_SEC
    while s.running
        s.authenticated = false
        try
            @info "Connecting to $(s.stream_url)"
            ws_open(s.stream_url) do ws
                s.ws = ws
                try
                    _send_auth(ws, s.client)
                    # Wait for auth confirmation before subscribing
                    while s.running && !s.authenticated
                        raw = receive(ws)
                        @debug "Raw message" raw
                        msgs = JSON3.read(raw)
                        for o in msgs
                            _dispatch_message(s, o)
                        end
                    end
                    if !s.authenticated
                        return  # stopped before auth completed
                    end
                    # Auth succeeded — reset backoff
                    backoff = _RECONNECT_BASE_SEC
                    _send_subscribe(ws, s)
                    # Main receive loop
                    while s.running
                        raw = receive(ws)
                        @debug "Raw message" raw
                        msgs = JSON3.read(raw)
                        for o in msgs
                            _dispatch_message(s, o)
                        end
                    end
                finally
                    s.ws = nothing
                end
            end
        catch e
            if !s.running
                @info "Stream stopped"
                return
            end
            if e isa AlpacaError
                @error "Authentication failed — not reconnecting" exception = (e, catch_backtrace())
                s.running = false
                rethrow()
            end
            @warn "Stream disconnected, reconnecting in $(backoff)s" exception = (e, catch_backtrace())
            sleep(backoff)
            backoff = min(backoff * _RECONNECT_MULTIPLIER, _RECONNECT_MAX_SEC)
        end
    end
end

# ── Public control ───────────────────────────────────────────────────────

"""
    start!(stream) -> stream

Open the WebSocket connection and begin streaming in a background `Task`.
Returns immediately. The stream authenticates, subscribes to any symbols
already added via [`subscribe!`](@ref), and dispatches incoming data to
registered callbacks.

Auto-reconnects on network failures with exponential backoff (1s → 30s max).
Authentication failures are hard errors that stop the stream.

See also: [`stop!`](@ref), `wait(stream)`.
"""
function start!(s::AlpacaStream)
    if s.running
        @warn "Stream is already running"
        return s
    end
    s.running = true
    s.task = @async _run_stream(s)
    return s
end

"""
    stop!(stream) -> stream

Signal the stream to close. The background task will exit after the current
message is processed. Blocks briefly until the task finishes.
"""
function stop!(s::AlpacaStream)
    s.running = false
    # Close the live ws (if any) so the blocking receive(ws) in the
    # background task unblocks promptly instead of waiting for the next
    # frame — which may never come on a quiet market.
    ws = s.ws
    if ws !== nothing
        try
            HTTP.WebSockets.close(ws)
        catch
            # Already closing / partial state — safe to ignore
        end
    end
    if s.task !== nothing && !istaskdone(s.task)
        @info "Stopping stream..."
        try
            wait(s.task)
        catch
            # Expected — the task may throw on close
        end
    end
    s.task = nothing
    s.authenticated = false
    @info "Stream stopped"
    return s
end

"""
    Base.wait(stream)

Block until the stream's background task finishes (either via [`stop!`](@ref)
or an unrecoverable error). Useful in scripts where the stream is the main
workload.
"""
function Base.wait(s::AlpacaStream)
    s.task === nothing && return
    wait(s.task)
end

"""
    isrunning(stream) -> Bool

Return `true` if the stream's background task is active.
"""
isrunning(s::AlpacaStream) = s.running && s.task !== nothing && !istaskdone(s.task)
