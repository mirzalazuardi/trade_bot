## ADDED Requirements

### Requirement: Uniform exchange adapter interface
All exchange adapters SHALL implement a common interface (`Exchange::Base`) using Ruby duck typing. The interface SHALL include: `fetch_ticker(pair)`, `fetch_candles(pair, interval, limit)`, `fetch_balance`, `place_order(order_params)`, `cancel_order(order_id)`, `fetch_order_status(order_id)`. Each method SHALL return a normalized data object consistent across all adapters.

#### Scenario: Fetch ticker from any exchange
- **WHEN** the system calls `adapter.fetch_ticker("BTC/IDR")` on any adapter (Binance, Indodax, Tokocrypto)
- **THEN** the adapter SHALL return a `Ticker` value object with `bid`, `ask`, `last`, `volume`, and `timestamp` fields, regardless of the underlying exchange's response format

#### Scenario: Adapter responds with normalized error
- **WHEN** an exchange API returns an error (auth failure, rate limit, network timeout)
- **THEN** the adapter SHALL raise a typed exception inheriting from `Exchange::Error` (e.g., `Exchange::AuthenticationError`, `Exchange::RateLimitError`, `Exchange::ConnectionError`)

### Requirement: Binance adapter
The system SHALL include an adapter for Binance REST API that supports spot trading for major crypto pairs (BTC/USDT, ETH/USDT, BTC/IDR equivalents). The adapter SHALL handle Binance's HMAC-SHA256 authentication and timestamp synchronization.

#### Scenario: Place a limit buy order on Binance
- **WHEN** the system calls `place_order(pair: "BTC/USDT", side: :buy, type: :limit, price: 50000, quantity: 0.001)` on the Binance adapter
- **THEN** the adapter SHALL submit the order to Binance's `/api/v3/order` endpoint with proper signature and return an `OrderResult` with `exchange_order_id`, `status`, and `placed_at`

#### Scenario: Binance rate limit handling
- **WHEN** Binance returns HTTP 429 (rate limited)
- **THEN** the adapter SHALL raise `Exchange::RateLimitError` with `retry_after` extracted from response headers

### Requirement: Indodax adapter
The system SHALL include an adapter for Indodax REST API supporting IDR-based crypto trading pairs (BTC/IDR, ETH/IDR). The adapter SHALL handle Indodax's HMAC-SHA512 authentication.

#### Scenario: Fetch balance from Indodax
- **WHEN** the system calls `fetch_balance` on the Indodax adapter
- **THEN** the adapter SHALL return a `Balance` object with available and locked amounts per currency, normalized to the common `Balance` format

#### Scenario: Indodax pair format normalization
- **WHEN** the system requests data for pair "BTC/IDR"
- **THEN** the Indodax adapter SHALL translate this to Indodax's native format (`btc_idr`) internally and return data using the canonical `BTC/IDR` format

### Requirement: Tokocrypto adapter
The system SHALL include an adapter for Tokocrypto REST API supporting IDR-based crypto trading. The adapter SHALL handle Tokocrypto's authentication mechanism.

#### Scenario: Fetch candles from Tokocrypto
- **WHEN** the system calls `fetch_candles("BTC/IDR", "1h", 100)` on the Tokocrypto adapter
- **THEN** the adapter SHALL return an array of `Candle` value objects with `open`, `high`, `low`, `close`, `volume`, and `timestamp` fields

### Requirement: Forex broker adapter interface extension
Forex adapters SHALL extend the base interface with forex-specific methods: `fetch_spread(pair)`, `fetch_leverage_info`, and support for forex-specific order types (market, limit, stop, trailing stop). Forex pairs SHALL use standard notation (e.g., `USD/IDR`, `EUR/USD`).

#### Scenario: Fetch spread for forex pair
- **WHEN** the system calls `fetch_spread("EUR/USD")` on a forex adapter
- **THEN** the adapter SHALL return a `Spread` value object with `bid`, `ask`, `spread_pips`, and `timestamp`

### Requirement: Fee schedule per adapter
Each exchange adapter SHALL expose a `fee_schedule` method returning a `FeeSchedule` value object with the exchange's current fee rates. Adapters that support it SHALL also implement `fetch_fee_schedule_from_api` to sync rates from the exchange.

#### Scenario: Binance adapter reports fees
- **WHEN** the system calls `adapter.fee_schedule` on the Binance adapter
- **THEN** it SHALL return a `FeeSchedule` with maker_rate: 0.001, taker_rate: 0.001, and discount info for BNB payment

#### Scenario: Indodax adapter reports fees
- **WHEN** the system calls `adapter.fee_schedule` on the Indodax adapter
- **THEN** it SHALL return a `FeeSchedule` with maker_rate: 0.0, taker_rate: 0.003

#### Scenario: OANDA adapter reports spread-based fees
- **WHEN** the system calls `adapter.fee_schedule` on the OANDA adapter
- **THEN** it SHALL return a `FeeSchedule` with spread_based: true, typical_spreads per instrument, and commission_per_unit (0 for spread-only, >0 for core pricing)

### Requirement: Exchange adapter registry
The system SHALL maintain a registry of available adapters. New adapters SHALL be registered by name and can be looked up at runtime. The registry SHALL support lazy loading of adapter classes.

#### Scenario: Register and retrieve an adapter
- **WHEN** an adapter class is registered as `Exchange::Registry.register(:binance, Exchange::Binance)`
- **THEN** calling `Exchange::Registry.fetch(:binance)` SHALL return a configured instance of the Binance adapter

#### Scenario: Request unregistered adapter
- **WHEN** the system requests an adapter that is not registered
- **THEN** the registry SHALL raise `Exchange::AdapterNotFoundError` with the requested adapter name
