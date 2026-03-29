#!/usr/bin/env python3
"""
Train a model for trade signal filtering.

Usage:
    python3 scripts/train_model.py <csv_path> <output_dir> [model_type] [features] [profit_pct] [loss_pct]

Examples:
    python3 scripts/train_model.py data.csv output lightgbm indicators 2.0 1.0
    python3 scripts/train_model.py data.csv output onnx full 3.0 2.0
"""
import sys
import os
import json
import pandas as pd
import numpy as np
import lightgbm as lgb
from datetime import date


FEATURE_SETS = {
    "basic": ["open", "high", "low", "close", "volume"],
    "indicators": ["open", "high", "low", "close", "volume", "rsi", "macd", "volatility"],
    "full": ["open", "high", "low", "close", "volume", "rsi", "macd", "macd_signal", "volatility", "bb_width", "atr", "volume_ratio"],
}


def compute_atr(high, low, close, period=14):
    tr1 = high - low
    tr2 = (high - close.shift(1)).abs()
    tr3 = (low - close.shift(1)).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    return tr.rolling(period).mean()


def compute_bb_width(prices, period=20):
    sma = prices.rolling(period).mean()
    std = prices.rolling(period).std()
    upper = sma + 2 * std
    lower = sma - 2 * std
    return (upper - lower) / sma.replace(0, 1)


def compute_volume_ratio(volume, window=20):
    avg = volume.rolling(window).mean()
    return volume / avg.replace(0, 1)


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 train_model.py <csv_path> <output_dir> [model_type] [features] [profit_pct] [loss_pct]")
        sys.exit(1)

    csv_path = sys.argv[1]
    output_dir = sys.argv[2]
    model_type = sys.argv[3] if len(sys.argv) > 3 else "lightgbm"
    features_key = sys.argv[4] if len(sys.argv) > 4 else "indicators"
    profit_pct = float(sys.argv[5]) if len(sys.argv) > 5 else 0.02
    loss_pct = float(sys.argv[6]) if len(sys.argv) > 6 else -0.01

    print(f"\n=== Training {model_type.upper()} model ===")
    print(f"Features: {features_key} | Profit: {profit_pct*100}% | Stop: {abs(loss_pct)*100}%\n")

    feature_cols = FEATURE_SETS.get(features_key, FEATURE_SETS["indicators"])

    df = pd.read_csv(csv_path)
    print(f"  {len(df)} rows loaded")

    if len(df) < 200:
        print(f"  Need at least 200 candles, got {len(df)}")
        sys.exit(1)

    print("Computing features...")
    df["rsi"] = compute_rsi(df["close"])
    df["macd"], df["macd_signal"] = compute_macd(df["close"])
    df["volatility"] = compute_volatility(df["close"])
    df["atr"] = compute_atr(df["high"], df["low"], df["close"]) if "atr" in feature_cols else 0
    df["bb_width"] = compute_bb_width(df["close"]) if "bb_width" in feature_cols else 0
    df["volume_ratio"] = compute_volume_ratio(df["volume"]) if "volume_ratio" in feature_cols else 1

    df["label"] = create_labels(df, profit_pct=profit_pct, loss_pct=loss_pct)
    df = df.dropna()
    print(f"  {len(df)} rows after dropping NaN")
    print(f"  Label distribution: {dict(df['label'].value_counts())}")

    split = int(len(df) * 0.8)
    X_train, X_test = df[feature_cols].iloc[:split], df[feature_cols].iloc[split:]
    y_train, y_test = df["label"].iloc[:split] + 1, df["label"].iloc[split:] + 1

    print(f"  Train: {len(X_train)}, Test: {len(X_test)}")

    if model_type == "onnx":
        model, accuracy = train_onnx(X_train, X_test, y_train, y_test)
    else:
        model, accuracy = train_lightgbm(X_train, X_test, y_train, y_test)

    print(f"  Test accuracy: {accuracy:.4f}")

    feature_importance = model.feature_importance().tolist() if hasattr(model, 'feature_importance') else [0] * len(feature_cols)
    importance = sorted(zip(feature_cols, feature_importance), key=lambda x: x[1], reverse=True)
    print("  Feature importance:")
    for feat, imp in importance[:5]:
        print(f"    {feat}: {imp}")

    os.makedirs(output_dir, exist_ok=True)
    model_path = os.path.join(output_dir, "signal_model.txt")

    if model_type == "onnx":
        onnx_path = os.path.join(output_dir, "signal_model.onnx")
        onnxproto = model.SerializeToString()
        with open(onnx_path, "wb") as f:
            f.write(onnxproto)
        model_path = onnx_path
    else:
        model.save_model(model_path)

    print(f"\n  ✓ Model saved to {model_path}")

    metadata = {
        "name": "Signal Filter",
        "version": 1,
        "model_type": model_type,
        "features": features_key,
        "profit_pct": profit_pct,
        "loss_pct": loss_pct,
        "training_date": str(date.today()),
        "feature_list": feature_cols,
        "performance_metrics": {
            "test_accuracy": round(accuracy, 4),
            "train_size": len(X_train),
            "test_size": len(X_test),
            "label_distribution": {int(k): int(v) for k, v in df["label"].value_counts().items()},
        },
    }

    metadata_path = os.path.join(output_dir, "metadata.json")
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)
    print(f"  ✓ Metadata saved to {metadata_path}")


def train_lightgbm(X_train, X_test, y_train, y_test):
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

    preds = model.predict(X_test).argmax(axis=1)
    accuracy = (preds == y_test.values).mean()
    return model, accuracy


def train_onnx(X_train, X_test, y_train, y_test):
    print("Training ONNX model...")
    try:
        from skl2onnx import to_onnx
        from sklearn.ensemble import RandomForestClassifier
    except ImportError:
        print("  ONNX support requires: pip install skl2onnx scikit-learn")
        print("  Falling back to LightGBM...")
        return train_lightgbm(X_train, X_test, y_train, y_test)

    clf = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    clf.fit(X_train.values, y_train.values)
    accuracy = clf.score(X_test.values, y_test.values)

    model = to_onnx(clf, X_train.values[:1].shape)
    return model, accuracy


if __name__ == "__main__":
    main()
