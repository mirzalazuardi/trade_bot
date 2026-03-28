module FeeManagement
  class FeeCalculator
    def self.estimate_fee(exchange_name:, side:, amount:, order_type: :taker)
      exchange_fee = ExchangeFee.find_by(exchange_name: exchange_name, is_active: true)
      return 0 unless exchange_fee

      if exchange_fee.spread_based
        estimate_spread_fee(exchange_name: exchange_name, side: side, amount: amount)
      else
        rate = order_type == :maker ? exchange_fee.maker_rate : exchange_fee.taker_rate
        amount * rate
      end
    end

    def self.round_trip_cost(exchange_name:, side:, amount:, entry_price:, exit_price:)
      entry_fee = estimate_fee(exchange_name: exchange_name, side: side, amount: amount, order_type: :taker)

      exit_side = side == "buy" ? "sell" : "buy"
      exit_fee = estimate_fee(exchange_name: exchange_name, side: exit_side, amount: amount, order_type: :taker)

      entry_fee + exit_fee
    end

    def self.net_pnl(gross_pnl:, total_fees:)
      gross_pnl - total_fees
    end

    def self.profitable_after_fees?(exchange_name:, side:, amount:, entry_price:, target_price:, min_profit_multiplier: 1.5)
      return true unless entry_price && target_price

      if side == "buy"
        gross_pnl = (target_price - entry_price) * amount
      else
        gross_pnl = (entry_price - target_price) * amount
      end

      total_fees = round_trip_cost(
        exchange_name: exchange_name,
        side: side,
        amount: amount,
        entry_price: entry_price,
        exit_price: target_price
      )

      net = net_pnl(gross_pnl: gross_pnl, total_fees: total_fees)
      net > total_fees * min_profit_multiplier
    end

    def self.estimate_spread_fee(exchange_name:, side:, amount:)
      exchange_fee = ExchangeFee.find_by(exchange_name: exchange_name, is_active: true)
      return 0 unless exchange_fee&.spread_based

      typical_spread = exchange_fee.typical_spreads.values.first || 0.1
      price = amount * typical_spread

      price
    end
  end
end
