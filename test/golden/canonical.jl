# Turn any value into nested arrays and strings so JSON3.write output is
# deterministic and comparable across runs.

function golden_canonical(x)
    if x === nothing
        return nothing
    elseif x isa JSON3.Object || x isa JSON3.Array
        return ["JSON3", JSON3.write(x)]
    elseif x isa Union{Number,Bool,AbstractString,Symbol,Date,DateTime,Time}
        return [string(typeof(x)), string(x)]
    elseif x isa AbstractVector
        return ["Vector", string(eltype(x)), Any[golden_canonical(v) for v in x]]
    elseif x isa Tuple
        return ["Tuple", Any[golden_canonical(v) for v in x]]
    elseif x isa AbstractDict
        pairs_out = Any[[string(k), golden_canonical(v)] for (k, v) in x]
        sort!(pairs_out; by = p -> p[1])
        return ["Dict", string(typeof(x)), pairs_out]
    end
    fields = Any[[string(f), golden_canonical(getfield(x, f))] for f in fieldnames(typeof(x))]
    return ["struct", string(nameof(typeof(x))), fields]
end

# One recorded request becomes [method, path, sorted query pairs, body].
function golden_canonical_request(r)
    body = isempty(r.body) ? nothing : golden_canonical(JSON3.read(r.body, Dict{String,Any}))
    query = isempty(r.query) ? String[] : sort(String.(split(r.query, '&')))
    return [r.method, r.path, query, body]
end
