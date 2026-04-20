using Alpaca
using Test
using HTTP
using JSON3
using Dates
using Sockets
using Logging

include("mock_server.jl")

@testset "Alpaca.jl" begin
    include("test_client.jl")
    include("test_account.jl")
    include("test_clock.jl")
    include("test_assets.jl")
    include("test_orders.jl")
    include("test_positions.jl")
    include("test_marketdata.jl")
    include("test_historical.jl")
    include("test_options.jl")
    include("test_streaming.jl")
    include("test_integration.jl")
end
