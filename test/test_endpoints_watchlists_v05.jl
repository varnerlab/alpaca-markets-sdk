# Tests for the v0.5 watchlist models: URLs, methods, bodies, tables, and mock round trips -
using DataFrames: DataFrame

@testset "v0.5 watchlists: URLs" begin
    @test url("http://h", MyWatchlistsEndpointModel()) == "http://h/watchlists"
    @test url("http://h", MyWatchlistEndpointModel(id = "w1")) == "http://h/watchlists/w1"
    @test url("http://h", MyWatchlistEndpointModel(name = "my list")) == "http://h/watchlists:by_name?name=my%20list"
    @test url("http://h", MyCreateWatchlistEndpointModel(name = "tech")) == "http://h/watchlists"
    @test url("http://h", MyUpdateWatchlistEndpointModel(id = "w1", new_name = "x")) == "http://h/watchlists/w1"
    @test url("http://h", MyUpdateWatchlistEndpointModel(name = "tech", symbols = ["AAPL"])) == "http://h/watchlists:by_name?name=tech"
    @test url("http://h", MyAddWatchlistAssetEndpointModel(id = "w1", symbol = "AAPL")) == "http://h/watchlists/w1"
    @test url("http://h", MyAddWatchlistAssetEndpointModel(name = "tech", symbol = "AAPL")) == "http://h/watchlists:by_name?name=tech"
    @test url("http://h", MyRemoveWatchlistAssetEndpointModel(id = "w1", symbol = "BTC/USD")) == "http://h/watchlists/w1/BTC%2FUSD"
    @test url("http://h", MyDeleteWatchlistEndpointModel(id = "w1")) == "http://h/watchlists/w1"
    @test url("http://h", MyDeleteWatchlistEndpointModel(name = "tech")) == "http://h/watchlists:by_name?name=tech"
    # an identifier is escaped in the path -
    @test url("http://h", MyWatchlistEndpointModel(id = "a/b")) == "http://h/watchlists/a%2Fb"
end

@testset "v0.5 watchlists: methods and bodies" begin
    @test Alpaca._http_method(MyWatchlistsEndpointModel()) == "GET"
    @test Alpaca._http_method(MyWatchlistEndpointModel(id = "w1")) == "GET"
    @test Alpaca._http_method(MyCreateWatchlistEndpointModel(name = "tech")) == "POST"
    @test Alpaca._http_method(MyUpdateWatchlistEndpointModel(id = "w1", symbols = ["AAPL"])) == "PUT"
    @test Alpaca._http_method(MyAddWatchlistAssetEndpointModel(id = "w1", symbol = "AAPL")) == "POST"
    @test Alpaca._http_method(MyRemoveWatchlistAssetEndpointModel(id = "w1", symbol = "AAPL")) == "DELETE"
    @test Alpaca._http_method(MyDeleteWatchlistEndpointModel(id = "w1")) == "DELETE"

    @test Alpaca._request_body(MyCreateWatchlistEndpointModel(name = "tech", symbols = ["AAPL"])) ==
          Dict("name" => "tech", "symbols" => ["AAPL"])
    @test Alpaca._request_body(MyCreateWatchlistEndpointModel(name = "tech")) == Dict("name" => "tech", "symbols" => String[])
    @test Alpaca._request_body(MyCreateWatchlistEndpointModel(name = "tech", symbols = "AAPL")) ==
          Dict("name" => "tech", "symbols" => ["AAPL"])
    @test Alpaca._request_body(MyUpdateWatchlistEndpointModel(id = "w1", new_name = "x")) == Dict("name" => "x")
    @test Alpaca._request_body(MyUpdateWatchlistEndpointModel(id = "w1", symbols = ["A", "B"])) == Dict("symbols" => ["A", "B"])
    @test Alpaca._request_body(MyUpdateWatchlistEndpointModel(id = "w1", new_name = "x", symbols = "A")) ==
          Dict("name" => "x", "symbols" => ["A"])
    @test Alpaca._request_body(MyAddWatchlistAssetEndpointModel(id = "w1", symbol = "AAPL")) == Dict("symbol" => "AAPL")
    @test Alpaca._request_body(MyDeleteWatchlistEndpointModel(id = "w1")) === nothing
    @test Alpaca._request_body(MyRemoveWatchlistAssetEndpointModel(id = "w1", symbol = "AAPL")) === nothing
end

