## ADDED Requirements

### Requirement: Platform-specific fee schedules
The system SHALL maintain a fee schedule per exchange, stored in the database, containing maker fee rate, taker fee rate, and optional discount information. Fee schedules SHALL be editable via the web dashboard.

#### Scenario: Binance fee schedule
- **WHEN** the system loads the Binance fee schedule
- **THEN** it SHALL contain maker_rate: 0.001 (0.1%), taker_rate: 0.001 (0.1%), with an optional BNB discount reducing rates to 0.00075 (0.075%)

#### Scenario: Indodax fee schedule
- **WHEN** the system loads the Indodax fee schedule
- **THEN** it SHALL contain maker_rate: 0.0 (0%), taker_rate: 0.003 (0.3%)

#### Scenario: Tokocrypto fee schedule
- **WHEN** the system loads the Tokocrypto fee schedule
- **THEN** it SHALL contain maker_rate: 0.001 (0.1%), taker_rate: 0.001 (0.1%), with an optional TKO discount flag

#### Scenario: OANDA spread-only fee schedule
- **WHEN** the system loads the OANDA fee schedule with spread-only pricing
- **THEN** it SHALL contain spread_based: true, commission_per_unit: 0, and typical_spread_pips per instrument (EUR/USD: ~1.1, GBP/USD: ~1.7, XAU/USD: ~25 points, SPX500: ~0.3 points)

#### Scenario: OANDA commission+core fee schedule
- **WHEN** the system loads the OANDA fee schedule with commission+core pricing
- **THEN** it SHALL contain spread_based: true, commission_per_unit as configured, and lower typical_spread_pips reflecting core pricing

#### Scenario: Forex broker fee schedule
- **WHEN** the system loads a forex broker fee schedule (GKInvest, Valbury)
- **THEN** it SHALL contain spread_based: true, commission_per_lot as a decimal, and typical_spread_pips per pair

#### Scenario: Update fee schedule via dashboard
- **WHEN** the admin updates the Binance taker_rate from 0.001 to 0.0012 via the dashboard
- **THEN** the system SHALL persist the change and all subsequent fee calculations SHALL use the new rate

### Requirement: Fee-aware order type determination
The exchange adapter interface SHALL include a method `order_fee_type(order)` that returns whether the order will be charged as maker or taker, based on order type (limit vs market) and exchange rules.

#### Scenario: Market order is taker
- **WHEN** a market buy order is evaluated for fee type on any exchange
- **THEN** the system SHALL classify it as taker and use the taker fee rate

#### Scenario: Limit order is maker
- **WHEN** a limit buy order is placed below current market price
- **THEN** the system SHALL classify it as maker and use the maker fee rate

### Requirement: Round-trip cost estimation
Before every trade execution, the system SHALL calculate the estimated round-trip cost (entry fee + exit fee) based on the exchange's fee schedule, order type, and position size. The estimation SHALL be available to strategies and risk management.

#### Scenario: Calculate round-trip cost for Binance taker
- **WHEN** the system estimates round-trip cost for a BTC/USDT trade of $1,000 on Binance using market orders
- **THEN** the round-trip cost SHALL be $1,000 × 0.001 (entry) + $1,000 × 0.001 (exit) = $2.00

#### Scenario: Calculate round-trip cost for Indodax mixed
- **WHEN** the system estimates round-trip cost for a BTC/IDR trade of Rp10,000,000 on Indodax (buy market, sell limit)
- **THEN** the round-trip cost SHALL be Rp10,000,000 × 0.003 (taker entry) + Rp10,000,000 × 0.0 (maker exit) = Rp30,000

#### Scenario: Calculate OANDA spread-only round-trip cost
- **WHEN** the system estimates round-trip cost for EUR/USD 10,000 units on OANDA with current spread 1.2 pips (spread-only account)
- **THEN** the round-trip cost SHALL be spread in currency: 10,000 × 0.00012 (1.2 pips) = $1.20 (spread is paid once on entry, exit uses the then-current spread which is estimated at the same rate)

