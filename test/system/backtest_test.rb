require File.expand_path("system_test", __dir__)

class BacktestTest < SystemTest
  def test_runs_backtest_on_bot
    bot = bots(:one)
    sign_in

    visit "/bots/#{bot.id}"
    wait_for_selector "form"

    date_from = 30.days.ago.to_s
    date_to = Date.today.to_s

    fill "input[name='from_date']", date_from
    fill "input[name='to_date']", date_to

    click "Run Backtest"

    assert_text "Backtest"
  end

  def test_backtest_form_is_visible
    bot = bots(:one)
    sign_in

    visit "/bots/#{bot.id}"
    assert_selector "input[name='from_date']"
    assert_selector "input[name='to_date']"
    assert_text "Run Backtest"
  end
end
