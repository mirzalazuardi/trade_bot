require "test_helper"

class RequestApprovalTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bot = bots(:one)
    @bot.update!(
      exchange_name: "binance",
      pair: "BTC/USDT",
      strategy: "rsi_reversal",
      mode: :semi_auto,
      status: :active
    )
    Approval.destroy_all
  end

  test "returns failure when signal is hold" do
    signal = Strategy::Signal.new(type: "hold", confidence: 0, reason: "RSI neutral")

    result = Trading::RequestApproval.call(bot: @bot, signal: signal)

    refute result.success
    assert_equal [ "Signal is hold" ], result.errors
  end
end
