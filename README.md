# TradeBot

Self-hosted multi-exchange trading bot built on Rails 8.1. Supports crypto (Binance, Indodax, Tokocrypto), forex and gold (OANDA). Designed for a budget VPS (1-2GB RAM, $5-10/mo).

## Stack

- **Rails 8.1** with Solid Queue, Solid Cache, Solid Cable (no Redis)
- **PostgreSQL** for all persistence
- **Kamal 2** for deployment
- **Tailwind CSS** for the dashboard
- **Turbo + Stimulus** for live updates

## Features

### Exchange Support
- **Crypto**: Binance, Indodax, Tokocrypto — unified adapter interface
- **Forex/Commodities**: OANDA — forex pairs, XAU/USD, XAG/USD

### Trading
- **4 Trading Modes**: Auto, Semi-Auto, Paper Trading, Backtest
- **Strategy Framework**: Pluggable strategies (RSI Reversal, MACD Crossover)
- **Technical Indicators**: RSI, MACD, Bollinger Bands, SMA/EMA
- **Fee-Aware**: Percentage-based (crypto) + pip-based (forex)

### AI/ML
- **ML Signal Filtering**: LightGBM/ONNX models
- **Feature Engineering**: Fractional differentiation, rolling stats, microstructure
- **Meta-Labeling**: Predict trade size, not direction (reduces overfitting)

### Risk & Compliance
- **Pre-Trade Checks**: Position size, daily loss limit, max open orders
- **Telegram Integration**: Commands, approval workflow, daily summary

### Dashboard
- **Real-time Prices**: Crypto, Forex, Commodities (BTC, ETH, XAU/USD, etc.)
- **Portfolio View**: Open positions, PnL by exchange
- **Bot Management**: Create, pause, resume, toggle AI
- **Trade History**: Filter by exchange, pair, date
- **ML Performance**: Model accuracy, prediction logs

## User Journey

### 1. Setup
```bash
bin/rails db:create db:migrate db:seed
bin/dev
```

### 2. Configure Exchanges
Add API credentials via `bin/rails credentials:edit`:
```yaml
binance:
  api_key: ...
  secret_key: ...
oanda:
  api_key: ...
  account_id: ...
telegram:
  bot_token: ...
```

### 3. Create Bot
1. Go to Dashboard → Bots → New Bot
2. Select exchange + trading pair (e.g., BTC/USDT)
3. Choose strategy (RSI Reversal, MACD Crossover)
4. Select mode:
   - **Auto**: Executes signals immediately
   - **Semi-Auto**: Asks via Telegram before each trade
   - **Paper Trading**: Simulates trades (no real money)
   - **Backtest**: Run strategy on historical data
5. Optionally enable AI filtering with ML model

### 4. Monitor
- Dashboard shows live prices + PnL
- Telegram receives trade notifications
- Portfolio view tracks open positions

### 5. Backtest
- Go to Bot → Run Backtest
- Select date range and view results
- Metrics: win rate, profit factor, max drawdown, equity curve

## Architecture

```
app/
├── channels/        # Action Cable (dashboard live updates)
├── controllers/     # Web dashboard + Telegram webhook
├── jobs/            # Solid Queue jobs (candle collection, bot evaluation)
├── models/
│   ├── exchanges/   # Adapter interface, registry, value objects
│   └── strategy/    # Base interface, registry, strategies
├── services/
│   ├── dashboard/   # Live broadcast
│   ├── features/    # ML feature engineering (FFD, rolling stats, microstructure)
│   ├── fee_management/  # Fee calculation (percentage + pip-based)
│   ├── indicators/  # RSI, MACD, Bollinger Bands, Moving Average
│   ├── ml_analytics/    # Predict service, performance tracking
│   ├── order_management/ # Place orders, sync, position calc
│   ├── risk_management/  # Pre-trade checks
│   ├── telegram/    # Bot, commands, approvals
│   └── trading/     # Execute signal, request approval
└── views/           # Dashboard, bots, trades, ML models
```

## Signal Flow

```
BotScheduler (recurring)
  → EvaluateBotJob
    → Fetch candles (MarketData::QueryService)
    → Compute indicators (RSI, MACD, etc.)
    → Strategy.analyze → Signal (buy/sell/hold)
    → ML filter (if AI enabled)
    → Auto: ExecuteSignal → PreTradeCheck → PlaceOrder
    → Semi-auto: RequestApproval → Telegram → User approves → ExecuteSignal
    → Paper: Trading::PaperTrading → Position tracking with PnL
```

## Deployment

See [doc/deployment.md](doc/deployment.md) for full guide.

```bash
kamal setup    # first deploy
kamal deploy   # subsequent
```

## ML Workflow

See [doc/ml_workflow.md](doc/ml_workflow.md) for the training pipeline.

```bash
bin/rails ml:export_training_data[BTC/USDT,binance,2025-01-01,2026-01-01]
# Train in Jupyter notebook
# Upload model via dashboard
# Enable AI on bot
```

## Tests

```bash
bin/rails test
```

## License

Proprietary.
