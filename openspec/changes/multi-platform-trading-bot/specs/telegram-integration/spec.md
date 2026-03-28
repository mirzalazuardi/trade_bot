## ADDED Requirements

### Requirement: Telegram bot notifications
The system SHALL send Telegram messages for significant events: trade executed, signal generated (semi-auto), risk violation, bot errors, and daily summary. Messages SHALL be formatted with Markdown for readability.

#### Scenario: Trade execution notification
- **WHEN** an order is filled on Binance for BTC/USDT
- **THEN** the system SHALL send a Telegram message: "✅ *BUY filled* BTC/USDT @ 50,000\nQty: 0.001 | Total: $50\nExchange: Binance | Bot: RSI_Bot_1"

#### Scenario: Risk violation alert
- **WHEN** a risk check blocks an order due to daily loss limit
- **THEN** the system SHALL send a Telegram message: "⚠️ *Risk Violation* Daily loss limit reached\nBot: RSI_Bot_1 paused\nLoss today: -2.1%"

### Requirement: Trade approval via Telegram
In semi-automated mode, the system SHALL send trade proposals to Telegram with inline keyboard buttons for Approve/Reject. The user SHALL have a configurable timeout (default: 5 minutes) to respond before the signal expires.

#### Scenario: Approve trade via Telegram
- **WHEN** a semi-auto bot generates a buy signal and sends approval request
- **THEN** the Telegram message SHALL include signal details and inline buttons [✅ Approve] [❌ Reject], and pressing Approve SHALL trigger order execution

#### Scenario: Approval timeout
- **WHEN** the user does not respond to an approval request within the configured timeout
- **THEN** the system SHALL mark the signal as expired and send a follow-up message "⏰ Signal expired: BTC/USDT buy"

### Requirement: Telegram command interface
The Telegram bot SHALL support commands for quick status checks and basic bot control.

#### Scenario: Status command
- **WHEN** the user sends `/status` to the Telegram bot
- **THEN** the bot SHALL reply with: number of active bots, total portfolio value, today's PnL, and any active alerts

#### Scenario: Balance command
- **WHEN** the user sends `/balance` to the Telegram bot
- **THEN** the bot SHALL reply with available balances per exchange

#### Scenario: Bots list command
- **WHEN** the user sends `/bots` to the Telegram bot
- **THEN** the bot SHALL reply with a list of all bots showing name, exchange, pair, mode, and status (active/paused)

### Requirement: Telegram webhook mode
The Telegram bot SHALL operate in webhook mode (not long-polling) to minimize resource usage. The webhook endpoint SHALL be part of the Rails application.

#### Scenario: Receive webhook update
- **WHEN** Telegram sends a webhook POST to the bot's endpoint
- **THEN** the Rails controller SHALL authenticate the request, parse the update, and route to the appropriate command handler

### Requirement: Daily summary report
The system SHALL send a daily summary via Telegram at a configurable time (default: 21:00 WIB) with: total PnL, number of trades, best/worst performing pair, and portfolio value.

#### Scenario: Daily summary at scheduled time
- **WHEN** the clock reaches 21:00 WIB
- **THEN** the system SHALL compile the day's statistics and send a formatted summary message via Telegram
