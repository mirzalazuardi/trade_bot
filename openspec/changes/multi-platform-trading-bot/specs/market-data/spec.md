## ADDED Requirements

### Requirement: Candle data collection
The system SHALL periodically collect OHLCV (Open, High, Low, Close, Volume) candlestick data from all configured exchanges and pairs. Collection intervals SHALL be configurable per pair (1m, 5m, 15m, 1h, 4h, 1d).

#### Scenario: Scheduled candle collection
- **WHEN** the collection interval timer fires for pair "BTC/USDT" on Binance with interval "1h"
- **THEN** the system SHALL fetch the latest candles from the exchange adapter and persist them to the `candles` table with `exchange`, `pair`, `interval`, `open`, `high`, `low`, `close`, `volume`, and `timestamp`

#### Scenario: Duplicate candle prevention
- **WHEN** the system attempts to store a candle that already exists (same exchange + pair + interval + timestamp)
- **THEN** the system SHALL skip the insert without raising an error (upsert behavior)

### Requirement: Ticker data collection
The system SHALL collect current ticker data (bid, ask, last price, volume) for monitored pairs. Ticker data SHALL be used for real-time price display and signal evaluation.

#### Scenario: Ticker poll
- **WHEN** the ticker poll job runs for a configured exchange and pair
- **THEN** the system SHALL fetch the current ticker via the exchange adapter and store it in the `tickers` table with timestamp

### Requirement: Market data normalization
All market data SHALL be stored in a normalized format regardless of source exchange. Prices SHALL be stored as decimals with sufficient precision (at least 8 decimal places for crypto, 5 for forex).

#### Scenario: Price precision for crypto
- **WHEN** Binance returns a BTC price of "50123.45678901"
- **THEN** the system SHALL store this as a decimal with at least 8 decimal places without floating-point rounding errors

#### Scenario: Price precision for forex
- **WHEN** a forex broker returns EUR/USD at "1.08765"
- **THEN** the system SHALL store this as a decimal with at least 5 decimal places (pip precision)

### Requirement: Data retention policy
The system SHALL enforce a configurable data retention policy to manage disk usage on budget VPS. Old candle data beyond the retention period SHALL be automatically pruned.

#### Scenario: Auto-prune old candles
- **WHEN** the daily maintenance job runs and 1-minute candles older than 30 days exist
- **THEN** the system SHALL delete candles older than the configured retention period for each interval (e.g., 30 days for 1m, 90 days for 5m, unlimited for 1d)

### Requirement: Market data query interface
The system SHALL provide a query interface for retrieving historical candle data with filtering by exchange, pair, interval, and time range. The interface SHALL be used by strategies and the web dashboard.

#### Scenario: Query candles for strategy
- **WHEN** a strategy requests the last 100 hourly candles for "BTC/USDT" on Binance
- **THEN** the system SHALL return an ordered array of `Candle` objects from newest to oldest, fetched from the database
