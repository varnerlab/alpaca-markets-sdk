# Alpaca REST endpoint inventory (2026-11-21)

Source: Alpaca's OpenAPI specs, downloaded 2026-11-21 from docs.alpaca.markets/openapi/{trading-api,market-data-api}.json. Gathered for the 0.5.0 full-coverage plan.


The source is Alpaca's own OpenAPI specs, downloaded on 2026-11-21. Every path below comes from these specs.

- `https://docs.alpaca.markets/openapi/trading-api.json` (OpenAPI 3.1.2, "Trading API" version 2.0.1, 58 operations, sha256 `325dd61b…`)
- `https://docs.alpaca.markets/openapi/market-data-api.json` (OpenAPI 3.1.2, "Market Data API" version 1.1, 49 operations, sha256 `f96ca5fb…`)

The docs reference index (`https://docs.alpaca.markets/llms.txt`) lists the same operations, one for one, for both APIs.

## Trading API

Host: `https://paper-api.alpaca.markets` (paper) or `https://api.alpaca.markets` (live). Paths are shown from the host root.

### Account

| Method | Path | Operation (operationId: summary) | Notes |
|---|---|---|---|
| GET | `/v2/account` | getAccount: Get Account | |

### Account configurations

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/account/configurations` | getAccountConfig: Get Account Configurations | |
| PATCH | `/v2/account/configurations` | patchAccountConfig: Account Configurations | |

### Account activities

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/account/activities` | getAccountActivities: Retrieve Account Activities | query: `activity_types`, `category` (`trade_activity`/`non_trade_activity`), `order_id`, `date`, `until`, `after`, `direction`, `page_size`, `page_token` |
| GET | `/v2/account/activities/{activity_type}` | getAccountActivitiesByActivityType: Retrieve Account Activities of Specific Type | the `activity_type` enum has 59 codes (see the footnote) |

### Portfolio history

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/account/portfolio/history` | getAccountPortfolioHistory: Get Account Portfolio History | `timeframe` is limited to `1Min`/`5Min`/`15Min`/`1H`/`1D` (Oct 2026); also `period`, `start`, `end`, `intraday_reporting`, `pnl_reset`, `extended_hours`, `cashflow_types` |

### Orders

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/orders` | getAllOrders: Get All Orders | the `asset_class` filter enum includes `us_equity`, `us_option`, `crypto`, `crypto_perp`, `treasury`, `corporate`, `global_equity`, `us_index`, `us_equity_chain`, `ipo`, `all` |
| POST | `/v2/orders` | postOrder: Create an Order | |
| DELETE | `/v2/orders` | deleteAllOrders: Delete All Orders | 207 response with one result per order |
| GET | `/v2/orders/{order_id}` | getOrderByOrderID: Get Order by ID | query: `nested` |
| PATCH | `/v2/orders/{order_id}` | patchOrderByOrderId: Replace Order by ID | |
| DELETE | `/v2/orders/{order_id}` | deleteOrderByOrderID: Delete Order by ID | |
| GET | `/v2/orders:by_client_order_id` | getOrderByClientOrderId: Get Order by Client Order ID | query: `client_order_id` (required); the path contains a literal colon |

### Positions (including option exercise)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/positions` | getAllOpenPositions: All Open Positions | |
| DELETE | `/v2/positions` | deleteAllOpenPositions: Close All Positions | query: `cancel_orders`; 207 response with one result per position |
| GET | `/v2/positions/{symbol_or_asset_id}` | getOpenPosition: Get an Open Position | |
| DELETE | `/v2/positions/{symbol_or_asset_id}` | deleteOpenPosition: Close a Position | query: `qty` or `percentage` |
| POST | `/v2/positions/{symbol_or_contract_id}/exercise` | optionExercise: Exercise an Options Position | options only |
| POST | `/v2/positions/{symbol_or_contract_id}/do-not-exercise` | optionDoNotExercise: Do Not Exercise an Options Position | options only |

### Assets

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/assets` | get-v2-assets: Get Assets | query: `status`, `asset_class`, `exchange` (comma list), `attributes` |
| GET | `/v2/assets/{symbol_or_asset_id}` | get-v2-assets-symbol_or_asset_id: Get an Asset by ID or Symbol | URL-encode crypto pairs, for example `BTC%2FUSDT` |

### Option contracts (tagged "Assets" in the spec)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/options/contracts` | get-options-contracts: Get Option Contracts | by default returns active contracts that expire before the coming weekend; paginated with `page_token` |
| GET | `/v2/options/contracts/{symbol_or_id}` | get-option-contract-symbol_or_id: Get an option contract by ID or Symbol | |