@testset "v0.5 watchlists: argument errors" begin
    @test_throws ArgumentError MyWatchlistEndpointModel()
    @test_throws ArgumentError MyWatchlistEndpointModel(id = "w1", name = "tech")
    @test_throws ArgumentError MyUpdateWatchlistEndpointModel(id = "w1")
    @test_throws ArgumentError MyUpdateWatchlistEndpointModel(new_name = "x", symbols = ["A"])
    @test_throws ArgumentError MyUpdateWatchlistEndpointModel(id = "w1", name = "t", new_name = "x")
    @test_throws ArgumentError MyAddWatchlistAssetEndpointModel(symbol = "AAPL")
    @test_throws ArgumentError MyAddWatchlistAssetEndpointModel(id = "w1", name = "t", symbol = "AAPL")
    @test_throws ArgumentError MyDeleteWatchlistEndpointModel()
    @test_throws ArgumentError MyDeleteWatchlistEndpointModel(id = "w1", name = "t")
end

@testset "v0.5 watchlists: tables" begin
    asset_a = """{"id":"a1","class":"us_equity","exchange":"NASDAQ","symbol":"AAPL","name":"Apple","status":"active","tradable":true,"marginable":true,"shortable":true,"easy_to_borrow":true,"fractionable":true}"""
    asset_b = """{"id":"b1","class":"us_equity","exchange":"NYSE","symbol":"IBM","status":"active","tradable":true}"""
    body = """{"id":"w1","account_id":"acc","name":"tech","created_at":"2026-11-20T15:00:00Z","updated_at":"2026-11-20T16:00:00Z","assets":[$asset_a,$asset_b]}"""
    df = Alpaca._watchlist_table(body)
    @test size(df, 1) == 2
    @test names(df)[1:3] == ["watchlist_id", "watchlist_name", "id"]
    @test names(df)[3:end] == names(Alpaca._assets_table(Any[]))
    @test df.watchlist_id == ["w1", "w1"] && df.watchlist_name == ["tech", "tech"]
    @test df.symbol == ["AAPL", "IBM"]
    @test ismissing(df[2, :name])

    # a watchlist with no assets: zero rows, the same columns -
    empty_df = Alpaca._watchlist_table("""{"id":"w1","account_id":"acc","name":"tech","created_at":"2026-11-20T15:00:00Z","updated_at":"2026-11-20T16:00:00Z","assets":[]}""")
    @test size(empty_df, 1) == 0
    @test names(empty_df) == names(df)

    # a missing assets field is also a watchlist with no assets -
    @test size(Alpaca._watchlist_table("""{"id":"w1","name":"tech"}"""), 1) == 0

    # the list of watchlists: one row each, no assets -
    lst = Alpaca._default_handler(MyWatchlistsEndpointModel,
        """[{"id":"w1","account_id":"acc","name":"tech","created_at":"2026-11-20T15:00:00Z","updated_at":"2026-11-20T16:00:00Z"},{"id":"w2","account_id":"acc","name":"energy","created_at":"2026-11-21T15:00:00Z","updated_at":null}]""")
    @test size(lst) == (2, 5)
    @test lst.name == ["tech", "energy"]
    @test lst[1, :created_at] == DateTime(2026, 11, 20, 15)
    @test ismissing(lst[2, :updated_at])

    # each single-watchlist model uses the watchlist table -
    for model_type in (MyWatchlistEndpointModel, MyCreateWatchlistEndpointModel, MyUpdateWatchlistEndpointModel,
                       MyAddWatchlistAssetEndpointModel, MyRemoveWatchlistAssetEndpointModel)
        @test isequal(Alpaca._default_handler(model_type, body), df)
    end
    @test Alpaca._default_handler(MyDeleteWatchlistEndpointModel, "") == DataFrame()
end

@testset "v0.5 watchlists: mock round trips" begin
    # create sends a POST with the JSON body, and returns the watchlist table -
    watchlist = """{"id":"w1","account_id":"acc","name":"tech","created_at":"2026-11-20T15:00:00Z","updated_at":"2026-11-20T15:00:00Z","assets":[{"id":"a1","class":"us_equity","exchange":"NASDAQ","symbol":"AAPL","status":"active"}]}"""
    handler, log = recording_handler(req -> HTTP.Response(200, ["Content-Type" => "application/json"], watchlist))
    with_mock(handler) do client
        df = api(client, MyCreateWatchlistEndpointModel(name = "tech", symbols = ["AAPL"]))
        @test size(df, 1) == 1 && df[1, :symbol] == "AAPL" && df[1, :watchlist_name] == "tech"
        @test length(log.entries) == 1
        req = log.entries[1]
        @test req.method == "POST"
        @test req.target == "/watchlists"
        sent = JSON3.read(req.body)
        @test sent.name == "tech" && collect(sent.symbols) == ["AAPL"]
    end

    # delete answers 204 with no body, and gives an empty table -
    handler, log = recording_handler(req -> HTTP.Response(204))
    with_mock(handler) do client
        df = api(client, MyDeleteWatchlistEndpointModel(id = "w1"))
        @test size(df) == (0, 0)
        @test length(log.entries) == 1
        @test log.entries[1].method == "DELETE"
        @test log.entries[1].target == "/watchlists/w1"
    end
end
