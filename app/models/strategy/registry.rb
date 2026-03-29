module Strategy
  class Registry
    BUILT_IN = {
      "rsi_reversal" => "Strategy::RsiReversal",
      "macd_crossover" => "Strategy::MacdCrossover"
    }.freeze

    class << self
      def register(name, strategy_class)
        strategies[name.to_s.downcase] = strategy_class
      end

      def get(name)
        load_built_in
        strategies[name.to_s.downcase] || raise(StandardError, "Unknown strategy: #{name}")
      end

      def available
        load_built_in
        strategies.keys
      end

      def each
        load_built_in
        strategies.each { |name, klass| yield(name, klass) }
      end

      private

      def strategies
        @strategies ||= {}
      end

      def load_built_in
        return if @loaded

        BUILT_IN.each do |name, class_name|
          strategies[name] ||= class_name.constantize
        end
        @loaded = true
      end
    end
  end
end
