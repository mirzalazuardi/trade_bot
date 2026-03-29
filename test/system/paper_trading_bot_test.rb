require_relative "system_test"

class PaperTradingBotTest < SystemTest
  def test_creates_paper_trading_bot
    sign_in

    visit "/bots/new"
    wait_for_selector "form"

    select "binance", from: "bot_exchange_name"
    fill "input[name='bot[pair]']", "BTC/USDT"
    select "rsi_reversal", from: "bot_strategy"
    select "paper_trade", from: "bot_mode"

    click "button[type='submit']"

    assert_text "BTC/USDT"
    assert_text "paper_trade"
    assert_text "rsi_reversal"
  end

  def test_paper_trading_bot_appears_in_list
    sign_in

    visit "/bots/new"
    wait_for_selector "form"

    fill "input[name='bot[pair]']", "ETH/USDT"
    select "binance", from: "bot_exchange_name"
    select "rsi_reversal", from: "bot_strategy"
    select "paper_trade", from: "bot_mode"

    click "button[type='submit']"

    visit "/bots"
    assert_text "ETH/USDT"
    assert_text "Paper Trading"
  end

  def test_paper_trading_bot_shows_pause_button
    bot = bots(:paper)
    sign_in

    visit "/bots/#{bot.id}"
    assert_text "Pause"
  end
end
