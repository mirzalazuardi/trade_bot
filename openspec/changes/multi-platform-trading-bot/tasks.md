## 1. Project Setup & Foundation

- [x] 1.1 Initialize Rails 8.1 app with PostgreSQL (`rails new trade_bot --database=postgresql --css=tailwind`)
- [x] 1.2 Verify Solid Queue, Solid Cache, and Solid Cable are configured as defaults (Rails 8.1 ships these out of the box)
- [x] 1.3 Configure Kamal 2 deployment (`config/deploy.yml`) targeting budget VPS — single container with Puma + Solid Queue in-process
- [x] 1.4 Configure database.yml for budget VPS PostgreSQL (connection pool sizing, statement timeout)
- [x] 1.5 Configure Puma for budget VPS: 2 workers / 2 threads for 2GB VPS, or 1 worker / 2-3 threads for 1GB VPS
- [x] 1.6 Set up Rails encrypted credentials structure for exchange API keys and Telegram bot token
- [x] 1.7 Add gems: telegram-bot-ruby (or equivalent), faraday for HTTP, chartkick for dashboard charts, lightgbm and/or onnxruntime for ML inference
- [x] 1.8 Create base application layout with Tailwind CSS (responsive)

## 2. User Authentication

- [x] 2.1 Run Rails 8.1 authentication generator (`bin/rails generate authentication`) — scaffolds User model, SessionsController, Current attributes, password reset
- [x] 2.2 Add failed_attempts and locked_until columns to User model migration
- [x] 2.3 Implement brute force protection (lock after 5 failed attempts for 30 minutes)
- [x] 2.4 Implement session timeout (24h default) and "remember me" (30 days) functionality
- [x] 2.5 Create seed task for initial admin user creation
- [x] 2.6 Add before_action authentication filter to ApplicationController (verify generated scaffold covers this)

## 3. Exchange Adapter Foundation

- [x] 3.1 Create Exchange::Base module defining the adapter interface contract (fetch_ticker, fetch_candles, fetch_balance, place_order, cancel_order, fetch_order_status, fee_schedule)
- [x] 3.2 Create Exchange::Error hierarchy (AuthenticationError, RateLimitError, ConnectionError, InsufficientBalanceError, InvalidOrderError)
- [x] 3.3 Create value objects: Ticker, Candle, Balance, OrderResult, CancelResult, OrderStatus, FeeSchedule
- [x] 3.4 Create Exchange::Registry for adapter registration and lookup
- [x] 3.5 Implement HTTP client wrapper with retry logic, exponential backoff, and rate limit handling

## 4. Binance Adapter

- [x] 4.1 Implement Exchange::Binance adapter with HMAC-SHA256 authentication
- [x] 4.2 Implement fetch_ticker for Binance (GET /api/v3/ticker/24hr)
- [x] 4.3 Implement fetch_candles for Binance (GET /api/v3/klines)
- [x] 4.4 Implement fetch_balance for Binance (GET /api/v3/account)
- [x] 4.5 Implement place_order for Binance (POST /api/v3/order) — limit and market orders
- [x] 4.6 Implement cancel_order and fetch_order_status for Binance
- [x] 4.7 Handle Binance-specific pair format normalization (BTCUSDT ↔ BTC/USDT)
- [x] 4.8 Implement fee_schedule for Binance (maker: 0.1%, taker: 0.1%, BNB discount: 0.075%)
- [x] 4.9 Implement fetch_fee_schedule_from_api for Binance to sync fee tiers
- [ ] 4.10 Write tests for Binance adapter with VCR/WebMock cassettes

## 5. Indodax Adapter

- [x] 5.1 Implement Exchange::Indodax adapter with HMAC-SHA512 authentication
- [x] 5.2 Implement fetch_ticker, fetch_candles, fetch_balance for Indodax
- [x] 5.3 Implement place_order, cancel_order, fetch_order_status for Indodax
- [x] 5.4 Handle Indodax pair format normalization (btc_idr ↔ BTC/IDR)
- [x] 5.5 Implement fee_schedule for Indodax (maker: 0%, taker: 0.3%, withdrawal: Rp10,000 flat)
- [ ] 5.6 Write tests for Indodax adapter

