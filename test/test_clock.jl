@testset "clock: parse" begin
    handler = function(_req)
        return json_response(200, Dict(
            "timestamp"  => "2026-04-13T14:30:00.123456Z",
            "is_open"    => true,
            "next_open"  => "2026-04-13T09:30:00Z",
            "next_close" => "2026-04-13T16:00:00Z",
        ))
    end

    with_mock(handler) do client
        clk = get_clock(client)
        @test clk isa MarketClock
        @test clk.is_open == true
        @test clk.timestamp == DateTime("2026-04-13T14:30:00")
        @test clk.next_open == DateTime("2026-04-13T09:30:00")
        @test clk.next_close == DateTime("2026-04-13T16:00:00")
    end
end

@testset "calendar: parse + query" begin
    handler, log = recording_handler() do req
        return json_response(200, [
            Dict("date" => "2026-04-13", "open" => "09:30", "close" => "16:00"),
            Dict("date" => "2026-04-14", "open" => "09:30", "close" => "16:00"),
        ])
    end

    with_mock(handler) do client
        days = get_calendar(client; start = Date(2026, 4, 13), finish = Date(2026, 4, 14))
        @test length(days) == 2
        @test days[1] isa CalendarDay
        @test days[1].date == Date(2026, 4, 13)
        @test days[1].open == Time(9, 30)
        @test days[1].close == Time(16, 0)
    end

    @test occursin("start=2026-04-13", log[1].query)
    @test occursin("end=2026-04-14", log[1].query)
end
