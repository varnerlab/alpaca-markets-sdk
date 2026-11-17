# Records what every legacy call returns and sends. Run once against v0.3.1:
#   julia --project=. test/golden/capture.jl
using Alpaca
using HTTP
using JSON3
using Dates
using Sockets
using Logging

include(joinpath(@__DIR__, "..", "mock_server.jl"))
include(joinpath(@__DIR__, "calls.jl"))

out_path = joinpath(@__DIR__, "golden-v0.3.1.jsonl")
open(out_path, "w") do io
    for (name, f) in GOLDEN_CALLS
        result, requests = run_golden_call(f)
        println(io, JSON3.write([name, result, requests]))
    end
end
println("wrote ", length(GOLDEN_CALLS), " entries to ", out_path)
