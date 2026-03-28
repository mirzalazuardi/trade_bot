# TradeBot

Self-hosted multi-exchange trading bot built on Rails 8.1. Supports crypto (Binance, Indodax, Tokocrypto), forex and gold (OANDA). Designed for a budget VPS (1-2GB RAM, $5-10/mo).

## Stack

- **Rails 8.1** with Solid Queue, Solid Cache, Solid Cable (no Redis)
- **PostgreSQL** for all persistence
- **Kamal 2** for deployment
- **Tailwind CSS** for the dashboard
- **Turbo + Stimulus** for live updates

## Features

- **4 exchange adapters** with unified interface (Binance, Indodax, Tokocrypto, OANDA)
- **Strategy framework** with pluggable strategies (RSI Reversal, MACD Crossover)
- **Technical indicators** (RSI, MACD, Bollinger Bands, SMA/EMA)
- **ML signal filtering** (LightGBM/ONNX) with fractional differentiation, meta-labeling
- **Risk management** with pre-trade checks
- **Fee-aware calculations** per exchange (percentage-based for crypto, pip-based for forex)
- **Telegram integration** (commands, approval workflow, daily summary)
- **Web dashboard** with portfolio, bots, trades, ML performance tracking
- **Semi-auto mode** with Telegram approval for each trade

## Setup

```bash
git clone <repo>
cd trade_bot
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

## Configuration

```bash
bin/rails credentials:edit
```

Required credentials:

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

## Known Issues — Remaining Fixes

### P5: Risk Management (priority: high, effort: 1-2 days)

The risk management layer has three gaps that must be addressed before live trading:

**H1: Risk check stubs are empty**
`RiskManagement::PreTradeCheck` has three placeholder methods with no implementation:
- `check_position_size` — should enforce max position as % of portfolio
- `check_daily_loss_limit` — should halt trading when daily drawdown exceeds 2%
- `check_max_open_orders` — should cap concurrent open orders per bot/exchange

**H2: Balance check ignores fees**
`check_balance` compares `available_balance >= quantity * price` but doesn't add estimated fees. Orders can fail at the exchange when the fee is deducted from the balance.

**H3: `bot.risk_config` has no backing model**
Multiple services call `@bot.risk_config&.max_position_percent` etc., but `Bot` has no `risk_config` association. Always returns `nil`, silently falling back to hardcoded defaults (10% allocation, 10 max orders). Need to either:
- Add a `risk_configs` table + `has_one :risk_config` on Bot, or
- Add risk columns directly to the `bots` table (`max_position_pct`, `max_daily_loss_pct`, `max_open_orders`)

### Other Minor Items

| Item | Description |
|------|-------------|
| `Signal` constant warning | `strategy/base.rb:33` redefines `Signal` on each load. Consider namespacing as `Strategy::Signal`. |
| Skipped tests (3) | ML predict tests that require candle fixtures. Not blocking. |
| `UpdateMlOutcomesJob.perform_async` | Should be `perform_later` (Rails convention). |

## License

Proprietary. Not for redistribution.
