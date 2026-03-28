# ML Training and Deployment Workflow

This document describes the complete workflow for training, deploying, and using ML models for signal filtering.

## Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Export    │ →  │  Train in  │ →  │   Upload  │ →  │   Enable  │
│  Data      │    │  Notebook  │    │   Model   │    │    AI     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Step 1: Export Training Data

Export historical candle data + trade history to CSV:

```bash
bin/rails ml:export_training_data[PAIR,EXCHANGE,FROM,TO]

# Example: Export BTC/USDT data from Binance for last 90 days
bin/rails ml:export_training_data[BTC/USDT,binance,2025-12-01,2026-03-01]
```

This creates a CSV file in `tmp/ml_training/` with:
- OHLCV candles
- Technical indicators (RSI, MACD, Bollinger Bands)
- Trade outcomes (for labeling)

## Step 2: Train Model

Open the Jupyter notebook and follow the template:

```bash
jupyter notebook notebook/ml/training.ipynb
```

The notebook includes:
1. Data loading from exported CSV
2. Feature engineering (FractionalDiff, RollingStats, Microstructure)
3. Triple-barrier labeling (profit target, stop loss, timeout)
4. Meta-labeling for signal quality
5. Purged K-Fold CV validation
6. Walk-forward validation
7. Model export (LightGBM .txt + metadata JSON)

## Step 3: Validate Features

Before using in production, validate Ruby feature computation against Python reference:

```bash
bin/rails ml:validate_features[BTC/USDT,binance]
```

This ensures feature consistency between training and inference.

## Step 4: Upload Model

1. Go to **ML Models** in the dashboard
2. Click **New ML Model**
3. Fill in:
   - Name: e.g., "RSI reversal filter"
   - Version: increment for each update
   - Type: LightGBM or ONNX
   - Training Date
   - File Path: point to uploaded model file
   - Feature List: features used during training
   - Performance Metrics: accuracy, Sharpe, etc. from CV
4. Set status to **Testing** initially

## Step 5: Enable AI on Bot

1. Go to **Bots** in the dashboard
2. Edit your bot
3. Enable **AI Enhanced**
4. Select your ML Model
5. Set thresholds:
   - High Threshold (0.7): Full size trade
   - Low Threshold (0.3): Skip signal
   - Between: Scaled size

## How It Works

```
Signal Generated → ML Model Inference → Confidence Check
                                    ↓
                    ┌───────────────┴───────────────┐
                    ↓           ↓                  ↓
              High (≥0.7)   Moderate           Low (<0.3)
                    ↓           ↓                  ↓
              Full Size    Scaled Size         Signal Filtered
```

## Performance Tracking

The system automatically tracks:
- **Total predictions** made
- **Executed signals** (filtered vs executed)
- **Confidence distribution** (low/moderate/high bins)
- **Accuracy rate** (profitable / total executed trades)
- **Filter rate** (signals blocked by ML)

View performance at **ML Performance** dashboard page.

## Model Lifecycle

1. **Testing**: Initial upload, not used
2. **Active**: Used for signal filtering
3. **Retired**: No longer used

Only one model can be active per bot. Replace active model to switch.

## Troubleshooting

### No predictions recorded
- Ensure AI is enabled on the bot
- Check bot has ML model assigned
- Verify market data exists for the pair

### Accuracy seems low
- Check training data quality
- Verify feature list matches training
- Consider retraining with more recent data

### Model not loading
- Verify file path exists
- Check model file format is correct
- Ensure LightGBM/ONNX gems installed