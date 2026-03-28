## ADDED Requirements

### Requirement: Dashboard overview
The web dashboard SHALL display a summary overview including: total portfolio value, daily PnL, active bots count, recent trades, and active alerts. The dashboard SHALL auto-refresh using Turbo Streams or periodic polling.

#### Scenario: View dashboard overview
- **WHEN** the authenticated user visits the dashboard root
- **THEN** the page SHALL display portfolio value across all exchanges, today's PnL, number of active/paused bots, and the 10 most recent trades

### Requirement: Bot management interface
The dashboard SHALL provide CRUD operations for bots: create new bot (select exchange, pair, strategy, mode, risk params), edit configuration, start/pause/stop, and delete.

#### Scenario: Create a new bot via dashboard
- **WHEN** the user fills in the new bot form with exchange=Binance, pair=BTC/USDT, strategy=RSI_Reversal, mode=auto, and submits
- **THEN** the system SHALL create the bot record and begin the trading cycle, redirecting to the bot detail page

#### Scenario: Pause bot via dashboard
- **WHEN** the user clicks "Pause" on an active bot
- **THEN** the bot SHALL stop evaluating strategies and the UI SHALL reflect the paused state immediately

### Requirement: Trade history view
The dashboard SHALL display paginated trade history with filters: exchange, pair, date range, side (buy/sell), and PnL positive/negative.

#### Scenario: Filter trades by exchange
- **WHEN** the user selects "Binance" from the exchange filter
- **THEN** the trade list SHALL show only trades executed on Binance, with pagination preserved

### Requirement: Exchange credentials management
The dashboard SHALL provide a secure interface to add, update, and remove exchange API credentials. API secrets SHALL be masked in the UI and stored encrypted.

#### Scenario: Add exchange credentials
- **WHEN** the user adds API key and secret for Binance
- **THEN** the system SHALL encrypt and store the credentials, and the UI SHALL display the API key partially masked (e.g., "abc...xyz") with the secret fully hidden

#### Scenario: Test exchange connection
- **WHEN** the user clicks "Test Connection" for stored credentials
- **THEN** the system SHALL call `fetch_balance` on the adapter and display success or the specific error

### Requirement: Portfolio view
The dashboard SHALL show current positions per exchange with: pair, quantity, entry price, current price, unrealized PnL, and PnL percentage. Balances per exchange SHALL also be visible.

#### Scenario: View positions across exchanges
- **WHEN** the user navigates to the portfolio page
- **THEN** the page SHALL show all open positions grouped by exchange with real-time price updates and PnL calculations

### Requirement: Responsive web design
The dashboard SHALL be responsive and usable on mobile browsers, since the user may check trades from a phone.

#### Scenario: Mobile dashboard access
- **WHEN** the user accesses the dashboard from a mobile browser
- **THEN** all pages SHALL be readable and functional with appropriate layout adjustments (no horizontal scrolling, touch-friendly controls)
