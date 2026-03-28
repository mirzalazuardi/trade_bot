require "test_helper"

class MlAnalyticsPredictTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  teardown do
    MlAnalytics::Predict.model_cache.clear
  end

  test "returns default prediction when no ml_model_id" do
    bot = Bot.create!(
      user: @user,
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "RSIReversal",
      mode: "auto",
      status: "active"
    )
    signal = Signal.new(type: "buy", confidence: 0.8, reason: "RSI oversold")

    result = MlAnalytics::Predict.call(bot: bot, signal: signal)

    assert_equal 0.5, result.confidence
    assert_equal "hold", result.prediction
    assert_equal "No ML model", result.reason
    bot.destroy
  end

  test "returns default prediction when model not active" do
    ml_model = MlModel.create!(
      user: @user,
      name: "test_#{SecureRandom.hex(4)}",
      version: 1,
      model_type: "lightgbm",
      status: "retired",
      file_path: "storage/ml_models/test.txt",
      feature_list: [],
      training_date: Date.today - 30
    )
    bot = Bot.create!(
      user: @user,
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "RSIReversal",
      mode: "auto",
      status: "active",
      ml_model_id: ml_model.id,
      ml_high_threshold: 0.7,
      ml_low_threshold: 0.3
    )
    signal = Signal.new(type: "buy", confidence: 0.8, reason: "RSI oversold")

    result = MlAnalytics::Predict.call(bot: bot, signal: signal)

    assert_equal 0.5, result.confidence
    assert_equal "hold", result.prediction
    assert_equal "Model not active", result.reason

    ml_model.destroy
    bot.destroy
  end

  test "returns default prediction when features unavailable" do
    skip "Requires market data fixtures"

    ml_model = MlModel.create!(
      user: @user,
      name: "test_#{SecureRandom.hex(4)}",
      version: 1,
      model_type: "lightgbm",
      status: "active",
      file_path: "storage/ml_models/test.txt",
      feature_list: %w[rsi_14 macd_histogram],
      training_date: Date.today - 30
    )
    bot = Bot.create!(
      user: @user,
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "RSIReversal",
      mode: "auto",
      status: "active",
      ml_model_id: ml_model.id,
      ml_high_threshold: 0.7,
      ml_low_threshold: 0.3
    )

    signal = Signal.new(type: "buy", confidence: 0.8, reason: "RSI oversold")

    result = MlAnalytics::Predict.call(bot: bot, signal: signal)

    assert_equal 0.5, result.confidence
    assert_equal "hold", result.prediction

    ml_model.destroy
    bot.destroy
  end

  test "returns default when file path does not exist" do
    skip "Requires market data fixtures"

    ml_model = MlModel.create!(
      user: @user,
      name: "test_#{SecureRandom.hex(4)}",
      version: 1,
      model_type: "lightgbm",
      status: "active",
      file_path: "storage/ml_models/nonexistent.txt",
      feature_list: %w[rsi_14],
      training_date: Date.today - 30
    )
    bot = Bot.create!(
      user: @user,
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "RSIReversal",
      mode: "auto",
      status: "active",
      ml_model_id: ml_model.id,
      ml_high_threshold: 0.7,
      ml_low_threshold: 0.3
    )
    signal = Signal.new(type: "buy", confidence: 0.8, reason: "RSI oversold")

    result = MlAnalytics::Predict.call(bot: bot, signal: signal)

    assert_equal 0.5, result.confidence
    assert_equal "hold", result.prediction

    ml_model.destroy
    bot.destroy
  end

  test "filters signal when confidence below low threshold" do
    skip "Requires market data fixtures"

    ml_model = MlModel.create!(
      user: @user,
      name: "test_#{SecureRandom.hex(4)}",
      version: 1,
      model_type: "lightgbm",
      status: "active",
      file_path: "storage/ml_models/test.txt",
      feature_list: %w[rsi_14],
      training_date: Date.today - 30
    )
    bot = Bot.create!(
      user: @user,
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "RSIReversal",
      mode: "auto",
      status: "active",
      ml_model_id: ml_model.id,
      ml_high_threshold: 0.7,
      ml_low_threshold: 0.3
    )
    signal = Signal.new(type: "buy", confidence: 0.8, reason: "RSI oversold")

    result = MlAnalytics::Predict.call(bot: bot, signal: signal)

    assert_equal "hold", result.prediction

    ml_model.destroy
    bot.destroy
  end

  test "clamps confidence between 0 and 1" do
    predict = MlAnalytics::Predict.new(
      bot: OpenStruct.new(ml_model_id: nil, exchange_name: "binance", pair: "BTC/USDT"),
      signal: Signal.new(type: "buy", confidence: 0.5, reason: "test")
    )

    assert_equal 0.5, predict.send(:normalize_confidence, 0.5)
    assert_equal 0.0, predict.send(:normalize_confidence, -0.5)
    assert_equal 1.0, predict.send(:normalize_confidence, 1.5)
    assert_equal 0.0, predict.send(:normalize_confidence, 0.0)
    assert_equal 1.0, predict.send(:normalize_confidence, 1.0)
  end
end
