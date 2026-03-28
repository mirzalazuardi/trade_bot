module RiskManagement
  class PreTradeCheck
    def self.call(bot:, side:, amount:, price:)
      new(bot: bot, side: side, amount: amount, price: price).call
    end

    def initialize(bot:, side:, amount:, price:)
      @bot = bot
      @side = side
      @amount = amount
      @price = price
      @errors = []
    end

    def call
      check_balance
      check_position_size
      check_daily_loss_limit
      check_max_open_orders

      @errors.empty? ? Result.success : Result.failure(@errors)
    end

    private

    def check_balance
      credential = @bot.user.exchange_credentials.find_by(exchange_name: @bot.exchange_name, is_active: true)
      return @errors << "No active credential" unless credential

      balance = credential.adapter.fetch_balance

      required = @amount * @price
      if @side == "buy" && balance.available_balance < required
        @errors << "Insufficient balance: #{balance.available_balance} < #{required}"
      end
    end

    def check_position_size
      max_position_percent = @bot.risk_config&.max_position_percent || 10

      # Simplified: would need portfolio value calculation
    end

    def check_daily_loss_limit
      # Simplified: would check today's PnL
    end

    def check_max_open_orders
      max_orders = @bot.risk_config&.max_open_orders || 10
      # Simplified: would count open orders
    end

    Result = Data.define(:success, :errors) do
      def self.success
        new(success: true, errors: [])
      end

      def self.failure(errors)
        new(success: false, errors: errors)
      end
    end
  end
end
