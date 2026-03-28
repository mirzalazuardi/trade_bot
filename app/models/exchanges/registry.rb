# frozen_string_literal: true

module Exchanges
  class Registry
    class << self
      def register(name, adapter_class)
        adapters[name.to_s.downcase] = adapter_class
      end

      def get(name)
        adapters[name.to_s.downcase] || raise(Error, "Unknown exchange: #{name}")
      end

      def available
        adapters.keys
      end

      def each
        adapters.each { |name, klass| yield(name, klass) }
      end

      private

      def adapters
        @adapters ||= {}
      end
    end
  end
end
