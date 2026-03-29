#!/usr/bin/env python3
"""
Train a LightGBM model for trade signal filtering.

Usage:
    python3 scripts/train_model.py <csv_path> <output_dir>

Example:
    python3 scripts/train_model.py storage/ml_training_data/binance_BTCUSDT_training.csv storage/ml_models
"""
import sys
import os
import json
import pandas as pd
import numpy as np
import lightgbm as lgb
from datetime import date


def compute_rsi(prices, period=14):
    delta = prices.diff()
    gain = delta.where(delta > 0, 0.0)
    loss = -delta.where(delta < 0, 0.0)
    avg_gain = gain.rolling(window=period, min_periods=period).mean()
    avg_loss = loss.rolling(window=period, min_periods=period).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def compute_macd(prices, fast=12, slow=26, signal=9):
    ema_fast = prices.ewm(span=fast, adjust=False).mean()
    ema_slow = prices.ewm(span=slow, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    return macd_line, signal_line


def compute_volatility(prices, window=20):
    returns = prices.pct_change()
    return returns.rolling(window=window).std()


def create_labels(df, profit_pct=0.02, loss_pct=-0.01, hold_bars=5):
    """Triple barrier labeling: profit target, stop loss, or time exit."""
    labels = []
    for i in range(len(df)):
        if i + hold_bars >= len(df):
            labels.append(0)  # hold
            continue

        future = df["close"].iloc[i + 1 : i + hold_bars + 1]
        entry = df["close"].iloc[i]
        max_ret = (future.max() - entry) / entry
        min_ret = (future.min() - entry) / entry

        if max_ret >= profit_pct:
            labels.append(1)  # buy signal was profitable
        elif min_ret <= loss_pct:
            labels.append(-1)  # sell signal was profitable
        else:
            labels.append(0)  # hold
    return labels


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    csv_path = sys.argv[1]
    output_dir = sys.argv[2]

    # Load data
    print(f"Loading data from {csv_path}...")
    df = pd.read_csv(csv_path)
    print(f"  {len(df)} rows loaded")

    if len(df) < 200:
        print(f"  ✗ Need at least 200 candles, got {len(df)}")
        sys.exit(1)

    # Compute indicators
    print("Computing features...")
    df["rsi"] = compute_rsi(df["close"])
    df["macd"], df["macd_signal"] = compute_macd(df["close"])
    df["volatility"] = compute_volatility(df["close"])

    # Create labels
    df["label"] = create_labels(df)
    df = df.dropna()
    print(f"  {len(df)} rows after dropping NaN")
    print(f"  Label distribution: {dict(df['label'].value_counts())}")

    # Features
    feature_cols = ["open", "high", "low", "close", "volume", "rsi", "macd", "volatility"]

    # Train/test split (80/20, time-ordered)
    split = int(len(df) * 0.8)
    X_train, X_test = df[feature_cols].iloc[:split], df[feature_cols].iloc[split:]
    y_train, y_test = df["label"].iloc[:split] + 1, df["label"].iloc[split:] + 1  # shift to 0,1,2

    print(f"  Train: {len(X_train)}, Test: {len(X_test)}")

    # Train LightGBM
    print("Training LightGBM model...")
    params = {
        "objective": "multiclass",
        "num_class": 3,
        "metric": "multi_logloss",
        "boosting_type": "gbdt",
        "num_leaves": 31,
        "learning_rate": 0.05,
        "feature_fraction": 0.8,
        "bagging_fraction": 0.8,
        "bagging_freq": 5,
        "verbose": -1,
        "seed": 42,
    }

    train_data = lgb.Dataset(X_train, label=y_train)
    test_data = lgb.Dataset(X_test, label=y_test, reference=train_data)

    model = lgb.train(
        params,
        train_data,
        num_boost_round=500,
        valid_sets=[test_data],
        callbacks=[lgb.early_stopping(30, verbose=False)],
    )

    # Evaluate
    preds = model.predict(X_test).argmax(axis=1)
    accuracy = (preds == y_test.values).mean()
    print(f"  Test accuracy: {accuracy:.4f}")

    # Feature importance
    importance = sorted(
        zip(feature_cols, model.feature_importance().tolist()),
        key=lambda x: x[1],
        reverse=True,
    )
    print("  Feature importance:")
    for feat, imp in importance:
        print(f"    {feat}: {imp}")

    # Save model
    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "signal_model.txt")
    model.save_model(model_path)
    print(f"\n  ✓ Model saved to {model_path}")

    # Save metadata
    metadata = {
        "name": "Signal Filter",
        "version": 1,
        "model_type": "lightgbm",
        "training_date": str(date.today()),
        "feature_list": feature_cols,
        "performance_metrics": {
            "test_accuracy": round(accuracy, 4),
            "train_size": len(X_train),
            "test_size": len(X_test),
            "best_iteration": model.best_iteration,
            "label_distribution": {int(k): int(v) for k, v in df["label"].value_counts().items()},
        },
    }

    metadata_path = os.path.join(output_dir, "metadata.json")
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"  ✓ Metadata saved to {metadata_path}")


if __name__ == "__main__":
    main()
