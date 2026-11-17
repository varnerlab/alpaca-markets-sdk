using Alpaca
using Test
using HTTP
using JSON3
using Dates
using Sockets
using Logging

include("mock_server.jl")

# The legacy names call Base.depwarn, and Pkg.test runs with --depwarn=yes. The unchanged legacy test files call
# those names many times. This logger wraps the global logger and drops the records of the :depwarn group.
# @test_deprecated installs its own task-local logger through @test_logs, so it still sees the warning.
struct DropDepwarnLogger <: Logging.AbstractLogger
    inner::Logging.AbstractLogger
end
Logging.min_enabled_level(l::DropDepwarnLogger) = Logging.min_enabled_level(l.inner)
Logging.catch_exceptions(l::DropDepwarnLogger) = Logging.catch_exceptions(l.inner)
function Logging.shouldlog(l::DropDepwarnLogger, level, _module, group, id)
    if group === :depwarn
        return false
    end
    return Logging.shouldlog(l.inner, level, _module, group, id)
end
function Logging.handle_message(l::DropDepwarnLogger, args...; kwargs...)
    return Logging.handle_message(l.inner, args...; kwargs...)
end
global_logger(DropDepwarnLogger(global_logger()))

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
    include("test_golden.jl")
    include("test_deprecations.jl")
    include("test_models_url.jl")
    include("test_api.jl")
    include("test_handlers_trading.jl")
    include("test_handlers_marketdata.jl")
end
