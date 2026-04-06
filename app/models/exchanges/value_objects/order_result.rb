# frozen_string_literal: true

module Exchanges
  OrderResult = Data.define(:success, :order_id, :client_order_id, :side, :type, :pair, :quantity, :price, :status, :filled_quantity, :average_price, :message, :errors) do
    def initialize(success:, order_id: nil, client_order_id: nil, side:, type:, pair:, quantity:, price: nil, status: :pending, filled_quantity: nil, average_price: nil, message: nil, errors: [])
      super
    end

    def filled?
      filled_quantity.to_f.positive?
    end
  end
end
