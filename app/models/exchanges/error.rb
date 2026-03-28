# frozen_string_literal: true

module Exchanges
  class Error < StandardError
    attr_reader :code, :details

    def initialize(message = nil, code: nil, details: {})
      super(message)
      @code = code
      @details = details
    end
  end

  class AuthenticationError < Error
    def initialize(message = "Authentication failed", code: nil, details: {})
      super(message, code: code || :auth_error, details: details)
    end
  end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message = "Rate limit exceeded", retry_after: nil, code: nil, details: {})
      super(message, code: code || :rate_limit, details: details)
      @retry_after = retry_after
    end
  end

  class ConnectionError < Error
    def initialize(message = "Connection failed", code: nil, details: {})
      super(message, code: code || :connection_error, details: details)
    end
  end

  class InsufficientBalanceError < Error
    def initialize(message = "Insufficient balance", code: nil, details: {})
      super(message, code: code || :insufficient_balance, details: details)
    end
  end

  class InvalidOrderError < Error
    def initialize(message = "Invalid order", code: nil, details: {})
      super(message, code: code || :invalid_order, details: details)
    end
  end

  class OrderNotFoundError < Error
    def initialize(message = "Order not found", code: nil, details: {})
      super(message, code: code || :order_not_found, details: details)
    end
  end
end
