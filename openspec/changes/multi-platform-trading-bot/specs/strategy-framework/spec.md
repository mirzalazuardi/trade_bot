## ADDED Requirements

### Requirement: Pluggable strategy interface
All strategies SHALL implement a common interface (`Strategy::Base`) with methods: `analyze(market_data)` returning a `Signal`, `required_indicators` returning an array of indicator symbols, and `params` returning a hash of configurable parameters.

#### Scenario: Strategy produces a buy signal
- **WHEN** `analyze` is called with market data where RSI is below 30 and MACD crosses above signal line
- **THEN** the strategy SHALL return a `Signal` with `type: :buy`, `confidence: 0.0..1.0`, `reason: "RSI oversold + MACD bullish cross"`, and `suggested_price`

#### Scenario: Strategy produces a hold signal
- **WHEN** no clear entry or exit conditions are met
- **THEN** the strategy SHALL return a `Signal` with `type: :hold` and `confidence: 0.0`

### Requirement: Technical indicator library
The system SHALL provide a library of common technical indicators as composable, pure-function modules. Each indicator SHALL accept candle data and parameters, returning computed values.

#### Scenario: Calculate RSI
- **WHEN** the system computes RSI with period 14 on 100 candles
- **THEN** the indicator SHALL return an array of RSI values (0-100) for each candle where computation is possible

#### Scenario: Calculate MACD
- **WHEN** the system computes MACD with fast=12, slow=26, signal=9
- **THEN** the indicator SHALL return `macd_line`, `signal_line`, and `histogram` arrays

#### Scenario: Calculate Bollinger Bands
- **WHEN** the system computes Bollinger Bands with period=20, std_dev=2
- **THEN** the indicator SHALL return `upper_band`, `middle_band`, and `lower_band` arrays

### Requirement: Strategy parameter configuration
Strategy parameters SHALL be configurable per bot instance. Default parameters SHALL be defined in the strategy class, but each bot MAY override them.

#### Scenario: Override strategy parameters
- **WHEN** a bot is configured with strategy RSI_Reversal and custom params `{ period: 21, oversold: 25, overbought: 75 }`
- **THEN** the strategy SHALL use the custom parameters instead of defaults when analyzing market data

### Requirement: Strategy registration
Strategies SHALL be registered in a strategy registry by name. New strategies SHALL be discoverable at runtime for bot configuration.

#### Scenario: Register a custom strategy
- **WHEN** a new strategy class `Strategy::MACDCrossover` is defined and registered
- **THEN** it SHALL appear in the list of available strategies and be selectable when configuring a bot

### Requirement: Multi-timeframe data access
Strategies SHALL be able to request market data across multiple timeframes (e.g., use 1h candles for trend, 15m for entry timing).

#### Scenario: Strategy uses multiple timeframes
- **WHEN** a strategy declares `required_timeframes: ["1h", "15m"]`
- **THEN** the system SHALL provide both timeframe datasets to the strategy's `analyze` method
