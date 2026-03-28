module Strategy
  class Registry
    class << self
      def register(name, strategy_class)
        strategies[name.to_s.downcase] = strategy_class
      end

      def get(name)
        strategies[name.to_s.downcase] || raise(StandardError, "Unknown strategy: #{name}")
      end

      def available
        strategies.keys
      end

      def each
        strategies.each { |name, klass| yield(name, klass) }
      end

      private

      def strategies
        @strategies ||= {}
      end
    end
  end
end