### Watchlists

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/watchlists` | getWatchlists: Get All Watchlists | |
| POST | `/v2/watchlists` | postWatchlist: Create Watchlist | |
| GET | `/v2/watchlists/{watchlist_id}` | getWatchlistById: Get Watchlist by ID | |
| PUT | `/v2/watchlists/{watchlist_id}` | updateWatchlistById: Update Watchlist By Id | |
| POST | `/v2/watchlists/{watchlist_id}` | addAssetToWatchlist: Add Asset to Watchlist | |
| DELETE | `/v2/watchlists/{watchlist_id}` | deleteWatchlistById: Delete Watchlist By Id | |
| DELETE | `/v2/watchlists/{watchlist_id}/{symbol}` | removeAssetFromWatchlist: Delete Symbol from Watchlist | the spec has no by-name version of this operation |
| GET | `/v2/watchlists:by_name` | getWatchlistByName: Get Watchlist by Name | query: `name` (required) |
| PUT | `/v2/watchlists:by_name` | updateWatchlistByName: Update Watchlist By Name | query: `name` |
| POST | `/v2/watchlists:by_name` | addAssetToWatchlistByName: Add Asset to Watchlist By Name | query: `name` |
| DELETE | `/v2/watchlists:by_name` | deleteWatchlistByName: Delete Watchlist By Name | query: `name` |

### Calendar and clock

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/calendar` | LegacyCalendar: Get US Market Calendar | query: `start`, `end`, `date_type` (`TRADING`/`SETTLEMENT`); the operationId says "Legacy", but the spec does not mark it deprecated |
| GET | `/v2/clock` | LegacyClock: Get US Market Clock | the operationId says "Legacy", not marked deprecated |
| GET | `/v3/calendar/{market}` | Calendar: Get Market Calendar | `market` enum has 32 values: BMO, BNYM, BOATS, CEUX, CHIX, HKEX, IEX, IEXG, ISE, LSE, MTA, MTAA, NASDAQ, NYSE, OCEA, OPRA, OTC, OTCM, SIFMA, TADAWUL, XAMS, XBRU, XDUB, XETR, XETRA, XHKG, XLIS, XLON, XNAS, XNYS, XPAR, XSAU; query: `start`, `end`, `timezone` |
| GET | `/v3/clock` | Clock: Get Market Clock | query: `markets`, `time`; multi-market |

### Corporate actions announcements

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/corporate_actions/announcements` | get-v2-corporate_actions-announcements: Retrieve Announcements | **deprecated** in the spec; use the Market Data `/v1/corporate-actions` endpoint instead. Required: `ca_types`, `since`, `until` |
| GET | `/v2/corporate_actions/announcements/{id}` | get-v2-corporate_actions-announcements-id: Retrieve a Specific Announcement | **deprecated** |

### Crypto funding (wallets, transfers, whitelisted addresses, travel rule)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/wallets` | listCryptoFundingWallets: Retrieve Crypto Funding Wallets | query: `asset`, `chain`, `network`; creates the wallet if `asset` is given and none exists |
| GET | `/v2/wallets/fees/estimate` | getCryptoTransferEstimate: Returns the estimated gas fee for a proposed transaction | query: `asset`, `from_address`, `to_address`, `amount` |
| GET | `/v2/wallets/transfers` | listCryptoFundingTransfers: Retrieve Crypto Funding Transfers | |
| GET | `/v2/wallets/transfers/{transfer_id}` | getCryptoFundingTransfer: Retrieve a Crypto Funding Transfer | |
| GET | `/v2/wallets/travel-rule/vasps` | searchVASPs: Search for VASPs | Notabene directory search (added Sept 2026) |
| GET | `/v2/wallets/whitelists` | listWhitelistedAddress: An array of whitelisted addresses | |
| POST | `/v2/wallets/whitelists` | createWhitelistedAddress: Request a new whitelisted address | |
| DELETE | `/v2/wallets/whitelists/{whitelisted_address_id}` | deleteWhitelistedAddress: Delete a whitelisted address | |
| PATCH | `/v2/wallets/whitelists/{whitelisted_address_id}/travel-rule-info` | updateWhitelistedAddressTravelRuleInfo: Update travel rule information for a whitelisted wallet | added Sept 2026 |

`POST /v2/wallets/transfers` (createCryptoTransferForAccount, "Request a New Withdrawal") is **no longer in the spec**. The Sept 2026 spec marked it deprecated ("Use the Alpaca web application to initiate withdrawals"), and the Oct 2026 spec dropped it.

### Tokenization (Instant Tokenization Network, for Authorized Participants only)

| Method | Path | Operation | Notes |
|---|---|---|---|
| POST | `/v2/tokenization/mint` | postTokenizationMint: Mint a Tokenized Asset | `Idempotency-Key` header |
| GET | `/v2/tokenization/requests` | getTokenizationRequests: List Tokenization Requests | |
| GET | `/v2/tokenization/requests/{tokenization_request_id}` | getTokenizationRequest: Get Tokenization Request by ID | |
| GET | `/v2/tokenization/requests:by_client_request_id` | getTokenizationRequestByClientRequestID: Get Tokenization Request by `client_request_id` | |

