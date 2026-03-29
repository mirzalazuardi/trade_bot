ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "ostruct"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    setup do
      Strategy::RsiReversal
    end

    def build_candle_data(closes)
      closes.map.with_index do |close, i|
        OpenStruct.new(
          open: close * 0.99,
          high: close * 1.01,
          low: close * 0.98,
          close: close,
          volume: 1000,
          timestamp: i
        )
      end
    end
  end
end
