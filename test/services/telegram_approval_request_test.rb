require "test_helper"

class TelegramApprovalRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.update!(telegram_chat_id: nil, telegram_enabled: false)

    @bot = bots(:one)
    @bot.update!(mode: :semi_auto)

    @approval = Approval.create!(
      user: @user,
      bot: @bot,
      pair: "BTC/USDT",
      side: "buy",
      quantity: 0.01,
      price: 50000,
      status: :pending,
      expires_at: 5.minutes.from_now
    )
  end

  test "send_request returns nil when telegram not enabled" do
    result = Telegram::ApprovalRequest.call(approval: @approval)
    assert_nil result
  end

  test "send_request returns nil when no telegram_chat_id" do
    @user.update!(telegram_enabled: true, telegram_chat_id: nil)

    result = Telegram::ApprovalRequest.call(approval: @approval)
    assert_nil result
  end

  test "build_approval_message formats correctly" do
    @user.update!(telegram_enabled: true, telegram_chat_id: "123")

    handler = Telegram::ApprovalRequest.new(approval: @approval)
    message = handler.send(:build_approval_message)

    assert_includes message, "Trade Approval Request"
    assert_includes message, "BUY"
    assert_includes message, "0.01"
    assert_includes message, "BTC/USDT"
  end

  test "build_inline_keyboard returns correct structure" do
    @user.update!(telegram_enabled: true, telegram_chat_id: "123")

    handler = Telegram::ApprovalRequest.new(approval: @approval)
    keyboard = handler.send(:build_inline_keyboard)

    assert keyboard[:inline_keyboard]
    assert_equal 1, keyboard[:inline_keyboard].size
    assert_equal 2, keyboard[:inline_keyboard].first.size
  end
end
