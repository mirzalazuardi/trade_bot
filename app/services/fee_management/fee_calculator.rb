require "ostruct"

module FeeManagement
  class FeeCalculator
    def self.call(exchange_name:, side:, quantity:, price:)
      amount = quantity * price
      total = estimate_fee(exchange_name: exchange_name, side: side, amount: amount, quantity: quantity)
      OpenStruct.new(total: total)
    end

    def self.estimate_fee(exchange_name:, side:, amount:, order_type: :taker, pair: nil, quantity: nil)
      exchange_fee = ExchangeFee.find_by(exchange_name: exchange_name, is_active: true)
      return 0 unless exchange_fee

      if exchange_fee.spread_based
        estimate_spread_fee(exchange_fee: exchange_fee, pair: pair, quantity: quantity, amount: amount)
      else
        rate = order_type.to_s == "maker" ? exchange_fee.maker_rate : exchange_fee.taker_rate
        amount * rate
      end
    end

    def self.round_trip_cost(exchange_name:, side:, amount:, entry_price:, exit_price:, pair: nil, quantity: nil)
      entry_fee = estimate_fee(exchange_name: exchange_name, side: side, amount: amount, order_type: :taker, pair: pair, quantity: quantity)

      exit_side = side == "buy" ? "sell" : "buy"
      exit_fee = estimate_fee(exchange_name: exchange_name, side: exit_side, amount: amount, order_type: :taker, pair: pair, quantity: quantity)

      entry_fee + exit_fee
    end

    def self.net_pnl(gross_pnl:, total_fees:)
      gross_pnl - total_fees
    end

    def self.profitable_after_fees?(exchange_name:, side:, amount:, entry_price:, target_price:, pair: nil, quantity: nil, min_profit_multiplier: 1.5)
      return true unless entry_price && target_price

      gross_pnl = if side == "buy"
        (target_price - entry_price) * (quantity || amount / entry_price)
      else
        (entry_price - target_price) * (quantity || amount / entry_price)
      end

      total_fees = round_trip_cost(
        exchange_name: exchange_name,
        side: side,
        amount: amount,
        entry_price: entry_price,
        exit_price: target_price,
        pair: pair,
        quantity: quantity
      )

      net = net_pnl(gross_pnl: gross_pnl, total_fees: total_fees)
      net > total_fees * min_profit_multiplier
    end

    # Forex spread cost = spread_in_pips * pip_value * units
    # pip_value: JPY pairs = 0.01, XAU = 0.1, standard = 0.0001
    def self.estimate_spread_fee(exchange_fee:, pair: nil, quantity: nil, amount: nil)
      return 0 unless exchange_fee&.spread_based

      spread_pips = if pair && exchange_fee.typical_spreads[pair]
        exchange_fee.typical_spreads[pair].to_f
      else
        exchange_fee.typical_spreads.values.first&.to_f || 0.1
      end

      units = quantity || (amount || 0)
      pip_value = pip_value_for(pair)

      spread_pips * pip_value * units
    end

    def self.pip_value_for(pair)
      return 0.0001 unless pair

      base, quote = pair.split("/")
      return 0.1 if base == "XAU"
      return 0.01 if quote == "JPY"
      0.0001
    end
  end
end
