## Why

There's no affordable, self-hosted trading bot solution that covers crypto and forex markets accessible to Indonesian citizens — most existing tools are SaaS with recurring fees, closed-source, or locked to a single exchange. A self-hosted Ruby on Rails bot on a budget VPS (~$5-10/mo, 1-2 vCPU, 1-2GB RAM) gives full control over strategies, data, and execution while keeping costs minimal.

## What Changes

- New Rails 8.1 application with loose coupling architecture following POODR and SOLID principles
- Pluggable exchange adapter system supporting crypto exchanges (Tokocrypto, Indodax, Binance), OANDA (forex, gold/metals, indices via REST v20 API), and future Bappebti-regulated forex brokers (GKInvest, Valbury)
- Dual-mode trading engine: fully automated execution and semi-automated (signal → approval → execution)
- Pluggable strategy framework for defining custom trading strategies per market type
- **Toggleable AI/ML analytics layer** (ML4T): train models offline (Python/Colab), run lightweight inference on VPS via `lightgbm`/`onnxruntime` Ruby gems. Uses meta-labeling (López de Prado) — ML doesn't replace strategies, it enhances signal confidence and position sizing. Can be toggled on/off per bot.
- **Platform-specific fee management**: accurate fee schedules per exchange (Binance: 0.1% maker/taker with BNB discount, Indodax: 0% maker/0.3% taker, Tokocrypto: 0.1% flat with TKO discount, OANDA: spread-based from ~1.1 pips EUR/USD or core spread + commission, forex brokers: spread + commission). Fee-aware PnL calculations, minimum-profit-after-fees validation, and round-trip cost estimation before every trade.
- Real-time market data collection with efficient storage on constrained resources
- Order lifecycle management with position tracking and **fee-aware PnL** across all connected exchanges
- Risk management layer with configurable rules (position sizing, stop-loss, daily limits) and **minimum-profit-after-fees** pre-trade check
- Web dashboard for monitoring bots, viewing trades, **ML model performance**, and managing strategies
- Telegram bot integration for alerts, trade notifications, and approval commands
- Designed for budget VPS: Rails 8.1 Solid trifecta (Solid Queue + Solid Cache + Solid Cable — zero Redis), PostgreSQL, Kamal 2 deployment, minimal memory footprint

## Capabilities

### New Capabilities

- `exchange-adapters`: Adapter pattern for exchange/broker APIs — uniform interface for market data retrieval, order placement, balance queries, and WebSocket streams. Each exchange is an isolated adapter conforming to a shared contract.
- `market-data`: Market data collection, normalization, and storage. Handles candlestick/OHLCV data, order book snapshots, and ticker prices across all connected exchanges with efficient DB storage.
- `trading-engine`: Core orchestration engine that coordinates strategy signals, risk checks, and order execution. Supports both automated and semi-automated modes with configurable execution policies.
- `strategy-framework`: Pluggable strategy definitions using a DSL/interface pattern. Strategies receive market data and emit signals. Includes common technical indicators (RSI, MACD, Bollinger, moving averages).
- `order-management`: Order lifecycle tracking — creation, submission, partial fills, completion, cancellation. Position tracking with PnL calculation across exchanges.
- `risk-management`: Pre-trade risk checks — position sizing, max drawdown, stop-loss enforcement, daily loss limits, and per-exchange exposure limits.
- `web-dashboard`: Rails web UI for bot monitoring, trade history, strategy configuration, exchange credentials management, and portfolio overview with charts.
- `telegram-integration`: Telegram bot for push notifications (trade alerts, signals, errors) and commands (approve/reject trades in semi-auto mode, check balances, bot status).
- `user-auth`: Single-user authentication for the web dashboard with secure credential storage for exchange API keys.
- `fee-management`: Platform-specific fee schedules (maker/taker/spread/commission), fee-aware PnL calculation, round-trip cost estimation, and minimum-profit-after-fees validation. Supports tiered fees, token-based discounts (BNB, TKO), and forex spread+commission models.
- `ml-analytics`: Toggleable ML4T analytics layer. Offline training pipeline (Python) with triple-barrier labeling, meta-labeling, fractional differentiation, and purged K-Fold CV. On-VPS inference via LightGBM/ONNX Ruby gems. ML enhances signals (confidence scoring, position sizing) without replacing traditional strategies. Feature engineering pipeline in Ruby for real-time feature computation.

### Modified Capabilities

_(none — greenfield project)_

## Impact

- **New Rails application**: Full project scaffold with models, controllers, background jobs, and service objects
- **External API dependencies**: Exchange APIs (Tokocrypto, Indodax, Binance REST/WebSocket), OANDA REST v20 API (forex/metals/indices), future forex broker APIs (GKInvest, Valbury), Telegram Bot API
- **ML dependencies**: `lightgbm` and/or `onnxruntime` Ruby gems for inference (~30-50MB RAM). Python (offline only) for model training — not required on VPS.
- **Database**: PostgreSQL for trade data, market data, strategy state, job queue (Solid Queue), caching (Solid Cache), and WebSocket (Solid Cable) — all DB-backed, zero Redis
- **Infrastructure**: Designed for 1-2 vCPU / 2GB RAM VPS (recommended). Solid trifecta eliminates Redis entirely. Kamal 2 for zero-downtime deployment. Authentication via Rails 8.1 built-in generator. Native database enums for order/bot status fields.
- **Security**: Exchange API keys encrypted at rest, rate limiting on dashboard, Telegram bot token security
- **Future extensibility**: Stock (IDX via Stockbit/Ajaib) adapters to be added later via the same adapter interface. Gold/metals already covered via OANDA adapter.
- **Regulatory note**: OANDA Global Markets (BVI entity) accepts Indonesian clients but is not Bappebti-regulated (offshore). Crypto exchanges (Indodax, Tokocrypto) are Bappebti-registered. GKInvest/Valbury are Bappebti-regulated for futures/forex.
