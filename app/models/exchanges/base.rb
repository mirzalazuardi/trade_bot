# frozen_string_literal: true

module Exchanges
  module Base
    extend ActiveSupport::Concern

    included do
      extend Exchanges::Base::ClassMethods
    end

    def fetch_ticker(pair)
      raise NotImplementedError, "#{self.class} must implement #fetch_ticker"
    end

    def fetch_candles(pair, interval, from: nil, to: nil, limit: nil)
      raise NotImplementedError, "#{self.class} must implement #fetch_candles"
    end

    def fetch_balance
      raise NotImplementedError, "#{self.class} must implement #fetch_balance"
    end

    def place_order(pair, side, type, quantity, price: nil, stop_price: nil, time_in_force: "GTC")
      raise NotImplementedError, "#{self.class} must implement #place_order"
    end

    def cancel_order(order_id)
      raise NotImplementedError, "#{self.class} must implement #cancel_order"
    end

    def fetch_order_status(order_id)
      raise NotImplementedError, "#{self.class} must implement #fetch_order_status"
    end

    def fee_schedule
      raise NotImplementedError, "#{self.class} must implement #fee_schedule"
    end

    def normalize_pair(pair)
      raise NotImplementedError, "#{self.class} must implement #normalize_pair"
    end

    def denormalize_pair(pair)
      raise NotImplementedError, "#{self.class} must implement #denormalize_pair"
    end

    def test_connection
      fetch_balance
      true
    rescue Exchanges::Error
      false
    end

    module ClassMethods
      def required_credentials
        []
      end

      def supported_pairs
        []
      end

      def supported_intervals
        %w[1m 5m 15m 30m 1h 4h 1d 1w]
      end

      def adapter_name
        name.split("::").last.downcase
      end
    end
  end
end
