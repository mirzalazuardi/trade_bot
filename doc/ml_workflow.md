# ML Training and Deployment Workflow

## Quick Start (One Command)

```bash
# Fetch candles from Binance + train model + register in DB
bin/rails "ml:train[BTC/USDT,90]"

# Activate the model
bin/rails runner 'MlModel.last.update!(status: :active)'
```

That's it. The model file is at `storage/ml_models/signal_model.txt`.

## Overview

```
Fetch Candles → Export CSV → Train LightGBM → Register Model → Enable AI on Bot
```

The ML system uses **meta-labeling**: it predicts whether a strategy's signal will be profitable, not direction. This reduces overfitting.

## Prerequisites

```bash
pip install lightgbm pandas numpy scikit-learn
```

## Step-by-Step

### 1. Fetch Historical Candles

```bash
# Fetch 90 days of 1h candles from Binance (no API key needed)
bin/rails "ml:fetch_candles[BTC/USDT,1h,90]"

# Other pairs
bin/rails "ml:fetch_candles[ETH/USDT,1h,60]"
bin/rails "ml:fetch_candles[SOL/USDT,1h,30]"
```

### 2. Export Training Data

```bash
bin/rails "ml:export_training_data[BTC/USDT,binance,2025-12-01,2026-03-01]"
```

Output: `storage/ml_training_data/binance_BTC/USDT_2025-12-01_2026-03-01.csv`

### 3. Train the Model

**Option A: Automated (recommended)**

```bash
bin/rails "ml:train[BTC/USDT,90]"
```

This runs all steps: fetch → export → train → register.

**Option B: Python script directly**

```bash
python3 scripts/train_model.py storage/ml_training_data/binance_BTCUSDT_training.csv storage/ml_models
```

**Option C: Jupyter notebook**

```bash
jupyter notebook notebooks/training.ipynb
```

Output files:
- `storage/ml_models/signal_model.txt` — LightGBM model
- `storage/ml_models/metadata.json` — training metadata

### 4. Register Model in Rails

If you used `ml:train`, the model is already registered. Otherwise:

```ruby
bin/rails runner '
metadata = JSON.parse(File.read("storage/ml_models/metadata.json"))
MlModel.create!(
  user: User.first,
  name: metadata["name"],
  version: 1,
  model_type: :lightgbm,
  status: :testing,
  file_path: Rails.root.join("storage/ml_models/signal_model.txt").to_s,
  training_date: Date.today,
  feature_list: metadata["feature_list"],
  performance_metrics: metadata["performance_metrics"]
)
'
```

Or create via the dashboard: **ML Models** → **New ML Model**.

### 5. Activate the Model

```bash
bin/rails runner 'MlModel.last.update!(status: :active)'
```

### 6. Enable AI on a Bot

Via dashboard: **Bots** → Edit → check **AI Enabled** → select model → set thresholds.

Via console:

```ruby
bot = Bot.find_by(pair: "BTC/USDT")
bot.update!(
  ai_enabled: true,
  ml_model_id: MlModel.find_by(name: "Signal Filter").id,
  ml_high_threshold: 0.7,
  ml_low_threshold: 0.3
)
```

## How It Works at Runtime

```
EvaluateBotJob
  → Strategy generates signal (buy/sell/hold)
  → If AI enabled and signal is buy/sell:
      → Features::Pipeline computes feature vector
      → MlAnalytics::Predict loads model, runs inference
      → confidence >= 0.7 → execute trade (full size)
      → confidence 0.3-0.7 → execute trade (scaled size)
      → confidence < 0.3   → skip signal
```

## Feature Pipeline

| Feature | Service | Description |
|---------|---------|-------------|
| `ffd` | `Features::FractionalDiff` | Fractional differentiation (d=0.4) |
| `volatility` | `Features::RollingStatistics` | Rolling std dev of returns |
| `spread` | `Features::Microstructure` | Bid-ask spread ratio |
| `vwap` | `Features::Microstructure` | Volume-weighted average price |
| `rsi` | `Indicators::RSI` | Relative Strength Index (14-period) |

## Rake Tasks

| Task | Description |
|------|-------------|
| `ml:fetch_candles[PAIR,INTERVAL,DAYS]` | Fetch candles from Binance API |
| `ml:export_training_data[PAIR,EXCHANGE,FROM,TO]` | Export candles to CSV |
| `ml:train[PAIR,DAYS]` | Full pipeline: fetch + export + train + register |
| `ml:validate_features[PAIR,EXCHANGE]` | Validate Ruby vs Python feature parity |

## Directory Structure

```
storage/
├── ml_models/
│   ├── signal_model.txt        # LightGBM model file
│   └── metadata.json           # Training metadata
└── ml_training_data/
    └── binance_BTCUSDT_training.csv

scripts/
└── train_model.py              # Standalone training script

notebooks/
└── training.ipynb              # Jupyter notebook (advanced)
```

## Model Lifecycle

| Status | Meaning |
|--------|---------|
| `testing` | Just created, not used by bots |
| `active` | Used for signal filtering |
| `retired` | No longer used |

## Troubleshooting

**No candle data**: Run `bin/rails "ml:fetch_candles[BTC/USDT,1h,90]"`

**Model not loading**: Check `file_path` exists and `lightgbm` gem is installed

**No predictions**: Bot needs `ai_enabled: true`, model must be `active`

**Low accuracy**: Retrain with more data, check feature list matches training
