## ADDED Requirements

### Requirement: Single-user authentication
The system SHALL use the Rails 8.1 built-in authentication generator as the foundation (`bin/rails generate authentication`). It SHALL support a single admin user with email/password authentication. There SHALL be no public registration — the user is created via Rails console or seed.

#### Scenario: Successful login
- **WHEN** the user submits correct email and password on the login page
- **THEN** the system SHALL create a session and redirect to the dashboard

#### Scenario: Failed login
- **WHEN** the user submits incorrect credentials
- **THEN** the system SHALL display "Invalid email or password" without revealing which field is wrong, and increment a failed attempt counter

#### Scenario: Brute force protection
- **WHEN** 5 failed login attempts occur within 15 minutes
- **THEN** the system SHALL lock the account for 30 minutes and log the lockout event

### Requirement: Session management
User sessions SHALL have a configurable timeout (default: 24 hours). The system SHALL support "remember me" functionality extending the session to 30 days.

#### Scenario: Session timeout
- **WHEN** a session has been inactive for longer than the configured timeout
- **THEN** the system SHALL invalidate the session and redirect to login on next request

#### Scenario: Remember me
- **WHEN** the user logs in with "remember me" checked
- **THEN** the session SHALL persist for 30 days instead of the default 24-hour timeout

### Requirement: Exchange API key encryption
Exchange API keys and secrets SHALL be encrypted at rest using Rails encrypted credentials or ActiveRecord encryption. Keys SHALL never appear in logs, error messages, or API responses.

#### Scenario: Store API key encrypted
- **WHEN** the user saves Binance API credentials via the dashboard
- **THEN** the system SHALL encrypt the API key and secret before writing to the database, and the plaintext SHALL not be present in any log output

#### Scenario: Decrypt for exchange communication
- **WHEN** an exchange adapter needs to authenticate an API call
- **THEN** the system SHALL decrypt the API key and secret in memory only for the duration of the request

### Requirement: Telegram user verification
The Telegram bot SHALL only respond to messages from the configured admin Telegram user ID. Messages from other users SHALL be ignored.

#### Scenario: Authorized Telegram user
- **WHEN** the configured admin sends `/status` to the Telegram bot
- **THEN** the bot SHALL process the command and reply

#### Scenario: Unauthorized Telegram user
- **WHEN** an unknown Telegram user sends any message to the bot
- **THEN** the bot SHALL ignore the message and log the unauthorized attempt
