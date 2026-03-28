## ADDED Requirements

### Requirement: Order lifecycle tracking
The system SHALL track every order through its full lifecycle: `pending` → `submitted` → `open` → `partially_filled` → `filled` / `cancelled` / `failed`. Each state transition SHALL be timestamped and logged.

#### Scenario: Order state transitions
- **WHEN** an order is placed and the exchange confirms it as open
- **THEN** the system SHALL update the order record from `submitted` to `open` with the exchange confirmation timestamp

#### Scenario: Partial fill tracking
- **WHEN** an exchange reports a partial fill (e.g., 0.5 of 1.0 BTC filled)
- **THEN** the system SHALL update the order's `filled_quantity`, `remaining_quantity`, and `average_fill_price`, and set status to `partially_filled`

### Requirement: Order synchronization
The system SHALL periodically check open orders on exchanges to detect fills, cancellations, or expirations that may have been missed (e.g., due to network issues).

#### Scenario: Detect missed fill
- **WHEN** the sync job checks an order marked as `open` and the exchange reports it as `filled`
- **THEN** the system SHALL update the order to `filled`, record the fill details, and publish `order.filled` event

### Requirement: Position tracking with fee-aware PnL
The system SHALL maintain aggregate position data per exchange and pair, calculated from filled orders. Positions SHALL show entry price, current quantity, gross PnL, total fees paid, and net PnL (gross minus fees). Both unrealized and realized PnL SHALL account for estimated exit fees.

#### Scenario: Calculate position from orders with fees
- **WHEN** the system has two filled buy orders for BTC/USDT on Binance (0.5 @ 50000 with fee $5, 0.3 @ 51000 with fee $3.06) and one sell (0.2 @ 52000 with fee $2.08)
- **THEN** the position SHALL show: quantity=0.6, average_entry=50375, gross_realized_pnl=$325, total_fees=$10.14, net_realized_pnl=$314.86, and unrealized_pnl SHALL account for estimated exit fee at current taker rate

#### Scenario: Unrealized PnL includes estimated exit fee
- **WHEN** the dashboard displays unrealized PnL for an open BTC/USDT position on Binance
- **THEN** the unrealized PnL SHALL be calculated as: (current_price - avg_entry) × quantity - estimated_exit_fee, where estimated_exit_fee uses the exchange's taker rate

### Requirement: Order creation validation
Before submitting an order to an exchange, the system SHALL validate: minimum order size, price within reasonable range (e.g., not 10x market price), sufficient balance, and pair availability on the target exchange.

#### Scenario: Reject order below minimum size
- **WHEN** the system attempts to place an order for 0.00001 BTC on Binance where minimum is 0.0001
- **THEN** the system SHALL reject the order with reason "below_minimum_size" without contacting the exchange

#### Scenario: Reject order with insufficient balance
- **WHEN** the system attempts a buy order requiring 1000 USDT but available balance is 500 USDT
- **THEN** the system SHALL reject the order with reason "insufficient_balance"

### Requirement: Trade history with comprehensive fee data
The system SHALL maintain a complete trade history with: order details, fill prices, estimated fees (pre-trade), actual fees (post-trade from exchange), gross PnL, net PnL, exchange, pair, strategy that generated the signal, ml_confidence (if AI was enabled), and timestamps.

#### Scenario: Record trade with actual fees from exchange
- **WHEN** an order is fully filled and the exchange reports actual fees
- **THEN** the system SHALL record the trade with gross_amount, estimated_fee (from pre-trade calculation), actual_fee_amount, actual_fee_currency, and net_amount (gross - actual_fee)

#### Scenario: Trade record includes ML data
- **WHEN** an AI-enhanced trade completes
- **THEN** the trade record SHALL include ml_model_id, ml_confidence_score, and ml_position_size_adjustment for performance tracking
