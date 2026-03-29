module Ml
  class TrainModelJob < ApplicationJob
    queue_as :default

    def perform(user_id:, pair:, days:, model_type: "lightgbm", features: "indicators", profit_pct: 2.0, loss_pct: 1.0)
      user = User.find(user_id)
      exchange = "binance"
      interval = "1h"

      broadcast_progress(user, "Fetching #{days} days of candles from Binance...")

      fetch_candles(exchange, pair, interval, days)

      candle_count = Candle.where(exchange_name: exchange, pair: pair, interval: interval).count
      broadcast_progress(user, "Exporting #{candle_count} candles to CSV...")

      csv_path = export_csv(exchange, pair, interval, days)

      broadcast_progress(user, "Training #{model_type} model (#{features})...")

      model_dir = Rails.root.join("storage/ml_models")
      model_dir.mkpath
      script = Rails.root.join("scripts/train_model.py")

      output = `python3 #{script} #{csv_path} #{model_dir} #{model_type} #{features} #{profit_pct} #{loss_pct} 2>&1`
      model_path = model_dir.join("signal_model.txt")

      unless model_path.exist?
        broadcast_progress(user, "Training failed: #{output.last(200)}", status: :error)
        return
      end

      broadcast_progress(user, "Registering model in database...")

      metadata = JSON.parse(File.read(model_dir.join("metadata.json"))) rescue {}

      model = MlModel.find_or_initialize_by(user: user, name: metadata["name"] || "Signal Filter")
      model.update!(
        version: (model.persisted? ? model.version + 1 : 1),
        model_type: model_type.to_sym,
        status: :testing,
        file_path: model_path.to_s,
        training_date: Date.today,
        feature_list: metadata["feature_list"] || %w[open high low close volume rsi macd volatility],
        performance_metrics: metadata["performance_metrics"] || {}
      )

      accuracy = model.performance_metrics["test_accuracy"]
      broadcast_progress(
        user,
        "Model trained! #{model.name} v#{model.version} — accuracy: #{(accuracy.to_f * 100).round(1)}%",
        status: :complete,
        model_id: model.id
      )
    end

    private

    def fetch_candles(exchange, pair, interval, days)
      symbol = pair.delete("/").upcase
      base_url = "https://api.binance.com/api/v3/klines"
      end_time = (Time.now.to_f * 1000).to_i
      start_time = ((Time.now - days.days).to_f * 1000).to_i

      current_start = start_time
      while current_start < end_time
        uri = URI(base_url)
        uri.query = URI.encode_www_form(symbol: symbol, interval: interval, startTime: current_start, limit: 1000)

        response = Net::HTTP.get_response(uri)
        break unless response.is_a?(Net::HTTPSuccess)

        klines = JSON.parse(response.body)
        break if klines.empty?

        klines.each do |k|
          Candle.find_or_initialize_by(
            exchange_name: exchange, pair: pair, interval: interval, timestamp: k[0].to_i / 1000
          ).update!(
            open: k[1].to_d, high: k[2].to_d, low: k[3].to_d,
            close: k[4].to_d, volume: k[5].to_d, closed: true
          )
        end

        current_start = klines.last[0].to_i + 1
        sleep 0.2
      end
    end

    def export_csv(exchange, pair, interval, days)
      candles = Candle.where(exchange_name: exchange, pair: pair, interval: interval)
                     .where("timestamp >= ?", days.days.ago.to_time.to_i)
                     .order(:timestamp)

      csv_path = Rails.root.join("storage/ml_training_data/#{exchange}_#{pair.delete("/")}_training.csv")
      csv_path.dirname.mkpath

      require "csv"
      CSV.open(csv_path, "w") do |csv|
        csv << %w[timestamp open high low close volume]
        candles.each { |c| csv << [ c.timestamp, c.open.to_f, c.high.to_f, c.low.to_f, c.close.to_f, c.volume.to_f ] }
      end

      csv_path
    end

    def broadcast_progress(user, message, status: :progress, model_id: nil)
      Turbo::StreamsChannel.broadcast_replace_to(
        "ml_training_#{user.id}",
        target: "ml_training_status",
        html: render_status(message, status, model_id)
      )
    end

    def render_status(message, status, model_id)
      icon = case status
      when :complete then '<svg class="h-5 w-5 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'
      when :error then '<svg class="h-5 w-5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>'
      else '<svg class="animate-spin h-5 w-5 text-indigo-500" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/></svg>'
      end

      bg = case status
      when :complete then "bg-green-50 border-green-200"
      when :error then "bg-red-50 border-red-200"
      else "bg-indigo-50 border-indigo-200"
      end

      text_color = case status
      when :complete then "text-green-700"
      when :error then "text-red-700"
      else "text-indigo-700"
      end

      link = model_id ? %(<a href="/ml_models/#{model_id}" class="ml-2 underline text-indigo-600 hover:text-indigo-800">View model →</a>) : ""

      <<~HTML
        <div id="ml_training_status" class="rounded-lg border #{bg} p-4 flex items-center gap-3">
          #{icon}
          <span class="text-sm font-medium #{text_color}">#{message}#{link}</span>
        </div>
      HTML
    end
  end
end
