# frozen_string_literal: true

module Exchanges
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
