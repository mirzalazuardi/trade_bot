module OrderManagement
  class PlaceOrder
    def self.call(bot:, side:, quantity:, price:, order_type: "limit")
      new(bot: bot, side: side, quantity: quantity, price: price, order_type: order_type).call
    end

    def initialize(bot:, side:, quantity:, price:, order_type:)
      @bot = bot
      @side = side
      @quantity = quantity
      @price = price
      @order_type = order_type
      @errors = []
    end

    def call
      return Result.failure([ "Bot not found" ]) unless @bot
      return Result.failure([ "Invalid side" ]) unless valid_side?
      return Result.failure(validation_errors) unless validation_errors.empty?

      estimated_fee = FeeManagement::FeeCalculator.estimate_fee(
        exchange_name: @bot.exchange_name,
        order_type: @order_type,
        amount: @quantity * @price,
        side: @side
      )

      order = Order.create!(
        user: @bot.user,
        bot: @bot,
        exchange_name: @bot.exchange_name,
        pair: @bot.pair,
        side: @side,
        status: :pending,
        order_type: @order_type,
        quantity: @quantity,
        price: @price,
        estimated_fee: estimated_fee
      )

      begin
        credential = @bot.user.exchange_credentials.find_by!(exchange_name: @bot.exchange_name, is_active: true)
        adapter = Exchanges::Registry.get(@bot.exchange_name).new(credential)

        result = adapter.place_order(
          pair: @bot.pair,
          side: @side,
          quantity: @quantity,
          price: @price,
          order_type: @order_type
        )

        order.update!(
          status: :submitted,
          native_order_id: result.order_id
        )

        Result.success(order: order)
      rescue Exchanges::Error => e
        order.update!(status: :failed)
        Result.failure([ e.message ])
      end
    end

    private

    def valid_side?
      %w[buy sell].include?(@side)
    end

    def validation_errors
      errors = []
      errors << "Invalid quantity" unless @quantity.positive?
      errors << "Invalid price" unless @price.positive?
      errors << "No active credential for #{@bot.exchange_name}" unless @bot.user.exchange_credentials.active.where(exchange_name: @bot.exchange_name).exists?
      errors
    end

    Result = Data.define(:success, :order, :errors) do
      def self.success(order:)
        new(success: true, order: order, errors: [])
      end

      def self.failure(errors)
        new(success: false, order: nil, errors: errors)
      end
    end
  end
end