### Locates (short-sale locates; the spec says these are not available in paper trading)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1/locates` | listLocates: List Locates | live only |
| POST | `/v1/locates` | createLocates: Create Locate | live only; `Idempotency-Key` header |
| GET | `/v1/locates/{locate_id}` | getLocate: Get Locate | live only |
| GET | `/v1/locates/quotes` | listLocateQuotes: Get Locate Quotes | live only; query: `symbols` (required) |

### Events (server-sent events)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2beta1/events/activities` | subscribeToActivitiesSSE: Subscribe to Activity Events (SSE) | beta path; `text/event-stream`; query: `since`, `until`, `since_id`, `until_id` |

### Crypto perpetuals and fixed-income asset lists: not in the current spec

The current spec has no crypto perpetuals endpoints. The perpetuals operations below appeared in the spec through the 2026-06-24 sync, all tagged "(Beta)", and were gone by the 2026-08-24 sync. I could not verify whether they still answer.

| Method | Path | Former operationId |
|---|---|---|
| GET | `/v2/perpetuals/account_vitals` | getCryptoPerpAccountVitals |
| GET | `/v2/perpetuals/leverage` | getCryptoPerpAccountLeverage |
| POST | `/v2/perpetuals/leverage` | setCryptoPerpAccountLeverage |
| GET | `/v2/perpetuals/wallets` | listCryptoPerpFundingWallets |
| GET | `/v2/perpetuals/wallets/fees/estimate` | getCryptoPerpTransferEstimate |
| GET | `/v2/perpetuals/wallets/transfers` | listCryptoPerpFundingTransfers |
| POST | `/v2/perpetuals/wallets/transfers` | createCryptoPerpTransferForAccount |
| GET | `/v2/perpetuals/wallets/transfers/{transfer_id}` | getCryptoPerpFundingTransfer |
| GET | `/v2/perpetuals/wallets/whitelists` | listWhitelistedPerpAddress |
| POST | `/v2/perpetuals/wallets/whitelists` | createWhitelistedPerpAddress |
| DELETE | `/v2/perpetuals/wallets/whitelists/{whitelisted_address_id}` | deleteWhitelistedPerpAddress |
| GET | `/v2/assets/fixed_income/us_corporates` | UsCorporates (now documented only in the Broker API) |
| GET | `/v2/assets/fixed_income/us_treasuries` | UsTreasuries |

## Market Data API

Host: `https://data.alpaca.markets` (production) or `https://data.sandbox.alpaca.markets` (sandbox). The one exception is the corporate-actions SSE endpoint, which runs on `https://stream.data.alpaca.markets` (sandbox: `https://stream.data.sandbox.alpaca.markets`). All endpoints are GET.

### Stocks, US (v2): multi-symbol

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/stocks/bars` | StockBars: Historical bars | `feed` = `iex`/`otc`/`sip`/`boats`; `adjustment` = comma list of `raw`/`split`/`dividend`/`spin-off`/`all`; also `asof`, `currency`, `page_token`, `sort` |
| GET | `/v2/stocks/bars/latest` | StockLatestBars: Latest bars | latest `feed` adds `delayed_sip` and `overnight` |
| GET | `/v2/stocks/quotes` | StockQuotes: Historical quotes | |
| GET | `/v2/stocks/quotes/latest` | StockLatestQuotes: Latest quotes | |
| GET | `/v2/stocks/trades` | StockTrades: Historical trades | |
| GET | `/v2/stocks/trades/latest` | StockLatestTrades: Latest trades | |
| GET | `/v2/stocks/snapshots` | StockSnapshots: Snapshots | |
| GET | `/v2/stocks/auctions` | StockAuctions: Historical auctions | only `sip` is valid for `feed` |

### Stocks, US (v2): single symbol

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/stocks/{symbol}/bars` | StockBarSingle: Historical bars (single symbol) | |
| GET | `/v2/stocks/{symbol}/bars/latest` | StockLatestBarSingle: Latest bar (single symbol) | |
| GET | `/v2/stocks/{symbol}/quotes` | StockQuoteSingle: Historical quotes (single symbol) | |
| GET | `/v2/stocks/{symbol}/quotes/latest` | StockLatestQuoteSingle: Latest quote (single symbol) | |
| GET | `/v2/stocks/{symbol}/trades` | StockTradeSingle: Historical trades (single symbol) | |
| GET | `/v2/stocks/{symbol}/trades/latest` | StockLatestTradeSingle: Latest trade (single symbol) | |
| GET | `/v2/stocks/{symbol}/snapshot` | StockSnapshotSingle: Snapshot (single symbol) | singular `snapshot` |
| GET | `/v2/stocks/{symbol}/auctions` | StockAuctionSingle: Historical auctions (single) | |

