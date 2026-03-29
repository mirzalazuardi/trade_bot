require "test_helper"

class PaperTradingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bot = bots(:paper)
    Trade.destroy_all
    Order.destroy_all
    Position.destroy_all
  end

  test "creates order when opening position" do
    result = Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 50000
    )

    assert result.is_a?(Order)
    assert_equal "filled", result.status
    assert_equal 0.01, result.quantity
    assert_equal 50000, result.price
  end

  test "creates position when opening" do
    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 50000
    )

    position = Position.last
    assert_equal "long", position.side
    assert_equal 0.01, position.quantity
    assert_equal 50000, position.average_price
    assert position.open?
  end

  test "creates trade record" do
    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 50000
    )

    trade = Trade.last
    assert_equal @user, trade.user
    assert_equal @bot, trade.bot
    assert_equal "buy", trade.side
    assert_equal 0.01, trade.quantity
    assert_equal 50000, trade.entry_price
    assert trade.open?
  end

  test "calculates long PnL correctly" do
    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 50000
    )

    position = Position.last

    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "sell",
      quantity: 0.01,
      price: 55000
    )

    position.reload
    assert position.closed?
    assert_equal 0, position.quantity
    assert position.gross_pnl.present?
    assert position.net_pnl.present?
  end

  test "calculates short PnL correctly" do
    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "sell",
      quantity: 0.01,
      price: 50000
    )

    position = Position.last
    assert_equal "short", position.side

    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 45000
    )

    position.reload
    assert position.closed?
    assert position.gross_pnl.positive?
  end

  test "adds to existing position on same side" do
    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.01,
      price: 50000
    )

    Trading::PaperTrading.simulate(
      bot: @bot,
      side: "buy",
      quantity: 0.02,
      price: 51000
    )

    position = Position.last
    assert_equal 0.03, position.quantity
    assert_equal 50666.67, position.average_price.round(2)
  end
end
