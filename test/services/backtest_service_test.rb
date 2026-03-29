require "test_helper"

class BacktestServiceTest < ActiveSupport::TestCase
  setup do
    Strategy::RsiReversal
    @user = users(:one)
    @bot = bots(:one)
    @bot.update!(
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "rsi_reversal",
      mode: :auto,
      status: :active
    )
  end

  test "returns hash with required keys" do
    skip "Requires candle data fixtures in database"
    result = Trading::BacktestService.call(
      bot: @bot,
      from_date: 30.days.ago,
      to_date: DateTime.now
    )

    assert result.is_a?(Hash)
    assert result.key?(:starting_cash)
    assert result.key?(:ending_cash)
    assert result.key?(:total_pnl)
    assert result.key?(:total_trades)
    assert result.key?(:win_rate)
    assert result.key?(:max_drawdown)
    assert result.key?(:profit_factor)
  end

  test "starting cash defaults to 10000" do
    skip "Requires candle data fixtures in database"
    result = Trading::BacktestService.call(
      bot: @bot,
      from_date: 30.days.ago,
      to_date: DateTime.now
    )

    assert_equal 10000, result[:starting_cash]
  end

  test "returns metrics with correct types" do
    skip "Requires candle data fixtures in database"
    result = Trading::BacktestService.call(
      bot: @bot,
      from_date: 30.days.ago,
      to_date: DateTime.now
    )

    assert result[:starting_cash].is_a?(Numeric)
    assert result[:ending_cash].is_a?(Numeric)
    assert result[:total_pnl].is_a?(Numeric)
    assert result[:total_trades].is_a?(Integer)
    assert result[:win_rate].is_a?(Numeric)
    assert result[:max_drawdown].is_a?(Numeric)
    assert result[:profit_factor].is_a?(Numeric)
  end
end