## 6. Tokocrypto Adapter

- [x] 6.1 Implement Exchange::Tokocrypto adapter with authentication
- [x] 6.2 Implement all Exchange::Base interface methods for Tokocrypto
- [x] 6.3 Handle Tokocrypto pair format normalization
- [x] 6.4 Implement fee_schedule for Tokocrypto (maker: 0.1%, taker: 0.1% flat, TKO discount flag)
- [ ] 6.5 Write tests for Tokocrypto adapter

## 7. OANDA Adapter (Forex, Gold/Metals, Indices)

- [x] 7.1 Implement Exchange::Oanda adapter with Bearer token authentication and account ID configuration
- [x] 7.2 Implement environment switching (practice: api-fxpractice.oanda.com, live: api-fxtrade.oanda.com)
- [x] 7.3 Implement fetch_ticker via OANDA /v3/accounts/{id}/pricing endpoint
- [x] 7.4 Implement fetch_candles via OANDA /v3/instruments/{instrument}/candles endpoint
- [x] 7.5 Implement fetch_balance via OANDA /v3/accounts/{id}/summary (balance, marginAvailable, unrealizedPL)
- [x] 7.6 Implement place_order via OANDA /v3/accounts/{id}/orders — market, limit, stop orders with optional stopLossOnFill/takeProfitOnFill
- [x] 7.7 Implement cancel_order and fetch_order_status for OANDA
- [x] 7.8 Handle OANDA pair format normalization (EUR/USD ↔ EUR_USD, XAU/USD ↔ XAU_USD)
- [x] 7.9 Implement fee_schedule returning spread-based FeeSchedule (spread-only or commission+core pricing)
- [x] 7.10 Implement optional streaming prices via /v3/accounts/{id}/pricing/stream with fallback to REST polling
- [ ] 7.11 Write tests for OANDA adapter with VCR/WebMock cassettes (use practice API for recording)

## 8. Exchange Credentials Management

- [x] 8.1 Create ExchangeCredential model with encrypted api_key and api_secret (ActiveRecord Encryption), plus optional fields: account_id (for OANDA), environment (practice/live)
- [x] 8.2 Create ExchangeCredentialsController with CRUD actions
- [x] 8.3 Create views for managing credentials (add, edit, delete, test connection) — OANDA form includes account_id and environment toggle
- [x] 8.4 Implement "Test Connection" feature that calls fetch_balance on the adapter
- [x] 8.5 Ensure API secrets are masked in all UI displays and never logged

## 9. Market Data Collection

- [x] 9.1 Create Candle model with exchange, pair, interval, open, high, low, close, volume, timestamp (decimal precision 8+ for crypto, 5 for forex)
- [x] 9.2 Create Ticker model for current price snapshots
- [x] 9.3 Add unique index on candles (exchange, pair, interval, timestamp) for upsert behavior
- [x] 9.4 Implement MarketData::CandleCollectorJob — Solid Queue recurring job per pair/interval, with `discard_on Exchange::RateLimitError` for graceful handling
- [x] 9.5 Implement MarketData::TickerCollectorJob — Solid Queue recurring job per pair, with `discard_on` for transient API errors
- [x] 9.6 Create MarketData::QueryService for retrieving historical candles (filter by exchange, pair, interval, time range)
- [ ] 9.7 Implement data retention job (prune 1m candles >30 days, 5m >90 days)
- [x] 9.8 Create MonitoredPair model to configure which pairs to track on which exchanges

## 10. Technical Indicators Library

- [x] 10.1 Create Indicators::RSI module — pure function, accepts candles + period, returns RSI array
- [x] 10.2 Create Indicators::MACD module — accepts candles + fast/slow/signal periods, returns macd_line/signal_line/histogram
- [x] 10.3 Create Indicators::BollingerBands module — accepts candles + period + std_dev, returns upper/middle/lower bands
- [x] 10.4 Create Indicators::MovingAverage module — SMA and EMA calculations
- [ ] 10.5 Write comprehensive tests for each indicator with known expected outputs

## 11. Fee Management

