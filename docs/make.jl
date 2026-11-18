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
            "Client"        => "api/client.md",
            "Models"        => "api/models.md",
            "Reading data"  => "api/reading.md",
            "Trading"       => "api/trading.md",
            "Streaming"     => "api/streaming.md",
            "Types"         => "api/types.md",
            "Legacy API"    => "api/legacy.md",
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