### Stocks, US (v2): metadata

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v2/stocks/meta/conditions/{ticktype}` | StockMetaConditions: Condition codes | `ticktype` = `trade`/`quote`; query `tape` = `A`/`B`/`C` (required) |
| GET | `/v2/stocks/meta/exchanges` | StockMetaExchanges: Exchange codes | |

The spec has no other stock "meta" endpoints.

### Stocks, non-US (v3); new since the 2026-11-04 MCP sync

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v3/stocks/{feed}/bars` | StockV3Bars: Historical bars | `feed` = `euroctp`/`xetr`/`xhkg`/`xlon`/`xsau`; `start` required; `page_size` (not `limit`); bars are unadjusted |
| GET | `/v3/stocks/{feed}/quotes` | StockV3Quotes: Historical quotes | `start` required |
| GET | `/v3/stocks/{feed}/trades` | StockV3Trades: Historical trades | `start` required |
| GET | `/v3/stocks/{feed}/latest/bars` | StockV3LatestBars: Latest bars | |
| GET | `/v3/stocks/{feed}/latest/quotes` | StockV3LatestQuotes: Latest quotes | |
| GET | `/v3/stocks/{feed}/latest/trades` | StockV3LatestTrades: Latest trades | |
| GET | `/v3/stocks/{feed}/snapshots` | StockV3Snapshots: Snapshots | symbols take the form `SYMBOL:MIC`, for example `SAP:XETR` (from the stream docs) |

### Options (v1beta1)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta1/options/bars` | optionBars: Historical bars | the operationId starts with a lowercase "o" |
| GET | `/v1beta1/options/trades` | OptionTrades: Historical trades | |
| GET | `/v1beta1/options/trades/latest` | OptionLatestTrades: Latest trades | `feed` = `opra`/`indicative` |
| GET | `/v1beta1/options/quotes/latest` | OptionLatestQuotes: Latest quotes | the spec has no historical option quotes endpoint |
| GET | `/v1beta1/options/snapshots` | OptionSnapshots: Snapshots | latest trade, latest quote, and greeks |
| GET | `/v1beta1/options/snapshots/{underlying_symbol}` | OptionChain: Option chain | filters: `type`, strike range, expiration range, `root_symbol`, `updated_since` |
| GET | `/v1beta1/options/meta/exchanges` | OptionMetaExchanges: Exchange codes | |
| GET | `/v1beta1/options/meta/conditions/{ticktype}` | OptionMetaConditions: Condition codes | `ticktype` = `trade`/`quote` |

### Crypto spot (v1beta3)

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta3/crypto/{loc}/bars` | CryptoBars: Historical bars | the `loc` enum is `us`/`us-1`/`us-2`/`eu-1`/`bs-1`, but the description defines only `us` (Alpaca), `us-1` (Kraken US), and `eu-1` (Kraken EU) |
| GET | `/v1beta3/crypto/{loc}/quotes` | CryptoQuotes: Historical quotes | `us-1` quote history starts 2025-10-14 |
| GET | `/v1beta3/crypto/{loc}/trades` | CryptoTrades: Historical trades | |
| GET | `/v1beta3/crypto/{loc}/latest/bars` | CryptoLatestBars: Latest bars | |
| GET | `/v1beta3/crypto/{loc}/latest/quotes` | CryptoLatestQuotes: Latest quotes | |
| GET | `/v1beta3/crypto/{loc}/latest/trades` | CryptoLatestTrades: Latest trades | |
| GET | `/v1beta3/crypto/{loc}/latest/orderbooks` | CryptoLatestOrderbooks: Latest orderbook | |
| GET | `/v1beta3/crypto/{loc}/snapshots` | CryptoSnapshots: Snapshots | |

### News

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta1/news` | News: News articles | query: `start`, `end`, `sort`, `symbols`, `limit`, `include_content`, `exclude_contentless`, `page_token` |

### Screener

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta1/screener/stocks/most-actives` | MostActives: Most active stocks | `by` = `volume`/`trades`; `top` |
| GET | `/v1beta1/screener/{market_type}/movers` | Movers: Top market movers | `market_type` = `stocks`/`crypto`; `top` |

### Corporate actions

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1/corporate-actions` | CorporateActions: Corporate actions | query: `symbols`, `cusips`, `types`, `region`, `start`, `end`, `ids`, `limit`, `data_quality` (`complete`/`all`, new Aug 2026), `page_token`, `sort` |
| GET | `/v1beta1/events/corporate-actions` | SubscribeToCorporateActionsEventsSSE: Subscribe to Corporate Actions Events (SSE) | host `stream.data.alpaca.markets`; SSE; filters `type` (16 event types), `region`, `since`/`until`/`since_id`/`until_id`; supports the `Last-Event-Id` header |

### Logos

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta1/logos/{symbol}` | Logos: Logos | returns `image/png`; query: `placeholder` |

### Fixed income

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/v1beta1/fixed_income/latest/prices` | FixedIncomeLatestPrices: Latest prices | `isins` required |
| GET | `/v1beta1/fixed_income/latest/quotes` | FixedIncomeLatestQuotes: Latest quotes | `isins` required; `trade_size` |

### Removed from the Market Data spec in 2026 (unverified whether they still answer)

