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
      check_event_risk
      check_balance
      check_position_size
      check_daily_loss_limit
      check_max_open_orders

      @errors.empty? ? Result.success : Result.failure(@errors)
    end

    private

    def check_event_risk
      context = MarketIntelligence::MarketContext.call

      if context[:calendar_risk] == :high
        @errors << "High-impact event within 30min — trading blocked"
      end

      if context[:avoid_pairs].include?(@bot.pair)
        @errors << "#{@bot.pair} affected by upcoming event — avoid"
      end

      if context[:size_modifier] == 0.0
        @errors << "Market intelligence: size modifier at 0% — no trades"
      end
    rescue => e
      Rails.logger.warn("Event risk check failed: #{e.message}")
    end

    def check_balance
      credential = @bot.user.exchange_credentials.find_by(exchange_name: @bot.exchange_name, is_active: true)
      return @errors << "No active credential" unless credential

      balance = credential.adapter.fetch_balance
      required = @amount * @price
      estimated_fee = FeeManagement::FeeCalculator.call(
        exchange_name: @bot.exchange_name,
        side: @side,
        quantity: @amount,
        price: @price
      ).total

      total_required = required + estimated_fee
      if @side == "buy" && balance.available_balance < total_required
        @errors << "Insufficient balance: #{balance.available_balance} < #{total_required} (incl. fee)"
      end
    end

    def check_position_size
      max_position_percent = @bot.risk_config.max_position_percent
      credential = @bot.user.exchange_credentials.find_by(exchange_name: @bot.exchange_name, is_active: true)
      return unless credential

      balance = credential.adapter.fetch_balance.available_balance
      position_value = @amount * @price
      position_percent = (position_value / balance * 100).round(2)

      if position_percent > max_position_percent
        @errors << "Position size #{position_percent}% exceeds max #{max_position_percent}%"
      end
    end

    def check_daily_loss_limit
      max_daily_loss_percent = @bot.risk_config.max_daily_loss_percent
      daily_pnl = @bot.daily_pnl

      credential = @bot.user.exchange_credentials.find_by(exchange_name: @bot.exchange_name, is_active: true)
      return unless credential

      balance = credential.adapter.fetch_balance.available_balance
      daily_loss_percent = (daily_pnl.abs / balance * 100).round(2)

      if daily_pnl < 0 && daily_loss_percent >= max_daily_loss_percent
        @errors << "Daily loss #{daily_loss_percent}% exceeds limit #{max_daily_loss_percent}%"
      end
    end

    def check_max_open_orders
      max_orders = @bot.risk_config.max_open_orders
      open_orders = @bot.open_orders_count

      if open_orders >= max_orders
        @errors << "Open orders #{open_orders} at max limit #{max_orders}"
      end
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
