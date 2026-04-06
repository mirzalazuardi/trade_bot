# frozen_string_literal: true

module Exchanges
  CancelResult = Data.define(:success, :order_id, :message, :errors) do
    def initialize(success:, order_id:, message: nil, errors: [])
      super
    end
  end
end
