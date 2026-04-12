# Tiny in-process HTTP server used to exercise the full request path
# (auth headers, query string, JSON body, error decoding) without hitting
# the real Alpaca API. Every testset that needs HTTP wraps its code in
# `with_mock(handler) do client ... end` so the server is started and
# torn down for each test.

"""
    RequestLog()

Captures each request the mock server receives so tests can assert on the
method / path / headers / decoded body after the fact.
"""
mutable struct RecordedRequest
    method::String
    target::String
    path::String
    query::String
    headers::Dict{String,String}
    body::String
end

mutable struct RequestLog
    entries::Vector{RecordedRequest}
end
RequestLog() = RequestLog(RecordedRequest[])

Base.length(r::RequestLog) = length(r.entries)
Base.getindex(r::RequestLog, i) = r.entries[i]
Base.lastindex(r::RequestLog) = lastindex(r.entries)

function _record!(log::RequestLog, req::HTTP.Request)
    uri = HTTP.URI(req.target)
    headers = Dict{String,String}()
    for (k, v) in req.headers
        headers[String(k)] = String(v)
    end
    push!(log.entries, RecordedRequest(
        String(req.method),
        String(req.target),
        String(uri.path),
        String(uri.query),
        headers,
        String(req.body),
    ))
end

json_response(status::Integer, payload) =
    HTTP.Response(status,
                  ["Content-Type" => "application/json"],
                  JSON3.write(payload))

plain_response(status::Integer, body::AbstractString) =
    HTTP.Response(status, ["Content-Type" => "text/plain"], body)

function _free_port()
    sock = listen(ip"127.0.0.1", 0)
    port = Int(getsockname(sock)[2])
    close(sock)
    return port
end

"""
    with_mock(handler) do client ... end

Spin up a local HTTP server that routes *every* request to `handler(req)`,
build an `AlpacaClient` pointed at it (both trading and data URLs share the
mock), run the test body, and tear the server down.

The handler should return an `HTTP.Response`.
"""
function with_mock(f::Function, handler::Function)
    port = _free_port()
    server = Base.with_logger(Logging.NullLogger()) do
        HTTP.serve!(handler, ip"127.0.0.1", port)
    end
    try
        base = "http://127.0.0.1:$(port)"
        client = Alpaca.AlpacaClient(base, base, "TEST_KEY_ID", "TEST_SECRET_KEY")
        f(client)
    finally
        Base.with_logger(Logging.NullLogger()) do
            close(server)
        end
    end
end

"""
    recording_handler(route_handler)

Wrap a handler so every request is appended to a `RequestLog` before being
dispatched. Returns `(wrapped_handler, log)`.
"""
function recording_handler(inner::Function)
    log = RequestLog()
    wrapped = function(req::HTTP.Request)
        _record!(log, req)
        return inner(req)
    end
    return wrapped, log
end
