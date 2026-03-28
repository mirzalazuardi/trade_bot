module Exchanges
  class HttpClient
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_INITIAL_DELAY = 1.0
    DEFAULT_MAX_DELAY = 32.0
    DEFAULT_BACKOFF_FACTOR = 2.0

    attr_reader :base_url, :credentials

    def initialize(base_url:, api_key: nil, api_secret: nil)
      @base_url = base_url
      @api_key = api_key
      @api_secret = api_secret
    end

    def get(path, params: {}, headers: {})
      request(:get, path, params: params, headers: headers)
    end

    def post(path, params: {}, headers: {}, body: nil)
      request(:post, path, params: params, headers: headers, body: body)
    end

    def delete(path, params: {}, headers: {})
      request(:delete, path, params: params, headers: headers)
    end

    def request(method, path, params: {}, headers: {}, body: nil)
      url = build_url(path, params)
      request_headers = default_headers.merge(headers)

      execute_with_retry(method, url, request_headers, body)
    end

    private

    attr_reader :api_key, :api_secret

    def build_url(path, params)
      full_url = "#{base_url}#{path}"
      return full_url if params.empty?

      URI.parse(full_url).tap do |uri|
        uri.query = URI.encode_www_form(params)
      end.to_s
    end

    def default_headers
      headers = { "Content-Type" => "application/json" }
      headers["X-MBX-APIKEY"] = api_key if api_key
      headers
    end

    def faraday_connection
      @faraday ||= Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def execute_with_retry(method, url, headers, body, attempt: 0)
      max_retries = ENV.fetch("EXCHANGE_MAX_RETRIES", DEFAULT_MAX_RETRIES).to_i

      loop do
        response = faraday_connection.public_send(method, url, body, headers)
        return handle_response(response)
      rescue RateLimitError => e
        raise e if attempt >= max_retries
        delay = calculate_delay(attempt, e.retry_after)
        sleep(delay)
        attempt += 1
      rescue Exchanges::ConnectionError => e
        raise e if attempt >= max_retries
        delay = calculate_delay(attempt)
        sleep(delay)
        attempt += 1
      rescue Faraday::Error => e
        raise e unless retryable_error?(e)
        raise e if attempt >= max_retries
        delay = calculate_delay(attempt)
        sleep(delay)
        attempt += 1
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise AuthenticationError, "Invalid credentials"
      when 403
        raise AuthenticationError, "Access forbidden"
      when 404
        raise Exchanges::OrderNotFoundError, "Resource not found"
      when 429
        retry_after = response.headers["Retry-After"]&.to_i || 60
        raise RateLimitError.new("Rate limit exceeded", retry_after: retry_after)
      else
        raise Error, "Request failed: #{response.status}"
      end
    end

    def retryable_error?(error)
      case error
      when Faraday::Error::TimeoutError, Faraday::Error::ConnectionFailed
        true
      else
        false
      end
    end

    def calculate_delay(attempt, retry_after = nil)
      return retry_after if retry_after

      initial_delay = ENV.fetch("EXCHANGE_INITIAL_DELAY", DEFAULT_INITIAL_DELAY).to_f
      max_delay = ENV.fetch("EXCHANGE_MAX_DELAY", DEFAULT_MAX_DELAY).to_f
      backoff_factor = ENV.fetch("EXCHANGE_BACKOFF_FACTOR", DEFAULT_BACKOFF_FACTOR).to_f

      [ initial_delay * (backoff_factor**attempt), max_delay ].min
    end
  end
end
