module Trading
  class RequestApproval
    def self.call(bot:, signal:)
      new(bot: bot, signal: signal).call
    end

    def initialize(bot:, signal:)
      @bot = bot
      @signal = signal
    end

    def call
      return Result.failure([ "Signal is hold" ]) if @signal.hold?

      side = @signal.buy? ? "buy" : "sell"
      price = @signal.suggested_price || current_price
      quantity = calculate_quantity(side: side, price: price)

      return Result.failure([ "Invalid quantity" ]) unless quantity.positive?

      estimated_fee = FeeManagement::FeeCalculator.estimate_fee(
        exchange_name: @bot.exchange_name,
        order_type: "limit",
        amount: quantity * price,
        side: side,
        pair: @bot.pair,
        quantity: quantity
      )

      ml_confidence = nil
      if @bot.ai_enabled && @bot.ml_model_id
        prediction = MlAnalytics::Predict.call(bot: @bot, signal: @signal)
        ml_confidence = prediction.confidence
      end

      approval = Approval.create!(
        user: @bot.user,
        bot: @bot,
        pair: @bot.pair,
        side: side,
        quantity: quantity,
        price: price,
        ml_confidence: ml_confidence,
        estimated_fee: estimated_fee,
        status: :pending,
        expires_at: 5.minutes.from_now
      )

      ActiveSupport::Notifications.publish("approval.requested", approval_id: approval.id, bot_id: @bot.id, signal: @signal)

      Result.success(approval: approval)
    end

    private

    def current_price
      Ticker.find_by(exchange_name: @bot.exchange_name, pair: @bot.pair)&.last_price || 0
    end

    def calculate_quantity(side:, price:)
      return 0 if price.zero?

      allocation = @bot.risk_config&.position_size_percent || 10
      balance = fetch_balance

      (balance * (allocation / 100.0) / price).round(8)
    end

    def fetch_balance
      credential = @bot.user.exchange_credentials.active.find_by(exchange_name: @bot.exchange_name)
      return 0 unless credential

      adapter = Exchanges::Registry.get(@bot.exchange_name).new(credential)
      adapter.fetch_balance.available_balance
    end

    Result = Data.define(:success, :approval, :errors) do
      def self.success(approval:)
        new(success: true, approval: approval, errors: [])
      end

      def self.failure(errors)
        new(success: false, approval: nil, errors: errors)
      end
    end
  end
end
