# frozen_string_literal: true

module Exchanges
  module ValueObjects
    autoload :Ticker, "exchanges/value_objects/ticker"
    autoload :Candle, "exchanges/value_objects/candle"
    autoload :Balance, "exchanges/value_objects/balance"
    autoload :OrderResult, "exchanges/value_objects/order"
    autoload :CancelResult, "exchanges/value_objects/order"
    autoload :OrderStatus, "exchanges/value_objects/order"
    autoload :FeeSchedule, "exchanges/value_objects/fee_schedule"
  end
end
