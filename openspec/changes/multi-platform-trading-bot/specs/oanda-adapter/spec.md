## ADDED Requirements

### Requirement: OANDA adapter implementing Exchange::Base interface
The system SHALL include an adapter for OANDA REST v20 API that implements the full Exchange::Base interface. The adapter SHALL support forex pairs (EUR/USD, GBP/USD, USD/JPY, etc.), metals (XAU/USD gold, XAG/USD silver), and indices (SPX500, NAS100, etc.).

#### Scenario: Fetch ticker from OANDA
- **WHEN** the system calls `adapter.fetch_ticker("EUR/USD")` on the OANDA adapter
- **THEN** the adapter SHALL call OANDA's `/v3/accounts/{id}/pricing` endpoint and return a `Ticker` value object with `bid`, `ask`, `last` (mid-price), `volume` (if available), and `timestamp`

#### Scenario: Fetch candles from OANDA
- **WHEN** the system calls `adapter.fetch_candles("XAU/USD", "H1", 100)` on the OANDA adapter
- **THEN** the adapter SHALL call OANDA's `/v3/instruments/{instrument}/candles` endpoint and return an array of `Candle` value objects with OHLCV data using mid/bid/ask prices as configured

### Requirement: OANDA v20 authentication
The OANDA adapter SHALL authenticate using a Bearer token (API key) sent in the Authorization header. The API key SHALL be stored encrypted in the ExchangeCredential model. The adapter SHALL also store the OANDA account ID.

#### Scenario: Authenticated API call
- **WHEN** the adapter makes any API call to OANDA
- **THEN** it SHALL include the header `Authorization: Bearer {api_key}` and use the configured account ID in the URL path

#### Scenario: Authentication failure
- **WHEN** OANDA returns HTTP 401 (unauthorized)
- **THEN** the adapter SHALL raise `Exchange::AuthenticationError` with message indicating invalid or expired API key

### Requirement: OANDA pair format normalization
The OANDA adapter SHALL translate between the system's canonical pair format (e.g., `EUR/USD`, `XAU/USD`) and OANDA's native format (e.g., `EUR_USD`, `XAU_USD` with underscore separator).

#### Scenario: Pair format translation
- **WHEN** the system requests data for pair "EUR/USD"
- **THEN** the OANDA adapter SHALL translate this to `EUR_USD` for API calls and return data using the canonical `EUR/USD` format

#### Scenario: Gold pair normalization
- **WHEN** the system requests data for "XAU/USD" (gold)
- **THEN** the OANDA adapter SHALL translate to `XAU_USD` and handle OANDA's specific precision for metals (2 decimal places for gold)

### Requirement: OANDA order placement
The OANDA adapter SHALL support market orders, limit orders, and stop orders via OANDA's `/v3/accounts/{id}/orders` endpoint. Orders SHALL include units (positive for buy, negative for sell) per OANDA's convention.

#### Scenario: Place a market buy order
- **WHEN** the system calls `place_order(pair: "EUR/USD", side: :buy, type: :market, quantity: 1000)` on the OANDA adapter
- **THEN** the adapter SHALL POST to OANDA's orders endpoint with `{"order": {"type": "MARKET", "instrument": "EUR_USD", "units": "1000"}}` and return an `OrderResult`

#### Scenario: Place a limit order with stop-loss and take-profit
- **WHEN** the system calls `place_order` with type: :limit, price, stop_loss, and take_profit parameters
- **THEN** the adapter SHALL include `stopLossOnFill` and `takeProfitOnFill` in the order request per OANDA v20 format

#### Scenario: Place a gold (XAU/USD) order
- **WHEN** the system places a buy order for XAU/USD with quantity 1 (1 unit = 1 troy ounce)
- **THEN** the adapter SHALL handle OANDA's units convention for metals and submit the order correctly

### Requirement: OANDA balance and position queries
The OANDA adapter SHALL fetch account balance, margin used, unrealized PnL, and open positions via the account endpoints.

#### Scenario: Fetch balance
- **WHEN** the system calls `fetch_balance` on the OANDA adapter
- **THEN** the adapter SHALL call `/v3/accounts/{id}/summary` and return a `Balance` object with `available` (marginAvailable), `total` (balance), and `unrealized_pnl`

#### Scenario: Fetch order status
- **WHEN** the system calls `fetch_order_status(order_id)` on the OANDA adapter
- **THEN** the adapter SHALL call `/v3/accounts/{id}/orders/{order_id}` and return an `OrderStatus` with current state, fill price, and filled quantity

### Requirement: OANDA spread-based fee schedule
The OANDA adapter's `fee_schedule` method SHALL return a spread-based `FeeSchedule` reflecting that OANDA's primary cost is the bid-ask spread. The schedule SHALL include typical spreads per instrument category and whether the account uses spread-only or commission+core-spread pricing.

#### Scenario: Spread-only account fee schedule
- **WHEN** the system calls `adapter.fee_schedule` on an OANDA adapter configured with spread-only pricing
- **THEN** it SHALL return a `FeeSchedule` with `spread_based: true`, `commission_per_unit: 0`, and `typical_spreads: {"EUR/USD": 1.1, "XAU/USD": 25, ...}` in pips/points

#### Scenario: Commission+core account fee schedule
- **WHEN** the system calls `adapter.fee_schedule` on an OANDA adapter configured with commission+core pricing
- **THEN** it SHALL return a `FeeSchedule` with `spread_based: true`, `commission_per_unit: X` (per-unit commission), and lower typical spreads

### Requirement: OANDA streaming prices (optional)
The OANDA adapter MAY implement a streaming price connection via OANDA's `/v3/accounts/{id}/pricing/stream` endpoint for real-time bid/ask updates. This is optional and can fall back to REST polling.

#### Scenario: Stream prices for active pairs
- **WHEN** the system subscribes to streaming prices for EUR/USD and XAU/USD
- **THEN** the adapter SHALL open a persistent HTTP connection to OANDA's streaming endpoint and publish `market_data.updated` events as prices arrive

#### Scenario: Streaming fallback to polling
- **WHEN** the streaming connection fails or is not configured
- **THEN** the adapter SHALL fall back to periodic REST polling via `fetch_ticker` at the configured interval

### Requirement: OANDA demo account support
The OANDA adapter SHALL support connecting to OANDA's practice (demo) environment by toggling the base URL between `api-fxtrade.oanda.com` (live) and `api-fxpractice.oanda.com` (demo).

#### Scenario: Connect to demo environment
- **WHEN** the ExchangeCredential for OANDA has `environment: "practice"`
- **THEN** the adapter SHALL use `api-fxpractice.oanda.com` as the base URL for all API calls

#### Scenario: Connect to live environment
- **WHEN** the ExchangeCredential for OANDA has `environment: "live"`
- **THEN** the adapter SHALL use `api-fxtrade.oanda.com` as the base URL