| Method | Path | Former operationId | Dropped in sync |
|---|---|---|---|
| GET | `/v1beta1/forex/latest/rates` | LatestRates | late Oct 2026 (2026-10-26) |
| GET | `/v1beta1/forex/rates` | Rates | late Oct 2026 |
| GET | `/v1beta1/crypto-perps/{loc}/latest/bars` | CryptoPerpLatestBars (`loc` = `global`) | Aug 2026 |
| GET | `/v1beta1/crypto-perps/{loc}/latest/quotes` | CryptoPerpLatestQuotes | Aug 2026 |
| GET | `/v1beta1/crypto-perps/{loc}/latest/trades` | CryptoPerpLatestTrades | Aug 2026 |
| GET | `/v1beta1/crypto-perps/{loc}/latest/orderbooks` | CryptoPerpLatestOrderbooks | Aug 2026 |
| GET | `/v1beta1/crypto-perps/{loc}/latest/pricing` | CryptoPerpLatestFuturesPricing | Aug 2026 |
| GET | `/v1beta1/indices/values` | IndexValues | Aug 2026 |
| GET | `/v1beta1/indices/latest/values` | IndexLatestValues | Aug 2026 |

The current docs have no forex, crypto-perps, or indices pages. The Go SDK (`alpaca-trade-api-go` v3, HEAD 2026-11-16) still has a `v1beta1/crypto-perps` REST prefix and a perps stream.

## Streaming feeds

| Feed | URL | Channels and notes |
|---|---|---|
| Trade updates (orders and account) | `wss://paper-api.alpaca.markets/stream`, `wss://api.alpaca.markets/stream` | `listen` to `trade_updates`; JSON or MessagePack; the paper stream sends binary frames |
| Account activities (SSE) | `GET {trading host}/v2beta1/events/activities` | listed in the Trading API tables above |
| Stocks, US | `wss://stream.data.alpaca.markets/{v2/sip, v2/iex, v2/delayed_sip, v1beta1/boats, v1beta1/overnight}` | `trades`, `quotes`, `bars`, `updatedBars`, `dailyBars`, `statuses`, `lulds`, `imbalances`; `corrections` and `cancelErrors` come automatically with `trades` |
| Test stream | `wss://stream.data.alpaca.markets/v2/test` | symbol `FAKEPACA`; available at all hours |
| Stocks, non-US (v3) | `wss://stream.data.alpaca.markets/v3/stocks/{euroctp, xetr, xhkg, xlon, xsau}` | `trades`, `quotes`, `bars`, `updatedBars`, `dailyBars` |
| Crypto spot | `wss://stream.data.alpaca.markets/v1beta3/crypto/{loc}` | the docs list `loc` = `us`, `us-1`, `eu-1`; `trades`, `quotes`, `bars`, `updatedBars`, `dailyBars`, `orderbooks` |
| Options | `wss://stream.data.alpaca.markets/v1beta1/{indicative, opra}` | MessagePack only; `trades`, `quotes` (`*` is not allowed for quotes) |
| News | `wss://stream.data.alpaca.markets/v1beta1/news` | `news` |
| Corporate actions (SSE) | `https://stream.data.alpaca.markets/v1beta1/events/corporate-actions` | listed in the Market Data tables above |
| Crypto perps (unverified) | `wss://stream.data.alpaca.markets/v1beta1/crypto-perps/global` | appears only in Go SDK tests, not in the current docs |

Every market data stream also has a sandbox host, `stream.data.sandbox.alpaca.markets`.

## Official alpaca-mcp-server

- Version **2.4.1**, released 2026-11-04 on GitHub and PyPI. The main branch HEAD is `9daa38c` (2026-11-13), a Docker image fix only.
- The server is generated from vendored copies of the two specs above, using `FastMCP.from_openapi`. `scripts/sync-specs.sh` downloads the specs from `docs.alpaca.markets/openapi/*.json` and rewrites the OpenAPI version from 3.1.2 to 3.1.1. A per-toolset operationId allowlist (`toolsets.py`) decides which operations become tools. `tool_registry.py` renames them. Tests assert exactly **72 tools**.
- The vendored specs date from 2026-11-04. They differ from today's docs only by the 7 `/v3/stocks/{feed}/…` endpoints.
- The `ALPACA_TOOLSETS` variable selects among 11 toolsets: `account`, `trading`, `watchlists`, `assets`, `stock-data`, `crypto-data`, `options-data`, `corporate-actions`, `news`, `fixed-income-data`, `locates`.

The 72 tools, with their operationIds:

