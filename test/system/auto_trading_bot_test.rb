require File.expand_path("system_test", __dir__)

class AutoTradingBotTest < SystemTest
  def test_creates_auto_trading_bot
    sign_in

    visit "/bots/new"
    wait_for_selector "form"

    select "binance", from: "bot_exchange_name"
    fill "input[name='bot[pair]']", "SOL/USDT"
    select "macd_crossover", from: "bot_strategy"
    select "auto", from: "bot_mode"

    click "button[type='submit']"

    assert_text "SOL/USDT"
    assert_text "auto"
  end

  def test_auto_bot_shows_status_active
    bot = bots(:one)
    sign_in

    visit "/bots/#{bot.id}"
    assert_text "active"
  end

  def test_toggles_ai_on_auto_bot
    bot = bots(:one)
    sign_in

    visit "/bots/#{bot.id}"
    click "Enable AI"

    assert_text "AI enabled"
  end
end
