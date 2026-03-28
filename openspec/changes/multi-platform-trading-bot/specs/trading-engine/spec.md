## ADDED Requirements

### Requirement: Trading engine orchestration
The trading engine SHALL orchestrate the full trading cycle: receive market data → evaluate strategies → check risk → execute or request approval → manage orders. Each step SHALL be a separate service object with a single responsibility.

#### Scenario: Full automated trade cycle
- **WHEN** new market data arrives for a pair with an active automated bot
- **THEN** the engine SHALL: (1) pass data to the strategy, (2) if signal is buy/sell and bot has ai_enabled, run ML inference for confidence scoring, (3) run pre-trade risk check including fee validation, (4) if all checks pass, place order via exchange adapter, (5) publish `order.placed` event

#### Scenario: Semi-automated trade cycle
- **WHEN** new market data arrives for a pair with a semi-automated bot and the strategy generates a buy/sell signal
- **THEN** the engine SHALL: (1) create a pending approval record, (2) publish `approval.requested` event, (3) wait for user approval via Telegram before executing

### Requirement: AI-enhanced signal processing
When a bot has `ai_enabled: true`, the trading engine SHALL pass the strategy signal through the ML inference pipeline before risk checks. The ML model acts as a meta-labeler: it determines confidence (position sizing and act/skip decision), NOT direction.

#### Scenario: AI enhances signal with high confidence
- **WHEN** a strategy produces a buy signal on a bot with `ai_enabled: true` and the ML model returns confidence 0.85
- **THEN** the engine SHALL proceed with the trade at full position size as determined by risk management

#### Scenario: AI filters out low-confidence signal
- **WHEN** a strategy produces a buy signal on a bot with `ai_enabled: true` and the ML model returns confidence 0.2
- **THEN** the engine SHALL skip the signal, publish `signal.ml_filtered` event, and log the filtering reason

#### Scenario: AI disabled falls through to normal flow
- **WHEN** a strategy produces a buy signal on a bot with `ai_enabled: false`
- **THEN** the engine SHALL skip ML inference entirely and proceed with the normal risk check → execution flow

### Requirement: Bot configuration
Each bot instance SHALL be configurable with: exchange, trading pair, strategy, execution mode (auto/semi-auto), ai_enabled flag, ml_model reference, ML confidence thresholds, position size rules, and active/paused status. Multiple bots SHALL run concurrently for different pairs and exchanges.

#### Scenario: Create a new bot
- **WHEN** the user creates a bot with exchange: Binance, pair: BTC/USDT, strategy: RSI_Reversal, mode: auto
- **THEN** the system SHALL create a `Bot` record and begin evaluating the strategy on each market data update for that pair

#### Scenario: Pause a running bot
- **WHEN** the user pauses an active bot
- **THEN** the bot SHALL stop evaluating strategies and placing new orders, but SHALL continue monitoring existing open orders

### Requirement: Execution mode switching
A bot SHALL support switching between automated and semi-automated modes at runtime without restarting.

#### Scenario: Switch from auto to semi-auto
- **WHEN** the user switches a bot from automated to semi-automated mode
- **THEN** all subsequent signals SHALL require Telegram approval before execution, and existing open orders SHALL continue to be monitored normally

### Requirement: Concurrent bot execution
The system SHALL support running multiple bots concurrently across different exchanges and pairs. Each bot SHALL operate independently without blocking others.

#### Scenario: Multiple bots running
- **WHEN** 5 bots are configured (3 crypto, 2 forex) across different exchanges
- **THEN** each bot SHALL have its own evaluation cycle via Solid Queue jobs, and a failure in one bot SHALL NOT affect the others

### Requirement: Engine event publishing
The trading engine SHALL publish events via ActiveSupport::Notifications for all significant state changes. Other components (notifications, dashboard, risk manager) SHALL subscribe without the engine having direct knowledge of subscribers.

#### Scenario: Signal generated event
- **WHEN** a strategy produces a buy signal with confidence 0.85
- **THEN** the engine SHALL publish `signal.generated` with payload including bot_id, pair, signal_type, confidence, strategy_name, ml_confidence (if ai_enabled), estimated_fees, and timestamp

#### Scenario: Order execution event
- **WHEN** an order is successfully placed on the exchange
- **THEN** the engine SHALL publish `order.placed` with payload including bot_id, exchange_order_id, pair, side, type, price, quantity
