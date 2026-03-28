## ADDED Requirements

### Requirement: AI toggle per bot
Each bot SHALL have an `ai_enabled` boolean flag (default: false) and an optional reference to an `MlModel` record. When `ai_enabled` is true, strategy signals SHALL be enhanced by ML confidence scoring before execution. When false, pure strategy signals SHALL be used.

#### Scenario: Bot with AI disabled
- **WHEN** a bot has `ai_enabled: false` and the strategy produces a buy signal with confidence 0.7
- **THEN** the trading engine SHALL execute the trade at default position size without ML enhancement

#### Scenario: Bot with AI enabled
- **WHEN** a bot has `ai_enabled: true` with an active ML model, and the strategy produces a buy signal
- **THEN** the trading engine SHALL compute features, run ML inference, and use the ML confidence score to determine position sizing

#### Scenario: Toggle AI at runtime
- **WHEN** the user toggles `ai_enabled` from false to true on a running bot via dashboard or Telegram
- **THEN** the bot SHALL begin using ML enhancement on the next signal evaluation without restart

### Requirement: ML model management
The system SHALL maintain a registry of ML models with: name, version, model_type (lightgbm/onnx), training_date, feature_list, performance_metrics (accuracy, precision, recall, sharpe), file_path, and status (active/retired/testing).

#### Scenario: Upload a new ML model via dashboard
- **WHEN** the admin uploads a LightGBM model file (.txt) with metadata (name, version, feature_list)
- **THEN** the system SHALL store the file, create an `MlModel` record with status `testing`, and make it available for bot assignment

#### Scenario: Retire an old model
- **WHEN** the admin retires a model version
- **THEN** the system SHALL set its status to `retired`, and any bots referencing it SHALL fall back to pure strategy mode (ai_enabled effectively becomes false)

#### Scenario: Model file validation
- **WHEN** an uploaded model file cannot be loaded by the LightGBM or ONNX runtime
- **THEN** the system SHALL reject the upload with error "invalid_model_file" and not create the MlModel record

### Requirement: Feature engineering pipeline (Ruby)
The system SHALL compute ML features from market data in Ruby, producing a feature vector compatible with the trained model's expected input. Features SHALL include: technical indicators, fractional differentiation values, rolling statistics, and microstructure features.

#### Scenario: Compute feature vector for prediction
- **WHEN** the ML inference pipeline requests features for BTC/USDT on Binance
- **THEN** the system SHALL compute all features listed in the model's `feature_list` from recent market data and return a numeric array in the expected order

#### Scenario: Fractional differentiation feature
- **WHEN** the feature pipeline computes `frac_diff_close` with d=0.4 using the FFD (Fixed-width Fractional Differentiation) method
- **THEN** the result SHALL preserve price memory while achieving stationarity, using weight threshold 1e-5 for truncation

#### Scenario: Missing data handling
- **WHEN** insufficient historical data exists to compute a required feature (e.g., need 200 candles but only 50 available)
- **THEN** the system SHALL skip ML inference for this evaluation cycle and log a warning, falling back to pure strategy signal

### Requirement: ML inference service
The system SHALL provide an `MlAnalytics::Predict` service that loads a model, computes features, and returns a prediction with confidence score. The service SHALL support both LightGBM and ONNX model formats.

#### Scenario: LightGBM inference
- **WHEN** the service receives a feature vector and the active model is LightGBM format
- **THEN** it SHALL load the model using the `lightgbm` Ruby gem, call `predict` with the feature array, and return a confidence score between 0.0 and 1.0

#### Scenario: ONNX inference
- **WHEN** the service receives a feature vector and the active model is ONNX format
- **THEN** it SHALL load the model using the `onnxruntime` Ruby gem, run inference, and return a confidence score between 0.0 and 1.0

#### Scenario: Model caching
- **WHEN** the inference service is called multiple times with the same model
- **THEN** the model SHALL be loaded into memory once and reused for subsequent predictions (not reloaded from disk each time)

### Requirement: Meta-labeling signal enhancement
When AI is enabled, the ML model SHALL act as a meta-labeler: the traditional strategy determines direction (buy/sell), and the ML model determines confidence (act/skip) and position sizing. The ML model SHALL NOT override the strategy's direction.

#### Scenario: High confidence — full position
- **WHEN** the strategy says "buy" and the ML model returns confidence 0.85 (above high_threshold: 0.7)
- **THEN** the system SHALL execute the buy at full position size as determined by risk management

#### Scenario: Medium confidence — reduced position
- **WHEN** the strategy says "buy" and the ML model returns confidence 0.55 (between low_threshold: 0.4 and high_threshold: 0.7)
- **THEN** the system SHALL execute the buy at a reduced position size (scaled proportionally between min and max size)

#### Scenario: Low confidence — skip signal
- **WHEN** the strategy says "buy" and the ML model returns confidence 0.25 (below low_threshold: 0.4)
- **THEN** the system SHALL skip the signal, log "ml_filtered: confidence below threshold", and NOT place any order

#### Scenario: ML does not change direction
- **WHEN** the strategy says "buy" and the ML model returns any confidence score
- **THEN** the system SHALL NEVER convert the buy to a sell; it SHALL only decide to act or skip, and at what size

### Requirement: ML confidence thresholds configuration
The ML confidence thresholds (high_threshold, low_threshold) SHALL be configurable per bot. Defaults: high_threshold=0.7, low_threshold=0.4.

#### Scenario: Custom thresholds per bot
- **WHEN** a bot is configured with high_threshold=0.8 and low_threshold=0.5
- **THEN** the meta-labeling logic SHALL use those thresholds instead of defaults

### Requirement: Offline training pipeline documentation
The system SHALL include documented Python scripts/notebooks for the offline training pipeline covering: data export from the Rails DB, feature engineering, triple-barrier labeling, meta-labeling, purged K-Fold CV, model training, and model export.

#### Scenario: Export training data from Rails
- **WHEN** the admin runs a Rails task `rails ml:export_training_data[BTC/USDT,binance,2024-01-01,2025-01-01]`
- **THEN** the system SHALL export candle data and trade history to CSV files suitable for the Python training pipeline

#### Scenario: Training notebook produces deployable model
- **WHEN** the Python training notebook is run with exported data
- **THEN** it SHALL output a trained LightGBM model file (.txt) and a metadata JSON file (feature_list, performance_metrics, training_params) ready for upload to the Rails dashboard

### Requirement: ML model performance tracking
The system SHALL track ML model performance in production: prediction accuracy (did the confidence score correlate with trade outcome?), PnL contribution (comparison of AI-enhanced vs pure strategy results), and signal filter rate (% of signals skipped by ML).

#### Scenario: Track prediction vs outcome
- **WHEN** an ML-enhanced trade completes (filled + closed)
- **THEN** the system SHALL record the ML confidence score alongside the actual trade PnL for model performance evaluation

#### Scenario: Model performance dashboard
- **WHEN** the admin views the ML model performance page
- **THEN** the dashboard SHALL show: total predictions, accuracy rate, average confidence, signals filtered (skipped), PnL with AI vs estimated PnL without AI, and a confidence vs outcome scatter chart

### Requirement: Feature parity validation
The Ruby feature computation SHALL produce numerically equivalent results to the Python training pipeline for the same input data. A validation rake task SHALL verify this.

#### Scenario: Validate fractional diff parity
- **WHEN** the admin runs `rails ml:validate_features[BTC/USDT,binance]`
- **THEN** the system SHALL compute features in Ruby, compare against reference Python outputs, and report any deviations exceeding 1e-6 tolerance
