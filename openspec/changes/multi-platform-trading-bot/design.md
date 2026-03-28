## Context

This is a greenfield **Rails 8.1** (latest stable: 8.1.3) application for a single-user, self-hosted trading bot running on a budget VPS (2GB RAM recommended, 1GB minimum with tuning). The bot must connect to multiple crypto exchanges (Tokocrypto, Indodax, Binance) and forex brokers (GKInvest, Valbury) accessible to Indonesian citizens. It supports both fully automated and semi-automated (signal → approval) trading modes.

Rails 8.1 is a strong fit because it ships with the **Solid trifecta** (Solid Queue, Solid Cache, Solid Cable) — all DB-backed, eliminating Redis entirely. It also includes a built-in authentication generator, Kamal 2 for deployment, Propshaft (leaner asset pipeline), native database enums, `discard_on` for graceful job error handling, and historic job archival in Solid Queue.

The architecture must follow POODR and SOLID principles with loose coupling between components, so adding new exchanges, strategies, or market types requires minimal changes to existing code.

**Constraints:**
- 2GB RAM recommended (1GB minimum with tuning) — must run Rails, PostgreSQL, and background jobs in a single VPS
- Single user (not multi-tenant)
- Indonesian market regulations (Bappebti for futures/forex, OJK awareness for securities)
- Exchange API rate limits vary significantly across platforms
- Network latency from Indonesian/SE Asian VPS to exchange servers

## Goals / Non-Goals

**Goals:**
- Loosely coupled, POODR/SOLID architecture where each component has a single responsibility and communicates through well-defined interfaces
- Support crypto (Tokocrypto, Indodax, Binance) and OANDA (forex, gold/metals, indices via REST v20) as initial adapters. GKInvest/Valbury (Bappebti-regulated forex) deferred until API availability confirmed.
- Dual-mode execution: fully automated and signal-with-approval via Telegram
- Run comfortably on 2GB RAM VPS (1GB with tuning) using Rails 8.1 Solid trifecta — zero Redis
- Web dashboard for monitoring (with Solid Cable for live updates) and Telegram bot for alerts/commands
- Extensible adapter interface for future stock (IDX) and commodity (gold) support

**Non-Goals:**
- Multi-tenant SaaS platform (this is a personal tool)
- High-frequency trading / sub-second execution (VPS latency makes this impractical)
- Mobile native app (web dashboard is responsive, accessed via browser)
- Backtesting engine (deferred to future iteration)
- Copy-trading or social trading features
- Direct market access (DMA) — all trades go through exchange/broker APIs

## Decisions

### 1. Rails 8.1 with Solid Trifecta (zero Redis)

**Choice:** Use Rails 8.1.3 with the full Solid trifecta: **Solid Queue** (background jobs), **Solid Cache** (caching), and **Solid Cable** (Action Cable/WebSocket) — all backed by PostgreSQL, eliminating Redis entirely.

**Why:** On a 2GB VPS, Redis would consume 50-200MB of precious RAM. Rails 8.1 ships all three Solid adapters as defaults, meaning zero additional configuration for a fully-featured production stack without Redis.

**Rails 8.1 features we leverage:**
- **Solid Queue** (default job backend): Recurring jobs for market data polling, order sync, daily summary. Historic job archival for audit trail. `discard_on` for graceful handling of transient exchange API errors.
- **Solid Cache** (default cache store): Cache fee schedules, ticker data, exchange balance snapshots — all in PostgreSQL, no Redis.
- **Solid Cable** (default Action Cable adapter): Live dashboard updates via WebSocket without Redis pub/sub.
- **Authentication generator** (`bin/rails generate authentication`): Scaffolds User model, SessionsController, Current attributes, password reset — exactly what we need for single-user auth. No Devise dependency.
- **Kamal 2** (default deployer): Docker-native, zero-downtime deployment to VPS. Ships with Rails 8.1, configured via `config/deploy.yml`.
- **Propshaft** (default asset pipeline): Leaner than Sprockets, lower memory footprint.
- **Native database enums**: `t.enum :status, enum_type: :order_status` for Order, Bot, and Approval status fields — database-level type safety.