- [x] 11.1 Create FeeSchedule value object (maker_rate, taker_rate, discount_info, spread_based flag, commission_per_unit, typical_spreads hash)
- [x] 11.2 Create ExchangeFee model for persisting fee schedules per exchange (editable via dashboard)
- [x] 11.3 Create FeeCalculator service — computes estimated fee for an order given exchange, order type (maker/taker), and amount. Handles both percentage-based (crypto) and spread-based (OANDA/forex) fee models.
- [x] 11.4 Implement round_trip_cost calculation (entry fee + exit fee estimate based on target price) — for spread-based: use current spread from ticker
- [x] 11.5 Implement fee-type determination logic (market order → taker, limit order that adds liquidity → maker; OANDA: always spread-based)
- [x] 11.6 Seed default fee schedules for Binance (0.1%/0.1% + BNB discount), Indodax (0%/0.3%), Tokocrypto (0.1%/0.1%), OANDA (spread-only: EUR/USD ~1.1 pips, XAU/USD ~25 points)
- [x] 11.7 Create fee schedule management views in dashboard (view, edit per exchange)
- [x] 11.8 Implement fee sync job — calls fetch_fee_schedule_from_api where available to auto-update rates
- [x] 11.9 Add actual_fee_amount and actual_fee_currency fields to Trade model for exchange-reported fees
- [x] 11.10 Implement spread monitoring for OANDA — reject trades when current spread exceeds max_spread threshold
- [x] 11.11 Update PnL calculations everywhere to use net_pnl = gross_pnl - total_fees (entry + exit)
- [ ] 11.12 Write tests for FeeCalculator with all exchange fee structures (Binance, Indodax, Tokocrypto, OANDA spread-based)

## 12. Strategy Framework

- [x] 12.1 Create Strategy::Base module defining the strategy interface (analyze, required_indicators, params, required_timeframes)
- [x] 12.2 Create Signal value object (type: buy/sell/hold, confidence, reason, suggested_price)
- [x] 12.3 Create Strategy::Registry for strategy registration and discovery
- [x] 12.4 Implement Strategy::RSIReversal — buy on oversold, sell on overbought
- [x] 12.5 Implement Strategy::MACDCrossover — buy/sell on MACD line crossing signal line
- [x] 12.6 Create StrategyConfig model for per-bot parameter overrides (stored in DB)
- [ ] 12.7 Write tests for each strategy with known market data inputs

## 13. Risk Management

- [x] 13.1 Create RiskManagement::PreTradeCheck service — orchestrates all risk checks before order placement
- [x] 13.2 Implement position size limit check (max % of portfolio per pair)
- [x] 13.3 Implement daily loss limit check with automatic bot pausing
- [x] 13.4 Implement max open orders limit check (per bot and global)
- [x] 13.5 Implement exchange exposure limit check (max % of portfolio per exchange)
- [x] 13.6 Implement minimum-profit-after-fees check (expected_profit > round_trip_fees × min_profit_multiplier)
- [x] 13.7 Create RiskConfig model for global and per-bot risk parameters (includes min_profit_fee_multiplier, default 1.5)
- [x] 13.8 Implement stop-loss monitoring job — checks positions against stop-loss levels, places market sell when triggered
- [x] 13.9 Implement daily loss counter reset job (00:00 WIB)
- [ ] 13.10 Write tests for all risk checks including fee-aware profitability validation

## 14. Order Management

- [x] 14.1 Create Order model with native database enum for status (pending, submitted, open, partially_filled, filled, cancelled, failed) via `t.enum :status, enum_type: :order_status` + estimated_fee, actual_fee_amount, actual_fee_currency fields
- [x] 14.2 Create Position model for aggregate position tracking per exchange/pair with gross_pnl, total_fees, net_pnl
- [x] 14.3 Create Trade model for completed trade records with gross amount, estimated fee, actual fee, net PnL, ml_model_id, ml_confidence
- [x] 14.4 Implement OrderManagement::PlaceOrder service — validates, calculates estimated fee, submits to exchange, creates order record
- [x] 14.5 Implement OrderManagement::SyncOrders job — polls exchange for open order updates, records actual fees on fills
- [x] 14.6 Implement PositionCalculator service — computes entry price, quantity, gross PnL, fees, net PnL from order history (including estimated exit fee for unrealized PnL)
- [x] 14.7 Implement order creation validations (min size, price range, balance check)

