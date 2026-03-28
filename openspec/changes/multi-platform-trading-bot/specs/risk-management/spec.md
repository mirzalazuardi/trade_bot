## ADDED Requirements

### Requirement: Pre-trade risk checks
Before every order execution, the system SHALL run configurable risk checks. If any check fails, the order SHALL be blocked and a `risk.violation` event published.

#### Scenario: Position size limit
- **WHEN** a bot attempts to place an order that would result in a position exceeding the configured max position size (e.g., max 5% of portfolio per pair)
- **THEN** the risk manager SHALL block the order with reason "max_position_size_exceeded"

#### Scenario: All checks pass
- **WHEN** a bot attempts to place an order that passes all risk checks
- **THEN** the risk manager SHALL return approval and the order SHALL proceed to execution

### Requirement: Daily loss limit
The system SHALL enforce a configurable daily loss limit per bot and globally. Once the limit is reached, the bot SHALL be automatically paused until the next trading day.

#### Scenario: Daily loss limit reached
- **WHEN** a bot's realized losses for the day reach the configured daily limit (e.g., -2% of portfolio)
- **THEN** the system SHALL pause the bot, publish `risk.violation` event with type "daily_loss_limit", and send notification

#### Scenario: Daily loss limit reset
- **WHEN** a new trading day begins (00:00 WIB)
- **THEN** the daily loss counter SHALL reset and paused bots with only daily-limit violations SHALL resume if still marked active

### Requirement: Stop-loss enforcement
The system SHALL support configurable stop-loss per position. When the price reaches the stop-loss level, a market sell order SHALL be placed automatically regardless of bot mode (auto or semi-auto).

#### Scenario: Stop-loss triggered
- **WHEN** the current price of BTC/USDT drops to or below the configured stop-loss price for an open position
- **THEN** the system SHALL immediately place a market sell order for the full position quantity, bypassing any approval requirements

### Requirement: Maximum open orders limit
The system SHALL enforce a maximum number of concurrent open orders per bot and globally to prevent runaway order creation.

#### Scenario: Max open orders reached
- **WHEN** a bot has 5 open orders (configured max) and attempts to place another
- **THEN** the risk manager SHALL block the new order with reason "max_open_orders_exceeded"

### Requirement: Exposure limit per exchange
The system SHALL enforce a maximum capital exposure per exchange to limit counterparty risk.

#### Scenario: Exchange exposure limit
- **WHEN** the total value of positions and open orders on Binance reaches the configured exchange limit (e.g., 50% of total portfolio)
- **THEN** the risk manager SHALL block new orders on Binance with reason "exchange_exposure_limit"

### Requirement: Minimum profit after fees check
The pre-trade risk check SHALL include a fee-aware profitability check. The expected profit from entry to target MUST exceed the round-trip fees (entry + exit) multiplied by a configurable minimum profit multiplier (default: 1.5×).

#### Scenario: Trade rejected — fees eat the profit
- **WHEN** a bot on Indodax (taker 0.3%) attempts a trade with entry Rp800,000,000, target Rp802,000,000, quantity 0.01 BTC — expected profit Rp20,000 but round-trip taker fees = Rp48,000
- **THEN** the risk manager SHALL block the trade with reason "insufficient_profit_after_fees" because Rp20,000 < Rp48,000 × 1.5

#### Scenario: Trade approved — profit exceeds fee threshold
- **WHEN** a bot on Binance (taker 0.1%) attempts a trade with entry $50,000, target $50,500, quantity 0.1 BTC — expected profit $50 and round-trip fees = $10
- **THEN** the risk manager SHALL approve because $50 > $10 × 1.5 ($15)

### Requirement: Risk configuration
Risk parameters SHALL be configurable at both global and per-bot levels. Per-bot settings SHALL override global defaults. Parameters include: max position size, daily loss limit, stop-loss, max open orders, exchange exposure limits, and min_profit_fee_multiplier.

#### Scenario: Bot-specific risk override
- **WHEN** global max position size is 5% but a specific bot is configured with 3%
- **THEN** the 3% limit SHALL apply to that bot while other bots use the 5% default
