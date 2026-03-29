require File.expand_path("system_test", __dir__)

class StrategyTest < SystemTest
  def test_views_strategies_page
    sign_in

    visit "/strategies"
    assert_text "Strategies"
    assert_text "Built-in Strategies"
  end

  def test_displays_built_in_strategies
    sign_in

    visit "/strategies"
    assert_text "Rsi Reversal"
    assert_text "Macd Crossover"
    assert_selector "table"
  end

  def test_displays_indicator_info
    sign_in

    visit "/strategies"
    page = PlaywrightHelper.page

    rsi_cell = page.locator("td:has-text('Rsi Reversal')").first
    assert rsi_cell
  end
end