- **account (6):** `get_account_info` (getAccount), `get_account_config`, `update_account_config`, `get_portfolio_history`, `get_account_activities`, `get_account_activities_by_type`
- **trading, orders (6):** `get_orders`, `get_order_by_id`, `get_order_by_client_id`, `replace_order_by_id`, `cancel_order_by_id`, `cancel_all_orders`
- **trading, positions (6):** `get_all_positions`, `get_open_position`, `close_position`, `close_all_positions`, `exercise_options_position`, `do_not_exercise_options_position`
- **order placement, hand-written in place of postOrder (3):** `place_stock_order`, `place_crypto_order`, `place_option_order`
- **watchlists, by ID only (7):** `get_watchlists`, `create_watchlist`, `get_watchlist_by_id`, `update_watchlist_by_id`, `delete_watchlist_by_id`, `add_asset_to_watchlist_by_id`, `remove_asset_from_watchlist_by_id`
- **assets (8):** `get_all_assets`, `get_asset`, `get_option_contracts`, `get_option_contract`, `get_calendar` (v2 LegacyCalendar), `get_clock` (v2 LegacyClock), `get_corporate_action_announcements`, `get_corporate_action_announcement` (the last two use the deprecated v2 endpoints)
- **stock-data (9):** `get_stock_bars`, `get_stock_quotes`, `get_stock_trades` (all three hand-written), `get_stock_latest_bar`, `get_stock_latest_quote`, `get_stock_latest_trade`, `get_stock_snapshot` (these four map to the multi-symbol endpoints), `get_most_active_stocks`, `get_market_movers`
- **crypto-data (8):** `get_crypto_bars`, `get_crypto_quotes`, `get_crypto_trades` (all three hand-written, with `loc` fixed to `us`), `get_crypto_latest_bar`, `get_crypto_latest_quote`, `get_crypto_latest_trade`, `get_crypto_snapshot`, `get_crypto_latest_orderbook`
- **options-data (7):** `get_option_bars`, `get_option_trades`, `get_option_latest_trade`, `get_option_latest_quote`, `get_option_snapshot`, `get_option_chain`, `get_option_exchange_codes`
- **corporate-actions (1):** `get_corporate_actions` (v1)
- **news (1):** `get_news`
- **fixed-income-data (1):** `get_fixed_income_latest_quotes`
- **locates (4):** `get_locates`, `create_locate`, `get_locate`, `get_locate_quotes`
- **ReadMe docs proxy (5):** `search_alpaca_docs`, `fetch_alpaca_doc`, `search_alpaca_api_specs`, `list_alpaca_api_endpoints`, `get_alpaca_endpoint_docs`

The official server has no tool for 42 of the 107 spec operations. That count leaves out postOrder, which the 3 `place_*` tools cover. The 42 operations without a tool are:

- **Trading:** the 4 `watchlists:by_name` operations, `/v3/calendar/{market}`, `/v3/clock`, all 9 crypto funding operations, all 4 tokenization operations, and `/v2beta1/events/activities`.
- **Market Data:** `/v2/stocks/auctions`, all 8 `/v2/stocks/{symbol}/…` single-symbol operations, both stock meta operations, all 7 v3 stock operations, option meta conditions, fixed income latest prices, logos, and the corporate-actions SSE.

## Sources and caveats

- **Source for every table:** the live OpenAPI specs from `docs.alpaca.markets/openapi/{trading-api,market-data-api}.json`, downloaded 2026-11-21. I cross-checked them against the `docs.alpaca.markets/llms.txt` reference index, and the two match one for one.
- **Source for the "removed" tables:** the spec history vendored in `alpacahq/alpaca-mcp-server`, with syncs on 2026-03-23, 06-05, 06-24, 08-24, 09-25, 10-12, 10-26, and 11-04, plus that repo's PR notes.
- **Source for streaming:** the docs pages `websocket-streaming`, `streaming-market-data`, `real-time-stock-pricing-data`, `real-time-stock-data-v3`, `real-time-crypto-pricing-data`, `real-time-option-data`, and `streaming-real-time-news`.
- **Not verified:** whether the removed endpoints (perps, forex, indices, fixed-income asset lists, `POST /v2/wallets/transfers`) still respond. Unauthenticated probes return 401 for every path, including made-up ones, so they cannot tell a live route from a dead one. Settling the question needs an authenticated call.
- **Not verified:** what the crypto `loc` values `us-2` and `bs-1` mean. They appear in the REST enum but not in any description or in the stream docs.
- **Paper availability:** the spec says only the locates endpoints are unavailable in paper. It says nothing about paper support for crypto funding, tokenization, or events.
- **SDK spot-check:** alpaca-py (HEAD 2026-11-20) calls a subset of these paths and nothing outside the current spec. The Go SDK still references crypto-perps, `/v2/assets/fixed_income/*`, and `/v2/events/trades`, which is a Broker API path.

Footnote, `activity_type` enum (59 codes): ACATC ACATS ALLOC CFEE CGD CIL CSD CSR CSW DIV DIVCGL DIVCGS DIVFEE DIVFT DIVNRA DIVROC DIVTW DIVTXEX DIVWH DVF ECEXP EXTRD FEE FIMAT FXCNV FXTRD INT INTNRA INTTW INVPNL JNL JNLC JNLS MA MEM NC OCT OPASN OPCA OPCSH OPEXC OPEXP OPTRD PTC PTR REO REORG SC SPIN SPLIT SUB SWP TRD VOF WH FOPT FILL MISC TRANS.

