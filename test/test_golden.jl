include(joinpath("golden", "calls.jl"))

@testset "golden: legacy outputs match v0.3.1" begin
    golden = Dict{String,String}()
    for line in readlines(joinpath(@__DIR__, "golden", "golden-v0.3.1.jsonl"))
        entry = JSON3.read(line)
        golden[String(entry[1])] = line
    end
    for (name, f) in GOLDEN_CALLS
        result, requests = run_golden_call(f)
        @test JSON3.write([name, result, requests]) == golden[name]
    end
end