## 15. Trading Engine

- [x] 15.1 Create Bot model with native database enums for mode (auto/semi_auto) and status (active/paused/stopped), plus ai_enabled, ml_model_id, ml_high_threshold, ml_low_threshold, exchange, pair, strategy, risk config references
- [x] 15.2 Implement Trading::EvaluateBot job — runs strategy analysis on new market data, includes ML inference if ai_enabled
- [x] 15.3 Implement Trading::ExecuteSignal service — for automated mode: ML enhancement (if enabled) → fee estimation → risk check → place order
- [x] 15.4 Implement Trading::RequestApproval service — for semi-auto mode: include ML confidence and estimated fees in approval request
- [x] 15.5 Create Approval model with native database enum for status (pending, approved, rejected, expired)
- [x] 15.6 Implement approval timeout logic (configurable, default 5 minutes)
- [x] 15.7 Set up ActiveSupport::Notifications event publishing (signal.generated, signal.ml_filtered, order.placed, order.filled, risk.violation, approval.requested)
- [x] 15.8 Implement bot pause/resume/stop lifecycle management
- [x] 15.9 Create BotScheduler job — triggers EvaluateBot for each active bot on market data updates
- [x] 15.10 Implement AI toggle (ai_enabled on/off at runtime without restart)

## 16. ML Analytics — Feature Engineering (Ruby)

- [x] 16.1 Create Features::FractionalDiff module — FFD method with configurable d (default 0.4) and weight threshold (1e-5)
- [x] 16.2 Create Features::RollingStatistics module — rolling volatility, rolling correlation, rolling sharpe
- [x] 16.3 Create Features::Microstructure module — bid-ask spread ratio, order flow imbalance, volume-weighted features
- [x] 16.4 Create Features::Pipeline service — computes full feature vector for a given pair/exchange from market data, using model's feature_list
- [x] 16.5 Implement missing data detection — skip ML inference when insufficient history for feature computation
- [ ] 16.6 Write tests for FractionalDiff with known mathematical outputs
- [ ] 16.7 Write tests for the full feature pipeline with fixture data

## 17. ML Analytics — Model Management & Inference

- [x] 17.1 Create MlModel model (name, version, model_type: lightgbm/onnx, training_date, feature_list JSON, performance_metrics JSON, file_path, status: active/retired/testing)
- [x] 17.2 Implement model file storage (Active Storage or direct file in storage/ml_models/)
- [x] 17.3 Implement model file validation on upload — attempt to load with lightgbm/onnxruntime gem, reject if invalid
- [x] 17.4 Create MlAnalytics::Predict service — loads model (with caching), computes features via Pipeline, runs inference, returns confidence 0.0-1.0
- [x] 17.5 Implement model caching — load model into memory once, reuse across predictions (invalidate on model change)
- [x] 17.6 Implement meta-labeling logic: confidence > high_threshold → full size, moderate → scaled size, low → skip signal
- [x] 17.7 Create ML model management views in dashboard (upload, list, activate/retire, view performance)
- [x] 17.8 Write tests for Predict service with mock model and known feature inputs

## 18. ML Analytics — Training Pipeline & Performance Tracking

- [x] 18.1 Create rake task `ml:export_training_data[pair,exchange,from,to]` — exports candle data + trade history to CSV
- [x] 18.2 Create Python training notebook template (Jupyter) with: data loading, feature engineering, triple-barrier labeling, meta-labeling
- [x] 18.3 Add purged K-Fold CV and walk-forward validation to training notebook
- [x] 18.4 Add model export (LightGBM .txt + metadata JSON) to training notebook
- [x] 18.5 Create rake task `ml:validate_features[pair,exchange]` — computes features in Ruby, compares against Python reference outputs (tolerance 1e-6)
- [x] 18.6 Create MlPredictionLog model — records each prediction (bot_id, ml_model_id, confidence, signal_type, features snapshot)
- [x] 18.7 Implement ML performance tracking — correlate predictions with trade outcomes (accuracy, PnL contribution)
- [x] 18.8 Create ML performance dashboard page (accuracy rate, confidence distribution, PnL with AI vs without AI, filter rate)
- [x] 18.9 Document the full offline training → model upload → bot enable workflow

