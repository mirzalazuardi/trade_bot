require File.expand_path("system_test", __dir__)

class SemiAutoTradingBotTest < SystemTest
  def test_creates_semi_auto_trading_bot
    sign_in

    visit "/bots/new"
    wait_for_selector "form"

    select "oanda", from: "bot_exchange_name"
    fill "input[name='bot[pair]']", "EUR/USD"
    select "macd_crossover", from: "bot_strategy"
    select "semi_auto", from: "bot_mode"

    click "button[type='submit']"

    assert_text "EUR/USD"
    assert_text "semi_auto"
  end

  def test_semi_auto_bot_requires_approval
    bot = bots(:two)
    sign_in

    visit "/bots/#{bot.id}"
    assert_text "semi_auto"
    assert_text "Pause"
    assert_text "Resume"
  end
end
