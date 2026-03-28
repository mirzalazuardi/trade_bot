# frozen_string_literal: true

module Exchanges
  Balance = Data.define(:total_equity, :available_balance, :unrealized_pnl, :currency, :balances) do
    def initialize(total_equity: nil, available_balance: nil, unrealized_pnl: nil, currency: "USD", balances: {})
      super
    end

    def free_balance
      available_balance || total_equity
    end
  end
end
