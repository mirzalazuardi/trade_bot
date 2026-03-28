# frozen_string_literal: true

module Exchanges
  FeeSchedule = Data.define(:maker_rate, :taker_rate, :discount_info, :spread_based, :commission_per_unit, :typical_spreads, :currency) do
    def initialize(maker_rate: 0.0, taker_rate: 0.0, discount_info: nil, spread_based: false, commission_per_unit: nil, typical_spreads: {}, currency: "USD")
      super
    end

    def fee_for(amount, side: :taker)
      rate = side == :maker ? maker_rate : taker_rate
      amount * rate
    end
  end
end