**Alternatives considered:**
- **Rails 8.0.x**: Stable but misses 8.1 improvements (historic jobs, better enum support, Kamal 2 tighter integration)
- **Rails 7.2 + manual Solid gems**: Extra setup; 8.1 gives us everything out of the box
- **Sidekiq + Redis on Rails 8.1**: Possible but unnecessary — Solid Queue is the blessed default and our job volume is moderate

**Trade-off:** Solid Queue has lower throughput than Sidekiq for high-volume jobs. Acceptable since we're not doing HFT and job volume is moderate (market data polls + order checks every 1-60 seconds).

### 2. Adapter Pattern for Exchange Integration

**Choice:** Each exchange implements a common `Exchange::Base` interface using Ruby duck typing (POODR-style).

**Why:** SOLID's Dependency Inversion and Open/Closed principles. The trading engine depends on the adapter interface, not concrete exchange implementations. Adding Tokocrypto vs. Binance vs. a future IDX adapter requires zero changes to the engine.

**Interface contract:**
```
Exchange::Base
  #fetch_ticker(pair) → Ticker
  #fetch_candles(pair, interval, limit) → [Candle]
  #fetch_balance → Balance
  #place_order(order_params) → OrderResult
  #cancel_order(order_id) → CancelResult
  #fetch_order_status(order_id) → OrderStatus
  #subscribe_ticker(pair, &block) → void  (WebSocket, optional)
```

**Alternatives considered:**
- **Single god class with if/else**: Violates OCP, becomes unmaintainable
- **Gem-per-exchange**: Over-engineering for a personal tool — adapters are internal modules

### 3. Strategy Framework as Pluggable Objects

**Choice:** Strategies are plain Ruby objects conforming to a `Strategy::Base` interface. They receive market data and return signal objects.

**Why:** Follows POODR's message-sending pattern. Strategies don't know about exchanges or orders — they only understand market data in, signals out. This is the Single Responsibility principle: a strategy's job is to decide, not to execute.

**Interface:**
```
Strategy::Base
  #analyze(market_data) → Signal (buy/sell/hold with confidence, reason)
  #required_indicators → [:rsi, :macd, :bollinger]
  #params → { period: 14, threshold: 30 }
```

**Alternatives considered:**
- **DSL-based strategies**: More user-friendly but harder to test and debug
- **Database-stored strategy rules**: Flexible but adds complexity for v1 — can add later

### 4. Event-Driven Communication Between Components

**Choice:** Use ActiveSupport::Notifications for internal event bus. Components publish events; others subscribe without direct coupling.

**Why:** Loose coupling. When an order fills, the trading engine publishes `order.filled`. The notification system, risk manager, and dashboard can each subscribe independently. Adding a new subscriber (e.g., a future logging service) requires zero changes to publishers.

**Events:**
- `signal.generated` — strategy produced a signal
- `order.placed` / `order.filled` / `order.cancelled`
- `risk.violation` — risk check failed
- `market_data.updated` — new candle/ticker received
- `approval.requested` / `approval.received` — semi-auto mode

**Alternatives considered:**
- **Direct method calls**: Tighter coupling, harder to extend
- **External message queue (RabbitMQ)**: Overkill for single-process app, memory cost
- **Wisper gem**: Good pub/sub but adds dependency; AS::Notifications is built-in

### 5. Service Objects for Business Logic

**Choice:** Business logic lives in service objects (app/services/), not in models or controllers. Models handle persistence and validations only. Controllers handle HTTP concerns only.

**Why:** SOLID SRP. Models that contain trading logic become god objects. Service objects are easy to test, compose, and replace.

**Pattern:**
```
Trading::ExecuteOrder.call(signal:, exchange:, risk_params:)
Trading::EvaluateSignal.call(strategy:, market_data:)
RiskManagement::PreTradeCheck.call(order_params:, portfolio:)
```

