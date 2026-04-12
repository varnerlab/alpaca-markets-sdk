using Documenter
using Alpaca

DocMeta.setdocmeta!(Alpaca, :DocTestSetup, :(using Alpaca); recursive = true)

makedocs(;
    modules  = [Alpaca],
    sitename = "Alpaca.jl",
    authors  = "Jeffrey Varner",
    remotes  = nothing,  # flip to a Remotes.GitHub entry once the repo is on GitHub
    format   = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical  = "https://jeffreyvarner.github.io/Alpaca.jl",
        edit_link  = "main",
        assets     = String[],
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

# Uncomment to enable GitHub Pages deployment once the repo lives on GitHub.
#
# deploydocs(;
#     repo      = "github.com/jeffreyvarner/Alpaca.jl.git",
#     devbranch = "main",
#     push_preview = true,
# )