## Appendix: parameters of the endpoints added in 0.5.0

`*` marks a required parameter. `(q)` query, `(p)` path. BODY lists the JSON body fields.

```text
GET /v2/account/configurations :: 
PATCH /v2/account/configurations :: BODY{disable_overnight_trading:boolean, fractional_trading:boolean, max_margin_multiplier:string, max_options_trading_level:integer enum=0|1|2|3, no_shorting:boolean, ptp_no_exception_entry:boolean, suspend_trade:boolean, trade_confirm_email:string}
GET /v2/account/activities :: activity_types(q):array<string enum=ACATC|ACATS|ALLOC|CFEE|CGD|CIL|CSD|CSR|CSW|DIV|DIVCGL|DIVCGS|DIVFEE|DIVFT|DIVNRA|DIVROC|DIVTW|DIVTXEX|DIVWH|DVF|ECEXP|EXTRD|FEE|FIMAT|FXCNV|FXTRD|INT|INTNRA|INTTW|INVPNL|JNL|JNLC|JNLS|MA|MEM|NC|OCT|OPASN|OPCA|OPCSH|OPEXC|OPEXP|OPTRD|PTC|PTR|REO|REORG|SC|SPIN|SPLIT|SUB|SWP|TRD|VOF|WH|FOPT|FILL|MISC|TRANS>; category(q):string enum=trade_activity|non_trade_activity; order_id(q):string; date(q):string; until(q):string; after(q):string; direction(q):string enum=asc|desc default=desc; page_size(q):integer default=100 max=100; page_token(q):string
GET /v2/account/activities/{activity_type} :: activity_type(p*):string enum=ACATC|ACATS|ALLOC|CFEE|CGD|CIL|CSD|CSR|CSW|DIV|DIVCGL|DIVCGS|DIVFEE|DIVFT|DIVNRA|DIVROC|DIVTW|DIVTXEX|DIVWH|DVF|ECEXP|EXTRD|FEE|FIMAT|FXCNV|FXTRD|INT|INTNRA|INTTW|INVPNL|JNL|JNLC|JNLS|MA|MEM|NC|OCT|OPASN|OPCA|OPCSH|OPEXC|OPEXP|OPTRD|PTC|PTR|REO|REORG|SC|SPIN|SPLIT|SUB|SWP|TRD|VOF|WH|FOPT|FILL|MISC|TRANS; order_id(q):string; date(q):string; until(q):string; after(q):string; direction(q):string enum=asc|desc default=desc; page_size(q):integer default=100 max=100; page_token(q):string
GET /v2/account/portfolio/history :: period(q):string; timeframe(q):string enum=1D|1H|15Min|5Min|1Min; intraday_reporting(q):string enum=market_hours|extended_hours|continuous default=market_hours; start(q):string; pnl_reset(q):string enum=no_reset|per_day default=per_day; end(q):string; extended_hours(q):string; cashflow_types(q):string
DELETE /v2/orders/{order_id} :: order_id(p*):string
GET /v2/orders/{order_id} :: order_id(p*):string; nested(q):boolean
PATCH /v2/orders/{order_id} :: order_id(p*):string; BODY{advanced_instructions:object, client_order_id:string, limit_price:string, notional:string, qty:string, stop_price:string, time_in_force:string enum=day|gtc|opg|cls|ioc|fok, trail:string}
POST /v2/positions/{symbol_or_contract_id}/exercise :: symbol_or_contract_id(p*):string
POST /v2/positions/{symbol_or_contract_id}/do-not-exercise :: symbol_or_contract_id(p*):string
GET /v2/watchlists :: 
POST /v2/watchlists :: BODY{name*:string, symbols:array<string>}
DELETE /v2/watchlists/{watchlist_id} :: watchlist_id(p*):string
GET /v2/watchlists/{watchlist_id} :: watchlist_id(p*):string
POST /v2/watchlists/{watchlist_id} :: watchlist_id(p*):string; BODY{symbol:string}
PUT /v2/watchlists/{watchlist_id} :: watchlist_id(p*):string; BODY{name:string, symbols:array<string>}
DELETE /v2/watchlists/{watchlist_id}/{symbol} :: watchlist_id(p*):string; symbol(p*):string
DELETE /v2/watchlists:by_name :: name(q*):string
GET /v2/watchlists:by_name :: name(q*):string
POST /v2/watchlists:by_name :: name(q*):string; BODY{symbol:string}
PUT /v2/watchlists:by_name :: name(q*):string; BODY{name:string, symbols:array<string>}
GET /v3/calendar/{market} :: market(p*):string enum=BMO|BNYM|BOATS|CEUX|CHIX|HKEX|IEX|IEXG|ISE|LSE|MTA|MTAA|NASDAQ|NYSE|OCEA|OPRA|OTC|OTCM|SIFMA|TADAWUL|XAMS|XBRU|XDUB|XETR|XETRA|XHKG|XLIS|XLON|XNAS|XNYS|XPAR|XSAU; start(q):string; end(q):string; timezone(q):string enum=UTC
GET /v3/clock :: markets(q):string; time(q):string
POST /v2/orders :: BODY{advanced_instructions:object, client_order_id:string, extended_hours:boolean, legs:array<object>, limit_price:string, notional:string, order_class:string enum=simple|bracket|oco|oto|mleg|, position_intent:string enum=buy_to_open|buy_to_close|sell_to_open|sell_to_close, qty:string, side:string enum=buy|sell, stop_loss:object, stop_price:string, symbol:string, take_profit:object, time_in_force*:string enum=day|gtc|opg|cls|ioc|fok, trail_percent:string, trail_price:string, type*:string enum=market|limit|stop|stop_limit|trailing_stop}
GET /v2/stocks/bars/latest :: symbols(q*):string; feed(q):string enum=delayed_sip|iex|otc|sip|boats|overnight; currency(q):string
GET /v2/stocks/quotes/latest :: symbols(q*):string; feed(q):string enum=delayed_sip|iex|otc|sip|boats|overnight; currency(q):string
GET /v2/stocks/trades/latest :: symbols(q*):string; feed(q):string enum=delayed_sip|iex|otc|sip|boats|overnight; currency(q):string
GET /v2/stocks/auctions :: symbols(q*):string; start(q):string; end(q):string; limit(q):integer default=1000 max=10000; asof(q):string; feed(q):string default=sip; currency(q):string; page_token(q):string; sort(q):
GET /v2/stocks/meta/conditions/{ticktype} :: ticktype(p*):string enum=trade|quote; tape(q*):string enum=A|B|C
GET /v2/stocks/meta/exchanges :: 
GET /v3/stocks/{feed}/bars :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string; timeframe(q*):string; start(q*):; end(q):; sort(q):; page_size(q):integer default=1000 max=10000; page_token(q):string
GET /v3/stocks/{feed}/quotes :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string; start(q*):; end(q):; sort(q):; page_size(q):integer default=1000 max=10000; page_token(q):string
GET /v3/stocks/{feed}/trades :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string; start(q*):; end(q):; sort(q):; page_size(q):integer default=1000 max=10000; page_token(q):string
GET /v3/stocks/{feed}/latest/bars :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string
GET /v3/stocks/{feed}/latest/quotes :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string
GET /v3/stocks/{feed}/latest/trades :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string
GET /v3/stocks/{feed}/snapshots :: feed(p*):string enum=euroctp|xetr|xhkg|xlon|xsau; symbols(q*):string
GET /v1beta1/options/meta/exchanges :: 
GET /v1beta1/options/meta/conditions/{ticktype} :: ticktype(p*):string enum=trade|quote
GET /v1beta3/crypto/{loc}/bars :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string; timeframe(q*):string; start(q):string; end(q):string; limit(q):integer default=1000 max=10000; page_token(q):string; sort(q):
GET /v1beta3/crypto/{loc}/quotes :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string; start(q):string; end(q):string; limit(q):integer default=1000 max=10000; page_token(q):string; sort(q):
GET /v1beta3/crypto/{loc}/trades :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string; start(q):string; end(q):string; limit(q):integer default=1000 max=10000; page_token(q):string; sort(q):
GET /v1beta3/crypto/{loc}/latest/bars :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string
GET /v1beta3/crypto/{loc}/latest/quotes :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string
GET /v1beta3/crypto/{loc}/latest/trades :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string
GET /v1beta3/crypto/{loc}/latest/orderbooks :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string
GET /v1beta3/crypto/{loc}/snapshots :: loc(p*):string enum=us|us-1|us-2|eu-1|bs-1; symbols(q*):string
GET /v1beta1/news :: start(q):string; end(q):string; sort(q):string enum=asc|desc default=desc; symbols(q):string; limit(q):integer max=50; include_content(q):boolean; exclude_contentless(q):boolean; page_token(q):string
GET /v1beta1/screener/stocks/most-actives :: by(q):string enum=volume|trades default=volume; top(q):integer default=10 max=100
GET /v1beta1/screener/{market_type}/movers :: market_type(p*):string enum=stocks|crypto; top(q):integer default=10 max=50
GET /v1/corporate-actions :: symbols(q):string; cusips(q):string; types(q):string; region(q):string enum=us|non_us|all default=us; start(q):string; end(q):string; ids(q):string; limit(q):integer default=100 max=1000; data_quality(q):string enum=complete|all default=complete; page_token(q):string; sort(q):
GET /v1beta1/logos/{symbol} :: symbol(p*):string; placeholder(q):boolean default=True
GET /v1beta1/fixed_income/latest/prices :: isins(q*):string
GET /v1beta1/fixed_income/latest/quotes :: isins(q*):string; trade_size(q):integer
```