### 6. Database Schema: PostgreSQL with Time-Series Optimization

**Choice:** PostgreSQL with table partitioning for candle data and proper indexing.

**Why:** Candle data grows fast (1-min candles × multiple pairs × multiple exchanges). PostgreSQL's native partitioning by time range keeps queries fast without a dedicated time-series DB.

**Alternatives considered:**
- **TimescaleDB**: Excellent for time-series but adds extension dependency and memory overhead
- **SQLite**: Too limited for concurrent access (background jobs + web server)
- **InfluxDB**: Separate DB to manage, more memory, overkill

### 7. Kamal 2 Deployment with Single-Process Optimization

**Choice:** Deploy via Kamal 2 (ships with Rails 8.1). Run Puma (web) and Solid Queue (workers) in a single Docker container, managed by Kamal's zero-downtime deploy.

**Why:** Kamal 2 provides Docker-native deployment without Kubernetes complexity. Single-container keeps memory minimal. Kamal handles SSL (via Let's Encrypt), rolling deploys, and health checks out of the box.

**Memory budget (2GB VPS — recommended):**
- OS + Docker: ~200MB
- PostgreSQL: ~200-300MB
- Puma (2 workers) + Solid Queue (in-process): ~350-450MB
- Solid Cache + Solid Cable: ~0 extra (uses PostgreSQL)
- ML inference model: ~30-50MB
- **Total: ~780MB-1GB** → ~1GB headroom for spikes

**Memory budget (1GB VPS — minimum, with tuning):**
- OS + Docker: ~150MB
- PostgreSQL (tuned): ~200MB (shared_buffers=128MB)
- Puma (1 worker, 2-3 threads) + Solid Queue (in-process): ~250-300MB
- ML model loaded on-demand: ~30-50MB
- **Total: ~630-700MB** → add 1-2GB swap as safety net
- Tuning: `workers 1`, `threads 2, 3` in puma.rb

**Alternatives considered:**
- **Capistrano + systemd**: Traditional but more manual setup than Kamal
- **Docker Compose**: Works but Kamal provides rolling deploys and health checks for free
- **Kubernetes**: Massive overkill for single-VPS personal tool

### 8. Encrypted Credentials for Exchange API Keys

**Choice:** Use Rails encrypted credentials (credentials.yml.enc) for exchange API keys and secrets.

**Why:** API keys must never be in plaintext. Rails encrypted credentials are built-in, require no additional gems, and work well for single-user deployments.

**Alternatives considered:**
- **Environment variables**: Simpler but harder to manage multiple exchange keys
- **Vault/AWS Secrets Manager**: Overkill for self-hosted single-user app
- **Custom encryption**: Reinventing the wheel

### 9. Fee-Aware Architecture

**Choice:** Each exchange adapter reports its fee schedule via a `FeeSchedule` value object. A `FeeCalculator` service computes costs before and after trades. Fees are stored per-exchange in the DB and updatable via dashboard.

**Why:** Fee structures vary dramatically across platforms:
- **Binance**: Maker 0.1%, Taker 0.1%. With BNB discount: 0.075%. Tiered by 30-day volume.
- **Indodax**: Maker 0%, Taker 0.3%. IDR withdrawal flat Rp10,000.
- **Tokocrypto**: Maker 0.1%, Taker 0.1% flat. TKO token discount available. IDR withdrawal flat Rp10,000.
- **OANDA**: Spread-based, no commission (spread-only account: EUR/USD ~1.1 pips) OR core spread + fixed commission. No deposit/withdrawal fee. Spread is the primary cost — varies by pair and market conditions. Streaming prices via REST v20.
- **Forex (GKInvest/Valbury)**: Spread-based (variable per pair per session) + commission per lot. (API availability TBD)

Without fee awareness, a bot could execute trades where the round-trip cost exceeds the expected profit — guaranteed loss.

**Fee integration points:**
```
1. Pre-trade: FeeCalculator.round_trip_cost(pair, entry, target, exchange)
   → Reject if expected_profit < round_trip_fees * min_profit_multiplier
2. Order creation: Attach expected_fee to order record
3. Post-trade: Record actual_fee from exchange response
4. PnL: net_pnl = gross_pnl - (entry_fee + exit_fee)
5. Strategy: Signal minimum confidence threshold adjusted by fee impact
```

**Alternatives considered:**
- **Hardcoded fee constants**: Brittle, breaks when exchanges change fees
- **Ignore fees in signals, only track in PnL**: Leads to unprofitable trades being executed
- **Exchange API fee lookup on every trade**: Adds latency and API calls; cache locally instead

### 10. ML4T Architecture: Offline Training, Lightweight Inference

**Choice:** Train ML models offline (Python on dev machine or Google Colab), export to LightGBM native format or ONNX, run inference on VPS using `lightgbm` or `onnxruntime` Ruby gems.

**Why:** Budget VPS (1-2GB RAM) cannot run Python ML stack (NumPy + pandas + scikit-learn = 300-500MB). But inference is cheap — loading a pre-trained LightGBM model in Ruby costs ~30-50MB. This gives us ML4T capability without blowing the memory budget.

**ML4T Framework (López de Prado / Jansen):**
```
OFFLINE (Python — dev machine / Colab):
├── Feature engineering: fractional diff, technical indicators, microstructure
├── Labeling: triple-barrier method (profit target, stop loss, max holding period)
├── Meta-labeling: secondary model for confidence/sizing (not direction)
├── Validation: purged K-Fold CV (no lookahead), walk-forward
├── Model: LightGBM or XGBoost (small, fast inference)
└── Export: model.txt (LightGBM) or model.onnx (ONNX)

ON-VPS (Ruby):
├── Feature computation: indicators + fractional diff in Ruby
├── Load model: LightGBM.new(model_path) or OnnxRuntime::InferenceSession.new(model_path)
├── Predict: model.predict(features) → confidence score (0.0-1.0)
└── Apply: enhance strategy signal with ML confidence for sizing/filtering
```

**Meta-labeling pattern (key concept):**
- Primary model = traditional strategy (RSI, MACD, Squeeze) → direction (buy/sell)
- Secondary model = ML → "should we act on this signal? at what size?"
- ML confidence > threshold → execute at full size
- ML confidence moderate → execute at reduced size
- ML confidence low → skip the signal
- **This is what makes AI toggleable**: turn off ML → use pure strategy signals at default size

**Memory budget impact:**
ML inference adds ~30-50MB to the VPS footprint (LightGBM model loaded in one Puma worker). See Decision #7 for full memory budget. Fits comfortably on 2GB VPS; on 1GB VPS, load model on-demand (lazy) instead of keeping it resident.

**Alternatives considered:**
- **Python sidecar process**: Full ML stack on VPS — too much RAM (~400-500MB extra)
- **External ML API (cloud)**: Adds latency, cost, and external dependency for every signal
- **Ruby-only ML (Rumale gem)**: Limited algorithms, no LightGBM/XGBoost, slower inference
- **No ML**: Works, but misses the meta-labeling opportunity to filter bad signals and size positions intelligently

### 11. AI Toggle Architecture

**Choice:** Each bot has an `ai_enabled` boolean and an optional `ml_model_id` reference. When enabled, the trading engine passes the strategy signal through an ML confidence filter before execution. When disabled, pure strategy signals drive trades.

**Why:** ML models need validation before trusting them with real money. The toggle lets you:
1. Run a bot in pure-strategy mode while collecting data for ML training
2. Enable ML in semi-auto mode first to observe AI recommendations
3. Graduate to fully automated AI-enhanced mode once confident
4. Instantly disable AI if model performance degrades (regime change)

**Flow:**
```
Market data → Strategy → Signal (buy/sell/hold)
                              ↓
                    [ai_enabled?]
                    /           \
                  YES            NO
                  ↓              ↓
           ML inference    Use signal as-is
           → confidence    (default size)
                  ↓
          confidence > high_threshold → full size
          confidence > low_threshold  → reduced size
          confidence < low_threshold  → skip signal
```

**Model lifecycle:**
- Models stored as files in `storage/ml_models/` (Rails Active Storage or direct file)
- `MlModel` DB record tracks: name, version, training_date, performance_metrics, file_path, status (active/retired)
- Dashboard shows model performance over time (accuracy, PnL contribution)
- Multiple model versions can coexist; each bot references a specific version

## Risks / Trade-offs

- **VPS memory pressure** → Mitigation: Monitor via health check endpoint. 2GB VPS recommended (~1GB headroom). 1GB VPS works with Puma 1 worker + swap. Kamal health checks auto-restart on OOM.
- **Exchange API changes without notice** → Mitigation: Adapter pattern isolates impact. Version-lock API calls. Health checks per adapter.
- **Network latency (ID → exchange servers)** → Mitigation: Not targeting HFT. Use limit orders instead of market orders where possible. Retry logic with exponential backoff.
- **Single point of failure (one VPS)** → Mitigation: Automated daily DB backups to object storage. Kamal auto-restart. Telegram alert on service down.
- **PostgreSQL as job queue + cache + cable under load** → Mitigation: Solid trifecta handles moderate load well. All three share the same PostgreSQL instance with separate tables. If needed, can migrate individual components to Redis on a bigger VPS later.
- **Forex broker API availability** → Mitigation: OANDA REST v20 is well-documented and battle-tested — use as primary forex/metals adapter. GKInvest/Valbury APIs may have limited documentation; defer until confirmed. OANDA Global Markets (BVI) is offshore (not Bappebti-regulated) — acceptable for personal use.
- **OANDA spread variability** → Mitigation: Spreads widen during low liquidity (Asian session) and news events. Fee calculator uses current spread from streaming prices, not a fixed value. Pre-trade check verifies spread is within acceptable range.
- **Regulatory risk** → Mitigation: This is a personal tool, not a service for others. Monitor Bappebti/OJK regulatory changes.
- **ML model overfitting** → Mitigation: Purged K-Fold CV with embargo period. Walk-forward validation only. Meta-labeling (size, not direction) limits damage from bad predictions. Toggle off immediately if live performance deviates from backtest.
- **Fee schedule changes** → Mitigation: Fee schedules stored in DB (not hardcoded). Dashboard allows manual updates. Periodic job to verify fees against exchange API fee endpoints where available.
- **LightGBM/ONNX gem compatibility on VPS** → Mitigation: Test gem installation on target VPS OS (Ubuntu/Debian) early in development. Both gems have precompiled binaries for Linux x86_64.

## Open Questions

1. **GKInvest/Valbury API access** — Do these brokers offer REST APIs for algorithmic trading? Deferred — OANDA fills the forex/metals role with its excellent v20 API. GKInvest/Valbury can be added later if needed for Bappebti-regulated access.
2. **WebSocket vs polling trade-off** — For budget VPS, should we default to REST polling (simpler, less memory) or WebSocket (lower latency, higher memory)? Decision per exchange.
3. **Strategy persistence** — Should strategy parameters be stored in DB (editable via dashboard) or in code (version-controlled)? Leaning toward DB for v1 with code-defined defaults.
4. **Telegram bot hosting** — Run Telegram bot in the same Rails process (webhook mode) or separate process (long-polling)? Webhook mode saves resources.
5. **ML model update workflow** — How to deploy updated models from dev machine to VPS? Options: SCP/rsync, git LFS, or Active Storage upload via dashboard. Leaning toward dashboard upload for simplicity.
6. **Feature parity between Python training and Ruby inference** — Fractional differentiation and indicator calculations must produce identical results in both Python (training) and Ruby (inference). Need numerical precision tests.
