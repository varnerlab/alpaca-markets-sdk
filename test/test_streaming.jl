# WebSocket streaming tests.
#
# Runs an in-process WebSocket server that speaks just enough of the
# Alpaca market-data protocol to exercise authentication, initial
# subscription, live subscribe/unsubscribe deltas, and stop! on an
# idle connection.

using Alpaca: AlpacaStream, connect_market_stream, subscribe!, unsubscribe!,
              start!, stop!, isrunning, on_trade

# ── Mock WebSocket server ────────────────────────────────────────────────

struct WSFrameLog
    frames::Vector{Any}   # parsed JSON objects the server received
    lock::ReentrantLock
end
WSFrameLog() = WSFrameLog(Any[], ReentrantLock())

function _record_frame!(log::WSFrameLog, frame)
    lock(log.lock) do
        push!(log.frames, frame)
    end
end

function _frames_snapshot(log::WSFrameLog)
    lock(log.lock) do
        return copy(log.frames)
    end
end

function _free_ws_port()
    sock = listen(ip"127.0.0.1", 0)
    port = Int(getsockname(sock)[2])
    close(sock)
    return port
end

"""
    with_mock_ws(test_body, server_handler)

Spin up a local WebSocket server that dispatches every connection to
`server_handler(ws, log)`. `log::WSFrameLog` collects every JSON frame
received from the client so tests can assert on auth/subscribe payloads.
Passes `(stream_url, log)` to `test_body`.
"""
function with_mock_ws(test_body::Function, server_handler::Function)
    log = WSFrameLog()
    port = _free_ws_port()
    server = Base.with_logger(Logging.NullLogger()) do
        HTTP.WebSockets.listen!("127.0.0.1", port) do ws
            try
                server_handler(ws, log)
            catch e
                e isa HTTP.WebSockets.WebSocketError && return
                e isa EOFError && return
                rethrow()
            end
        end
    end
    try
        stream_url = "ws://127.0.0.1:$(port)/v2"
        test_body(stream_url, log)
    finally
        Base.with_logger(Logging.NullLogger()) do
            close(server)
        end
    end
end

# Read one client frame (which may be a JSON array or object) and return
# a vector of parsed objects.
function _read_client_frames(ws)
    raw = HTTP.WebSockets.receive(ws)
    parsed = JSON3.read(raw)
    return parsed isa JSON3.Array ? collect(parsed) : [parsed]
end

# Standard Alpaca-ish handler: greet, wait for auth, ack, then run `body`
# with the live ws + log so tests can drive further interaction.
function _alpaca_handshake(body::Function)
    return function(ws, log::WSFrameLog)
        HTTP.WebSockets.send(ws, JSON3.write([Dict("T" => "success", "msg" => "connected")]))
        # Auth frame
        for f in _read_client_frames(ws)
            _record_frame!(log, f)
        end
        HTTP.WebSockets.send(ws, JSON3.write([Dict("T" => "success", "msg" => "authenticated")]))
        body(ws, log)
    end
end

# Wait up to `seconds` for `pred()` to become true. Returns true if it did.
function _wait_for(pred::Function; seconds::Real = 3.0, step::Real = 0.02)
    deadline = time() + seconds
    while time() < deadline
        pred() && return true
        sleep(step)
    end
    return pred()
end

# Build an AlpacaStream pointed at a mock URL.
function _mock_stream(stream_url::AbstractString; feed::AbstractString = "iex")
    client = Alpaca.AlpacaClient("http://unused", "http://unused",
                                 "TEST_KEY", "TEST_SECRET")
    return connect_market_stream(client; feed = feed, stream_url = stream_url)
end

# ── Tests ────────────────────────────────────────────────────────────────

@testset "streaming" begin

    @testset "auth + initial subscribe" begin
        handler = _alpaca_handshake() do ws, log
            # Record one more client frame (the initial subscribe) then
            # drain whatever the client sends until it closes.
            while true
                try
                    for f in _read_client_frames(ws)
                        _record_frame!(log, f)
                    end
                catch
                    return
                end
            end
        end

        with_mock_ws(handler) do stream_url, log
            stream = _mock_stream(stream_url)
            subscribe!(stream; trades = ["AAPL"])
            start!(stream)

            @test _wait_for(() -> length(_frames_snapshot(log)) >= 2)
            frames = _frames_snapshot(log)
            @test frames[1]["action"] == "auth"
            @test frames[1]["key"]    == "TEST_KEY"
            @test frames[1]["secret"] == "TEST_SECRET"
            @test frames[2]["action"] == "subscribe"
            @test collect(frames[2]["trades"]) == ["AAPL"]

            stop!(stream)
            @test !isrunning(stream)
        end
    end

    @testset "post-start subscribe delta" begin
        handler = _alpaca_handshake() do ws, log
            while true
                try
                    for f in _read_client_frames(ws)
                        _record_frame!(log, f)
                    end
                catch
                    return
                end
            end
        end

        with_mock_ws(handler) do stream_url, log
            stream = _mock_stream(stream_url)
            # Start with one symbol so an initial subscribe frame is sent
            subscribe!(stream; trades = ["AAPL"])
            start!(stream)
            @test _wait_for(() -> length(_frames_snapshot(log)) >= 2)   # auth + initial sub

            # Live delta — should produce a third frame on the server
            subscribe!(stream; trades = ["MSFT"])
            @test _wait_for(() -> length(_frames_snapshot(log)) >= 3)

            frames = _frames_snapshot(log)
            @test frames[3]["action"] == "subscribe"
            @test collect(frames[3]["trades"]) == ["MSFT"]

            # Unsubscribe delta
            unsubscribe!(stream; trades = ["AAPL"])
            @test _wait_for(() -> length(_frames_snapshot(log)) >= 4)
            frames = _frames_snapshot(log)
            @test frames[4]["action"] == "unsubscribe"
            @test collect(frames[4]["trades"]) == ["AAPL"]

            stop!(stream)
        end
    end

    @testset "stop! on idle socket returns promptly" begin
        handler = _alpaca_handshake() do ws, log
            # Record initial subscribe, then go silent — never send another
            # frame. stop! must still return promptly.
            while true
                try
                    for f in _read_client_frames(ws)
                        _record_frame!(log, f)
                    end
                catch
                    return
                end
            end
        end

        with_mock_ws(handler) do stream_url, log
            stream = _mock_stream(stream_url)
            subscribe!(stream; trades = ["AAPL"])
            start!(stream)
            @test _wait_for(() -> length(_frames_snapshot(log)) >= 2)

            t0 = time()
            stop!(stream)
            elapsed = time() - t0
            @test !isrunning(stream)
            # Should be essentially immediate. Allow 2s headroom for CI.
            @test elapsed < 2.0
        end
    end

end