## 19. Telegram Integration

- [x] 19.1 Set up Telegram bot via BotFather and store token in encrypted credentials
- [x] 19.2 Create TelegramController with webhook endpoint for receiving updates
- [x] 19.3 Implement Telegram user verification — only respond to configured admin user ID
- [x] 19.4 Implement /status command handler (active bots, portfolio value, daily PnL including fees)
- [x] 19.5 Implement /balance command handler (balances per exchange)
- [x] 19.6 Implement /bots command handler (list all bots with status, AI enabled/disabled indicator)
- [x] 19.7 Implement trade notification sender (order filled with net PnL after fees, risk violation)
- [x] 19.8 Implement semi-auto approval flow with inline keyboard buttons — include ML confidence and estimated fees in the approval message
- [x] 19.9 Implement approval callback handler — processes button press, triggers order execution
- [x] 19.10 Implement daily summary job (21:00 WIB) — compile and send daily stats including total fees paid and AI filter stats

## 20. Web Dashboard

- [x] 20.1 Create DashboardController with overview page (portfolio value, gross PnL, fees, net PnL, active bots, recent trades)
- [x] 20.2 Create BotsController with index, show, new, create, edit, update, destroy actions — bot form includes ai_enabled toggle and ML model selection
- [x] 20.3 Create bot management views (list with AI indicator, detail with activity log + ML stats, create/edit forms with AI config)
- [x] 20.4 Create TradesController with index action and filtering (exchange, pair, date range, side, AI-enhanced yes/no)
- [x] 20.5 Create trades history view with pagination — columns include gross PnL, fees, net PnL, ML confidence
- [x] 20.6 Create PortfolioController showing positions per exchange with current prices, fees, and net PnL
- [x] 20.7 Create fee schedule management page (view/edit per exchange, sync from API button)
- [x] 20.8 Add Turbo Streams over Solid Cable (Action Cable via PostgreSQL) for live dashboard updates (price tickers, trade notifications, bot status changes)
- [x] 20.9 Ensure responsive layout works on mobile (test key flows on small viewport)

## 21. Event Subscriptions & Wiring

- [x] 21.1 Create EventSubscriber initializer — subscribe to AS::Notifications events
- [x] 21.2 Wire signal.generated → Telegram notification (semi-auto) or direct execution (auto)
- [x] 21.3 Wire signal.ml_filtered → log ML filtering, optional Telegram notification
- [x] 21.4 Wire order.placed / order.filled → Telegram notification (with fee info) + dashboard update
- [x] 21.5 Wire risk.violation → Telegram alert + bot pause logic
- [x] 21.6 Wire approval.received → Trading::ExecuteSignal

## 22. Deployment & Operations

- [x] 22.1 Configure Kamal 2 (`config/deploy.yml`) — Docker image build, VPS target, environment variables, health check path
- [x] 22.2 Create Dockerfile optimized for budget VPS (multi-stage build, minimal image size, Puma + Solid Queue in single container)
- [x] 22.3 Configure SSL via Let's Encrypt (built-in proxy with automatic HTTPS)
- [x] 22.4 Configure PostgreSQL on VPS (tuned for 2GB: shared_buffers=256MB; or 1GB: shared_buffers=128MB)
- [x] 22.5 Configure PostgreSQL backup cron (daily pg_dump to local + optional object storage)
- [x] 22.6 Create health check endpoint (/up) that verifies DB, Solid Queue, exchange connectivity, and ML model status — Kamal uses this for rolling deploys
- [x] 22.7 Add swap file setup to VPS provisioning (2GB swap recommended for 1GB VPS, 1GB swap for 2GB VPS)
- [x] 22.8 Verify lightgbm/onnxruntime gem installation in Docker image (Ubuntu/Debian x86_64 base)
- [x] 22.9 Create ML model deployment workflow (upload via dashboard or `kamal app exec` to copy model file)
- [x] 22.10 Test full deploy cycle: `kamal setup` (first deploy) and `kamal deploy` (subsequent) — verify zero-downtime rolling deploy
