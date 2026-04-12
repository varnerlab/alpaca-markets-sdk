@testset "historical: csv round-trip" begin
    bars = [
        Bar("AAPL", DateTime("2026-04-06T00:00:00"),
            256.5, 262.1, 256.5, 258.9, 4.8e5, 12345, 259.1),
        Bar("AAPL", DateTime("2026-04-07T00:00:00"),
            256.1, 256.2, 245.7, 253.6, 1.3e6, 54321, 251.2),
        Bar("AAPL", DateTime("2026-04-08T00:00:00"),
            258.0, 260.0, 257.5, 259.5, 9.8e5, nothing, nothing),
    ]

    path, io = mktemp()
    close(io)
    try
        write_bars_csv(path, bars)

        # Verify header + row count
        lines = readlines(path)
        @test lines[1] == "timestamp,symbol,open,high,low,close,volume,trade_count,vwap"
        @test length(lines) == 1 + length(bars)

        round_trip = read_bars_csv(path)
        @test length(round_trip) == length(bars)
        for (a, b) in zip(bars, round_trip)
            @test a.symbol == b.symbol
            @test a.t == b.t
            @test a.o == b.o
            @test a.h == b.h
            @test a.l == b.l
            @test a.c == b.c
            @test a.v == b.v
            @test a.n == b.n
            @test a.vw == b.vw
        end
    finally
        rm(path; force = true)
    end
end

@testset "historical: download_bars wraps get_bars + writes csv" begin
    bar_obj = Dict("t" => "2026-04-06T00:00:00Z", "o" => 256.5, "h" => 262.1,
                   "l" => 256.5, "c" => 258.9, "v" => 4.8e5,
                   "n" => 12345, "vw" => 259.1)

    handler, log = recording_handler() do _req
        return json_response(200, Dict(
            "bars"            => Dict("AAPL" => [bar_obj]),
            "next_page_token" => nothing,
        ))
    end

    tmp = mktempdir()
    try
        with_mock(handler) do client
            result = download_bars(client, "AAPL", "1Day";
                                   start = Date(2026, 4, 6),
                                   finish = Date(2026, 4, 6),
                                   save_dir = tmp)
            @test haskey(result, "AAPL")
            @test length(result["AAPL"]) == 1
        end
        # CSV written with symbol_timeframe.csv naming
        csv_path = joinpath(tmp, "AAPL_1Day.csv")
        @test isfile(csv_path)
        loaded = read_bars_csv(csv_path)
        @test length(loaded) == 1
        @test loaded[1].o == 256.5
    finally
        rm(tmp; recursive = true, force = true)
    end

    @test occursin("timeframe=1Day", log[1].query)
end

@testset "historical: chunk_months splits range into requests" begin
    requests = Ref(0)
    handler = function(_)
        requests[] += 1
        return json_response(200, Dict(
            "bars"            => Dict("SPY" => []),
            "next_page_token" => nothing,
        ))
    end

    with_mock(handler) do client
        download_bars(client, "SPY", "1Day";
                      start = Date(2024, 1, 1),
                      finish = Date(2024, 6, 30),
                      chunk_months = 2)
    end

    @test requests[] == 3  # Jan-Feb, Mar-Apr, May-Jun
end
