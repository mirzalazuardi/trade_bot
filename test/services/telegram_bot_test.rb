require "test_helper"

class TelegramBotTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @telegram_bot = ::TelegramBot.new
  end

  test "send_message does not raise when bot is nil" do
    result = @telegram_bot.send_message(chat_id: "123", text: "test")
    assert_nil result
  end

  test "send_trade_notification returns nil when no telegram_chat_id" do
    @user.update!(telegram_chat_id: nil, telegram_enabled: false)
    trade = trades(:one)

    result = @telegram_bot.send_trade_notification(user: @user, trade: trade)
    assert_nil result
  end

  test "send_risk_alert returns nil when no telegram_chat_id" do
    @user.update!(telegram_chat_id: nil, telegram_enabled: false)

    result = @telegram_bot.send_risk_alert(user: @user, message: "Test alert")
    assert_nil result
  end
end
