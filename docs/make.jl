using Documenter
using Alpaca

DocMeta.setdocmeta!(Alpaca, :DocTestSetup, :(using Alpaca); recursive = true)

makedocs(;
    modules  = [Alpaca],
    sitename = "Alpaca.jl",
    authors  = "Jeffrey Varner",
    repo     = "github.com/varnerlab/alpaca-markets-sdk.git",
    format   = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical  = "https://varnerlab.github.io/alpaca-markets-sdk",
        edit_link  = "main",
        assets     = String[],
        repolink   = "https://github.com/varnerlab/alpaca-markets-sdk",
    ),
    pages = [
        "Home"            => "index.md",
        "Getting Started" => "getting_started.md",
        "API Reference"   => [
            "Client"              => "api/client.md",
            "Account"             => "api/account.md",
            "Clock"               => "api/clock.md",
            "Assets"              => "api/assets.md",
            "Orders"              => "api/orders.md",
            "Positions"           => "api/positions.md",
            "Market Data"         => "api/marketdata.md",
            "Historical Downloads" => "api/historical.md",
            "Options"             => "api/options.md",
            "Types"               => "api/types.md",
        ],
    ],
    checkdocs = :exports,
    warnonly  = [:missing_docs],
)

deploydocs(;
    repo         = "github.com/varnerlab/alpaca-markets-sdk.git",
    devbranch    = "main",
    push_preview = true,
)