#### Scenario: Calculate OANDA gold (XAU/USD) round-trip cost
- **WHEN** the system estimates round-trip cost for XAU/USD 10 units on OANDA with current spread 25 points
- **THEN** the round-trip cost SHALL be 10 × 0.25 (25 points at $0.01 per point per unit) = $2.50

#### Scenario: Calculate forex broker round-trip cost
- **WHEN** the system estimates round-trip cost for EUR/USD 0.1 lot on a forex broker with 1.5 pip spread and $7/lot commission
- **THEN** the round-trip cost SHALL include spread cost ($1.50 per 0.1 lot) + commission ($0.70 per 0.1 lot × 2 for entry+exit) = $2.90

### Requirement: Minimum profit after fees validation
The risk management layer SHALL enforce that the expected profit of a trade (based on entry price and target price) MUST exceed the round-trip fees by a configurable multiplier (default: 1.5×). Trades that fail this check SHALL be rejected.

#### Scenario: Trade rejected due to insufficient profit after fees
- **WHEN** a signal suggests buying at $50,000 with target $50,050 (profit $50) but round-trip fees are $40 and min_profit_multiplier is 1.5
- **THEN** the system SHALL reject the trade because $50 < $40 × 1.5 ($60), with reason "insufficient_profit_after_fees"

#### Scenario: Trade passes fee validation
- **WHEN** a signal suggests buying at $50,000 with target $50,200 (profit $200) and round-trip fees are $40 with min_profit_multiplier 1.5
- **THEN** the system SHALL approve the trade because $200 > $40 × 1.5 ($60)

### Requirement: Actual fee recording
When an order is filled, the system SHALL record the actual fee amount and fee currency as reported by the exchange API response. Actual fees SHALL be used for PnL calculations instead of estimated fees.

#### Scenario: Record actual Binance fee
- **WHEN** Binance reports an order filled with commission: 0.00001 BTC, commissionAsset: "BNB"
- **THEN** the system SHALL store actual_fee_amount: 0.00001, actual_fee_currency: "BNB" on the trade record

#### Scenario: Indodax fee in IDR
- **WHEN** Indodax reports a completed trade with fee deducted from the IDR proceeds
- **THEN** the system SHALL store the fee amount in IDR and use it in net PnL calculation

### Requirement: Fee-aware PnL calculation
All PnL calculations (per trade, per position, per bot, portfolio total) SHALL deduct actual fees. The dashboard SHALL show both gross PnL and net PnL (after fees).

#### Scenario: Net PnL per trade
- **WHEN** a trade bought at $50,000 (fee $5) and sold at $51,000 (fee $5) for 0.1 BTC
- **THEN** gross PnL SHALL be ($51,000 - $50,000) × 0.1 = $100, net PnL SHALL be $100 - $5 - $5 = $90

#### Scenario: Portfolio net PnL
- **WHEN** the dashboard displays portfolio PnL for the day
- **THEN** it SHALL show total_gross_pnl, total_fees, and total_net_pnl separately

### Requirement: Fee schedule per exchange adapter contract
Each exchange adapter SHALL expose a `fee_schedule` method returning the current `FeeSchedule` value object for that exchange. The adapter SHALL also support `fetch_fee_schedule_from_api` to sync with the exchange's API (where available).

#### Scenario: Adapter returns fee schedule
- **WHEN** the system calls `adapter.fee_schedule` on the Binance adapter
- **THEN** it SHALL return a `FeeSchedule` with maker_rate, taker_rate, discount_info, and withdrawal_fees

#### Scenario: Sync fee schedule from exchange API
- **WHEN** the system calls `adapter.fetch_fee_schedule_from_api` on Binance
- **THEN** the adapter SHALL query Binance's trade fee endpoint and update the local fee schedule in the database
