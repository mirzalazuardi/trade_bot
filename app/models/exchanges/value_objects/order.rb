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

  CancelResult = Data.define(:success, :order_id, :message, :errors) do
    def initialize(success:, order_id:, message: nil, errors: [])
      super
    end
  end

  OrderStatus = Data.define(:order_id, :client_order_id, :side, :type, :pair, :quantity, :price, :status, :filled_quantity, :average_price, :created_at, :updated_at) do
    def initialize(order_id:, client_order_id: nil, side:, type:, pair:, quantity:, price: nil, status:, filled_quantity: nil, average_price: nil, created_at: nil, updated_at: nil)
      super
    end

    def open?
      %w[pending open partially_filled].include?(status.to_s)
    end

    def closed?
      %w[filled cancelled failed].include?(status.to_s)
    end
  end
end
